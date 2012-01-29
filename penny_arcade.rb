# Scrape and sync all PA comics.
# Sorry Jerry and Mike about the bandwidth.
# I'll buy a shirt from your store.
# I already give to child's play every year.  :)

# This will create a directory in your Pictures folder called PA

# TODO: Wow, this is broken since they redesigned their site

# threads solved by moving saver thread into scraper, refactoring now

require 'typhoeus'
require 'json'
require 'nokogiri'
require 'eventmachine'
require 'net/http'
require 'uri'


# real start page
start_page = "http://www.penny-arcade.com/comic/"

# test last comic
#start_page = "http://www.penny-arcade.com/comic/1998/11/20/"

# bomb out bug on 2008
#start_page = "http://www.penny-arcade.com/comic/2008/7/23/"

# undefined attribute nilclass
#start_page = "http://www.penny-arcade.com/comic/2001/9/14/"

# another nil class
#start_page = "http://www.penny-arcade.com/comic/1998/11/23/"

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
      if @previous_link
        self.queue_url(@previous_link)
      end
      
      # find the post title in the middle of the page
      @post = @doc.css('.post')
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
        
    @post_image_title = @post_image.attr('alt').value

    # parse the post date from the url
    @url_a = url.split("/")
    
    # pad month and day with a zero
    @year = @url_a[4]
    @month = sprintf('%02d', @url_a[5])
    @day = sprintf('%02d', @url_a[6])
    @post_date = [ @year, @month, @day ].join("_")

    @image_url = find_comic_img(doc)
    if @image_url
      # include information other than the url for naming of the local file
      @save_package = Hash[ :image_url => @image_url,
          :post_image_title => @post_image_title,
          :post_date => @post_date ]

      semaphore.synchronize {
        self.saver.queue_url @save_package
      }
    end
    
  end
  
  def find_comic_img(doc)
    img_tag = doc.css('.post').css('.body').css('img').first
    if !img_tag.nil?
      img_tag.attributes['src']
    end
  end
  
  def find_previous_link(doc)
    if doc.css('.actionbar').css('.spritemap').first.nil?
      puts "Stopping Scraper."
      self.running = false
      nil
      # TODO: might be a problem here, pushes nil to the url queue
    else
      navigation_map = doc.css('.actionbar').css('.spritemap')
      previous = navigation_map.first.css('.float_left').css('a')[1].attribute('href')
      return "http://www.penny-arcade.com#{previous}"
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
      navigation_map = @doc.css('.actionbar').css('.spritemap')
    end
    
    self.hydra.queue @request
    self.hydra.run
    
    # now get the relative previous link
    previous = navigation_map.first.css('.float_left').css('a')[1].attribute('href')
    
    
    # go back a comic
    @request = Typhoeus::Request.new("http://www.penny-arcade.com#{previous.to_s}")
    @request.on_complete do |response|
      @doc = Nokogiri::HTML(response.body)
      navigation_map = @doc.css('.actionbar').css('.spritemap')
    end

    self.hydra.queue @request
    self.hydra.run
  
    # now return the next comic which is the unaliased newest comic that has a date in it
    next_link = navigation_map.first.css('.float_left').css('a')[3].attribute('href')
    return "http://www.penny-arcade.com#{next_link}"
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
      puts "SAVER THREAD: #{self.saver_thread.alive?}"

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
        sleep 5
        
      end
      
      # need to sleep a little bit to keep terminal from freaking out
      sleep Random.new.rand(0.01..0.1).round(3)
    end
    
  end
    
end


# Saves images in the following format:  date_title.extension
# For example: 2010_11_17_Prognostication.jpg
class Saver
  attr_accessor :url_queue            # queue of img files to download
  attr_accessor :local_dir            # path to directory for saving images
  attr_accessor :running              # boolean for running loop
  attr_accessor :saved_count          # count of saved files
  attr_accessor :downloaded_images    # list of already saved image urls
	attr_accessor :omit_extensions      # extensions to skip
	attr_accessor :last_saved           # last downloaded file
  attr_accessor :semaphore
  
  def initialize
    self.local_dir = "#{ENV['HOME']}/Pictures/PA"
    
    if !File.exists? local_dir
      require 'fileutils'
      begin
        FileUtils.mkdir local_dir
      rescue Errno::ENOENT
        puts $!
        exit
      end
    else
      if !File.directory? local_dir
        puts "Please remove the file at #{local_dir}, this needs to be a directory."
        exit
      end
    end
    
    self.running = true
    self.url_queue = Array.new
    self.downloaded_images = Array.new
    self.omit_extensions = [ "doc", "pdf", "xls", "rtf", "docx", "xlsx", "ppt", 
    							"pptx", "avi", "wmv", "wma", "mp3", "mp4", "pps", "swf" ]
    self.saved_count = 0
  end
  
  def queue_url(hash)
    self.url_queue.push(hash)
    #puts "Saver.queue_url(): pushed #{hash[:image_url]} to saver url queue."
  end
    
  def running?
    self.running
  end  
  
  def stop
    self.running = false
    puts "Stopping Saver"
  end
  
  def save_image(url, post_image_title=nil, post_date=nil)
    # Check to see if we have saved this image already.
    # If so, move on.
    return if downloaded_images.include? url        

    # Save this file name down so that we don't download
    # it again in the future.
    downloaded_images << url

    # Parse the image name out of the url. We'll use that
    # name to save it down.
    file_name = parse_file_name(url)
    
    # keep the remote extension
    file_extension = parse_extension(url)
    
    if !post_image_title.nil?
      # replace spaces with underscores for comic title
      post_image_title.gsub!(/\s/, '_')
      
      # get rid of characters that make for nasty local filenames
      post_image_title.gsub!(/[\/\:\,\.\#\~\`\@\$\*\\\'\"\!\(\)\?]/, '')

      # find one or more underscores and make it just one
      post_image_title.gsub!(/_+/,'_')
      
      # saved image naming convention
      file_name = "#{post_date}_#{post_image_title}#{file_extension}"
    end

    if File.exist?(self.local_dir + "/" + file_name)
      #puts "Saver.save_image(): Skipping file already downloaded"
      self.last_saved = "[SKIPPED EXISTS]: #{file_name}"
    else
      # Get the response and data from the web for this image.
      response = fetch_page(url)

      # If the response is not nil, save the contents down to
      # an image.
      if !response.nil?
        #puts "Saver.save_image(): saving image: #{url}"    

        f = File.open(self.local_dir + "/" + file_name, "wb+")
        f << response.body
        f.close
                
        self.saved_count += 1
        self.last_saved = file_name
      else
        puts "reponse is nil from #{url}:#{response}"
      end
    end


  end

  def fetch_page(url, limit = 10)
    # Make sure we are supposed to fetch this type of resource.
    return if should_omit_extension(url)

    # You should choose better exception.
    raise ArgumentError, 'HTTP redirect too deep' if limit == 0

    begin
      response = Net::HTTP.get_response(URI.parse(url))
    rescue
      # The URL was not valid - just log it can keep moving
      puts "INVALID URL: #{url}" + $!
    end

    case response
    when Net::HTTPSuccess     then response
    when Net::HTTPRedirection then fetch_page(response['location'], limit - 1)
    else
      # We don't want to throw errors if we get a response
      # we are not expecting so we will just keep going.
      nil
    end
  end

  def parse_file_name(url)
    # Find the position of the last slash. Everything after
    # it is our file name.
    spos = url.rindex("/")
    url[spos + 1, url.length - 1]
  end
  
  def parse_extension(url)
    url[url.rindex("."), url.length - 1]
  end
  
  def should_omit_extension(url)
     # Get the index of the last slash.
     spos = url.rindex("/")

     # Get the index of the last dot.
     dpos = url.rindex(".")

     # If there is no dot in the string this will be nil, so we
     # need to set this to 0 so that the next line will realize
     # that there is no extension and can continue.
     if dpos.nil?
       dpos = 0
     end

     # If the last dot is before the last slash, we don't have
     # an extension and can return.
     return false if spos > dpos

     # Grab the extension.
     ext = url[dpos + 1, url.length - 1]

     # The return value is whether or not the extension we
     # have for this URL is in the omit list or not.
     omit_extensions.include? ext

   end
   
   def run
     while self.running?
       # thread was dying until put saver into scraper
       # puts "saver tick"
       if url_queue.size != 0
         semaphore.synchronize {
           @save_hash = self.url_queue.pop
           save_image(@save_hash[:image_url].to_s, @save_hash[:post_image_title], @save_hash[:post_date])
         }
       end
       
       # need to sleep a little bit to keep terminal from freaking out
       sleep Random.new.rand(0.02..0.2).round(3)
     end
   end
   
   def stats
     r = self.running ? "Running" : "Stopped"
     printf("%-4s %4s", "Saver queue: ", self.url_queue.length)
     print " || Saver:#{r}   || "
     printf("%-3s %3s", "Saved Images This Session: ", self.saved_count)
     print "\n"
     
     
     #puts "  Saver queue: #{self.url_queue.length} || Saver:#{r}   ||  Saved Images This Session: #{self.saved_count}"
     puts "Saving to: #{self.local_dir}"
     puts "On: #{self.last_saved}"
   end
  
end


# We need to get the latest comic.  On PA, you have to click back and then forward to get the
# latest comic which is aliased at /comic.
temp_scraper = Scraper.new
newest_comic = temp_scraper.newest_comic(start_page)

# threads are dying
semaphore = Mutex.new

scraper = Scraper.new
scraper.semaphore = semaphore
scraper.queue_url(newest_comic)

scraper.start_saver(semaphore)

scraper_thread = Thread.new { scraper.run }
saver_thread = Thread.new { scraper.saver.run }

scraper_thread.join
