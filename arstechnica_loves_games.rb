# arstechnica game recommendation finder and syncer

require 'typhoeus'
require 'json'
require 'nokogiri'
require 'open-uri'
require 'eventmachine'
require 'net/http'
require 'uri'
require 'date'
require 'yaml'
require 'base64'


class Scraper
  attr_accessor :number_of_results
  attr_accessor :reviews        # hash of parsed reviews
  attr_accessor :starting_url   # static google results URL
  attr_accessor :page           # google result page iterator number
  attr_accessor :test_mode      # uses cache .yaml file for testing instead of hitting google
  attr_accessor :limit
  attr_accessor :limit_count
  
  def initialize
    self.number_of_results = 0
    self.page = 0
    self.reviews = Array.new
    self.starting_url = "http://www.google.com/search?hl=en&safe=off&biw=1310&bih=1064"
    self.starting_url << "&q=site%3Aarstechnica.com+arstechnica.com+%22verdict%3A+buy%22&aq=f&start="

    # the below is for test/dev
    self.test_mode = true
    self.limit = -1
    self.limit_count = 0
    
    if !self.test_mode
      begin
        puts "Cleared cache file."
        File.delete(File.dirname(__FILE__) + "/ars_dump.yaml")
      rescue Errno::ENOENT
        puts "Cache file already gone."
      end
    end
    
  end
  
  def scrape
    
    # test mode speeds up development because you don't have to wait 5 minutes to scrape ars
    if self.test_mode
      # Skip hammering google by loading from a cache file
      dump_file = File.open(File.dirname(__FILE__) + "/ars_dump.yaml")
      YAML::load_documents(dump_file) do |doc|
        self.reviews << doc
      end
      dump_file.close
      
      # skips all rest of scrape
      return
    end
    
    # get the google results for the current page
    @doc = Nokogiri::HTML(open(self.search_url))
    
    review_buffer = Array.new
    
    # parse the result
    @doc.css('li.g').each do |result|
      @title = result.css('h3.r a.l').text
      @link = result.css('h3.r a.l').attr('href').text
      @date_str = result.css('div.s').text[0..12]

      # remove all periods -- can add more to the regex as needed
      @date_str.gsub!(/\./, '')
      begin
        @date = Date.parse(@date_str)
      rescue ArgumentError
        @date = "INVALID on #{@link}"
        puts $!
      end
      
      @nokogiri_doc = Nokogiri::HTML(open(@link))
      
      # gzip fail
      # @serialized_doc = @nokogiri_doc.serialize({:encoding => 'utf-8', :save_with => 0})
      # @compressed_doc = Zlib::Deflate.deflate(@serialized_doc, Zlib::DEFAULT_COMPRESSION)
      # reviews << { :title => @title, :link => @link, :date => @date, :doc => @compressed_doc }
      
      # base64 fail
      @encoded_doc = Base64::encode64(@nokogiri_doc.to_s)
      self.reviews << { :title => @title, :link => @link, :date => @date, :doc => @encoded_doc }
      review_buffer << { :title => @title, :link => @link, :date => @date, :doc => @encoded_doc }
      
      #@msg = @nokogiri_doc.to_s.to_msgpack
      #reviews << { :title => @title, :link => @link, :date => @date, :doc => @msg }

      puts @title
    end
    
    # if we run out of google results size will be less than 10 (full page of links)
    if @doc.css('li.g').size >= 10
      self.page += 1
      puts "===> Sleeping before page: #{self.page}.  ZZzzz..."
      
      # flush to YAML file
      File.open(File.dirname(__FILE__) + "/ars_dump.yaml", "a") do |file|
        puts "review_buffer: #{review_buffer.size} || reviews: #{self.reviews.size} || page_count: #{self.limit_count}"
        review_buffer.each do |review|
          file.puts YAML::dump(review)
        end
      end
      
      
      # sleep to avoid hammering
      sleep 3
      
      # set limit to -1 to scrape all google results, all pages
      if self.limit == -1 || self.limit_count < self.limit - 1
        self.limit_count += 1
        scrape
      end
      
    end
    
    # will get a 503 if you hammer google, so we'll cache to file
    # this won't fire because of the return near top
    File.open(File.dirname(__FILE__) + "/ars_dump.yaml", "a") do |file|
      review_buffer.each do |review|
        file.puts YAML::dump(review)
      end
    end
        
  end
  
  def search_url
    "#{self.starting_url}#{self.page}"
  end
  
  # get rid of non-reviews
  def trim(key, string)
    forum_posts = []
    reviews.each_with_index do |r, i|
      if r[key][/#{string}/]
        forum_posts.push i
      end
    end

    forum_posts.each do |fp|
      reviews[fp] = nil
    end
    reviews.compact!
  end
  
  def to_s
    puts "#{self.title} - #{self.link}"
  end
    
end



####################################################
# MAIN


s = Scraper.new
s.scrape

# Pages of results: 
# Expected size: 
puts "before trim: #{s.reviews.size}"

# trim out forum posts
s.trim(:title, "OpenForum")
s.trim(:link, "\/civis\/")
s.trim(:link, "\/phpbb\/")
s.trim(:link, "\/gadgets/")

# for some reason getting an author bio link in there
s.trim(:link, "\/author\/")

# unique the whole thing
s.reviews.uniq!

# sort by title
s.reviews.sort_by! { |r| r[:title] }

# unique based on titles, gets rid of mulipage hits
# avoid ruby bug #4346 (uniq! after sort_by!)
s.reviews = s.reviews.uniq { |e| e[:title] }
puts "after trim: #{s.reviews.size}"


review_style_1 = ""
s.reviews.each do |r|
  if r[:title][/^Let them/]
    review_style_1 = r
  end
end

s.reviews.each do |r|
  doc = Nokogiri::HTML.parse(Base64::decode64(r[:doc]))
  #doc = Nokogiri::HTML::parse r[:doc]
  puts "-" * 50
  puts r[:link]
      
  # style 1 (table with heading, bleh)
  if !doc.css('tbody').css('th')[1].nil?
    print "STYLE 2: "
    puts doc.css('tbody').css('th')[1].text.strip
  end
  
  # style 2 (nice game-info div)
  if !doc.css('.game-info').css('h3')[0].nil?
    print "STYLE 3: "
    puts doc.css('.game-info').css('h3')[0].text.strip
  end
  
  # style 3 (nothing really, title detection)
  # http://arstechnica.com/gaming/news/2007/02/7048.ars
  # Game Review: WiiPlay (Wii)
  if doc.css('title').text[/^Game Review:/]
    print "STYLE 1: "
    puts doc.css('title').text.split(":")[1].strip
  end
  
  # style 4 (even less, just some <em> text)
  # http://arstechnica.com/gaming/reviews/2010/04/plain-sighton-the-pc-low-gravity-suicidal-robot-ninjas.ars
  if doc.xpath('//div[@id="story"]/h2[@class="title"]').css('em').text.size > 0
    print "STYLE 4: "
    puts doc.xpath('//div[@id="story"]/h2[@class="title"]').css('em').text.strip
  end
  
  # style 5 (absolutely nothing useful)
  # Try to detect proper nouns after the word reviews
  # http://arstechnica.com/gaming/reviews/2010/03/retro-but-approachable-ars-review-mega-man-10.ars
  if doc.xpath('//meta[@name = "title"]').attr("content").to_s.size > 0

    title = doc.xpath('//meta[@name = "title"]').attr("content").to_s
    game_title = title[/reviews(.*)/]
    if !game_title.nil?
      title_array = game_title.split(" ")
    
      # get rid of any words that start with lower case, hopefully a title is left
      title_array.reject! { |e| e[/^[a-z]/] }
      game_title = title_array.join(" ")
    
      print "STYLE 5: "
      puts game_title
    end
  end
  
  # style 6: grab title from text like Review: Lego Batman is saved by the co-op
  # http://arstechnica.com/gaming/news/2008/09/lego-batman-saved-by-the-co-op.ars
  if !doc.xpath('//meta[@property="og:title"]').empty?
    title = doc.xpath('//meta[@property="og:title"]').attr("content").to_s
    title_array = title.split(":")
    
    if !title_array[1].nil?
      game_title = title_array[1].strip
      game_title_array = game_title.split(" ")
    
      caps = Array.new
      game_title_array.each do |e|
        if e =~ /^[A-Z]/
          caps.push e
        else
          break
        end
      end
    
      print "STYLE 6: "
      puts caps.join(" ")
    end
  end
  
end


# s.reviews.each do |r|
#   puts "#{r[:title]} - #{r[:link]}"
# end

