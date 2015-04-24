# queues up the previous links, one page at a time
class Scraper
  attr_accessor :page_size      # size of page
  attr_accessor :page_position  # position inside of single page
  attr_accessor :hydra          # hydra object
  attr_accessor :url_queue      # url string queue
  attr_accessor :running
  attr_accessor :saver          # image saver class
  attr_accessor :scraped_count  # number of links followed
  attr_accessor :semaphore
  attr_accessor :saver_thread

  def initialize
    self.page_size = 10
    self.page_position = 0
    self.hydra = Typhoeus::Hydra.new
    self.url_queue = Array.new
    self.running = true
    self.saver = Saver.new
    self.scraped_count = 0
  end

  def running?
    self.running
  end

  def scrape(url)
    @request = Typhoeus::Request.new(url)

    @request.on_complete do |response|
      @response = response.body
      @doc = Nokogiri::HTML(@response)

      @previous_link = find_previous_link(@doc)
      # handle last comic
      if @previous_link == 'http://penny-arcade.com/comic/'
        puts "Hit last comic.  Stopping."
        self.running = false
        self.saver.stop
      end

      if @previous_link
        self.queue_url(@previous_link)
      end


      # find the post title in the middle of the page
      @post = @doc.css('#comic')
      if @doc.css('.content').css('.error').css('h1').text == "No comic/newspost for this issue"
        self.saver.last_saved = "[SKIPPED] No comic for today."
      else
        queue_saver(url, @post, @doc)
      end
    end

    self.hydra.queue @request
    self.hydra.run
    self.scraped_count += 1
  end

  def queue_url(url)
    self.url_queue.push(url)
    #puts "Scraper.queue_url(): pushed #{url} to url queue."
  end

  # we have a comic image, parse it and queue it
  def queue_saver(url, post, doc)
    # check for empty post (should mean first comic ever)
    if post.empty?
      return
    else
      @post_image = post.css('img')
    end

    @post_image_title = post.css('.title').css('.comicTag').css('h2').text

    # parse the post date from the url
    @url_a = url.split("/")

    # pad month and day with a zero
    @year = @url_a[4].to_i
    @month = sprintf('%02d', @url_a[5].to_i)
    @day = sprintf('%02d', @url_a[6].to_i)
    @post_date = [ @year, @month, @day ].join("_")

    @image_url = find_comic_img(doc)
    if !@image_url.nil?
      # include information other than the url for naming of the local file
      @save_package = Hash[ :image_url => @image_url,
          :post_image_title => @post_image_title,
          :post_date => @post_date ]

      semaphore.synchronize {
        self.saver.queue_url @save_package
      }
    end

  end

  # this should just return a url directly to the image
  def find_comic_img(doc)
    img_tag = doc.css('#comicFrame').css('img').first
    if !img_tag.nil?
      img_tag.attributes['src'].value
    else
      puts "Scraper broken, it can't find an image.  PA has changed styles again."
    end
  end

  # walk the comic tree
  def find_previous_link(doc)
    if doc.css('.btnPrev').first.nil?
      puts "Stopping Scraper."
      self.running = false
      nil
      # TODO: might be a problem here, pushes nil to the url queue
    else
      navigation_map = doc.css('.btnPrev')
      previous = navigation_map.first.attributes['href'].value()
      return previous
    end
  end

  # the newest comic at /comic doesn't have a date in the URL which is the only place to get it
  # so we have to go back one post and go forward
  def newest_comic(url)
    # define for scope reasons
    navigation_map = ""

    # get the newest comic
    @request = Typhoeus::Request.new(url)
    @request.on_complete do |response|
      @doc = Nokogiri::HTML(response.body)
      navigation_map = @doc.css('.comicNav').css('.btnPrev')
    end

    self.hydra.queue @request
    self.hydra.run

    # now get the relative previous link
    previous = navigation_map.first.attributes['href'].value()

    # go back a comic
    @request = Typhoeus::Request.new(previous)
    @request.on_complete do |response|
      @doc = Nokogiri::HTML(response.body)
      navigation_map = @doc.css('.comicNav').css('.btnNext')
    end

    self.hydra.queue @request
    self.hydra.run

    # now return the next comic which is the unaliased newest comic that has a date in it
    next_link = navigation_map.first.attributes['href'].value()
  end

  def stats
    # clear screen
    print %x{clear}

    r = self.running ? "Running" : "Stopped"

    # scraper stats
    printf("%-2s %2s", "Scraper queue: ", self.url_queue.length)
    print " || Scraper:#{r} || "
    printf("%-3s %3s", "Pages Scraped This Session: ", self.scraped_count)
    print "\n"
  end

  def start_saver(semaphore)
    self.saver = Saver.new
    self.saver.semaphore = semaphore
    self.saver_thread = Thread.new { self.saver.run }
  end

  def run
    while self.running?
      if url_queue.size != 0 && self.saver.url_queue.size <= 10
        @url = self.url_queue.pop
        scrape(@url)
      end

      # print stats
      self.stats
      self.saver.stats
      # saver thread keeps dying
      # puts "SAVER THREAD: #{self.saver_thread.alive?}"

      # TODO: sometimes the thread dies!
      if !self.saver_thread.alive?
        self.saver_thread = Thread.new { self.saver.run }
        death_string = %q{
         _______ _                        _   _____  _          _ _
        |__   __| |                      | | |  __ \(_)        | | |
           | |  | |__  _ __ ___  __ _  __| | | |  | |_  ___  __| | |
           | |  | '_ \| '__/ _ \/ _` |/ _` | | |  | | |/ _ \/ _` | |
           | |  | | | | | |  __/ (_| | (_| | | |__| | |  __/ (_| |_|
           |_|  |_| |_|_|  \___|\__,_|\__,_| |_____/|_|\___|\__,_(_)
           It's ok, this happens.  It'll start again soon.
        }
        puts death_string
        sleep 1
      end

      # need to sleep a little bit to keep terminal from freaking out
      sleep Random.new.rand(0.01..0.1).round(3)
    end
  end

end
