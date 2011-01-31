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
require 'msgpack'

class Scraper
  attr_accessor :number_of_results
  attr_accessor :reviews        # hash of parsed reviews
  attr_accessor :starting_url   # static google results URL
  attr_accessor :page           # google result page iterator number
  attr_accessor :test_mode      # uses cache .yaml file for testing instead of hitting google
  
  def initialize
    self.number_of_results = 0
    self.page = 0
    self.reviews = Array.new
    self.starting_url = "http://www.google.com/search?hl=en&safe=off&biw=1310&bih=1064"
    self.starting_url << "&q=site%3Aarstechnica.com+arstechnica.com+%22verdict%3A+buy%22&aq=f&start="
    self.test_mode = true
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
      
      #@msg = @nokogiri_doc.to_s.to_msgpack
      #reviews << { :title => @title, :link => @link, :date => @date, :doc => @msg }

      puts @title
    end
    
    # if we run out of google results size will be less than 10 (full page of links)
    if @doc.css('li.g').size >= 10
      self.page += 1
      puts "Sleeping before page: #{self.page} ..."
      
      # sleep to avoid hammering
      #sleep 3
      
      #scrape
    end
    
    # will get a 503 if you hammer google, so we'll cache to file
    # this won't fire because of the return near top
    File.open(File.dirname(__FILE__) + "/ars_dump.yaml", "w") do |file|
      self.reviews.each do |hash|
        file.puts YAML::dump(hash)
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


def deserialize(element)
  # zstream = Zlib::Inflate.new
  # buf = zstream.inflate(element[:doc])
  # deserialized_doc = Nokogiri::HTML.parse(buf)

  
  deserialized_doc = Nokogiri::HTML.parse(Base64::decode64(element[:doc]))
end



s = Scraper.new
s.scrape

# Pages of results: 
# Expected size: 
puts "before trim: #{s.reviews.size}"

# trim out forum posts
s.trim(:title, "OpenForum")
s.trim(:link, "\/civis\/")
s.trim(:link, "\/phpbb\/")

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

# test unique title trim
# s.reviews.each do |r|
#   if r[:title][/Reach/]
#     puts r
#   end
# end

review_style_1 = ""
s.reviews.each do |r|
  if r[:title][/^Let them/]
    review_style_1 = r
  end
end
#puts review_style_1[:link]
puts review_style_1.size

# gzip
#doc = deserialize(review_style_1)

# base64

#puts doc


#puts unpacked_doc = Nokogiri::HTML.parse(MessagePack.unpack review_style_1[:doc])


#puts doc.css('.news-item-figure') #.css('th') #[1].text


s.reviews.each do |r|
  doc = Nokogiri::HTML.parse(Base64::decode64(r[:doc]))
  #doc = Nokogiri::HTML::parse r[:doc]
  puts r[:link]
  
  # style -1
  #if !doc.css('.news-item-figure').css('th')[1].nil?
  #  print "STYLE 1: "
  #  puts doc.css('.news-item-figure').css('th')[1].text
  #end
    
  # style 1 (table with heading, bleh)
  if !doc.css('tbody').css('th')[1].nil?
    print "STYLE 1: "
    puts doc.css('tbody').css('th')[1].text
  end
  
  # style 2 (nice game-info div)
  if !doc.css('.game-info').css('h3')[0].nil?
    print "STYLE 2: "
    puts doc.css('.game-info').css('h3')[0].text
  end
  
  # style 3 (nothing really, title detection)
  # http://arstechnica.com/gaming/news/2007/02/7048.ars
  # Game Review: WiiPlay (Wii)
  if doc.css('title').text[/^Game Review:/]
    print "STYLE 3: "
    puts doc.css('title').text.split(":")[1].strip
  end
  
end


# s.reviews.each do |r|
#   puts "#{r[:title]} - #{r[:link]}"
# end

