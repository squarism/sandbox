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

class Scraper
  attr_accessor :number_of_results
  attr_accessor :reviews        # hash of parsed reviews
  attr_accessor :starting_url
  attr_accessor :page
  attr_accessor :test_mode
  
  def initialize
    self.number_of_results = 0
    self.page = 0
    self.reviews = Array.new
    self.starting_url = "http://www.google.com/search?hl=en&safe=off&biw=1310&bih=1064"
    self.starting_url << "&q=site%3Aarstechnica.com+arstechnica.com+%22verdict%3A+buy%22&aq=f&start="
    self.test_mode = true
  end
  
  def scrape
    
    if self.test_mode
      ## Skip hammering google by loading from a cache file
      dump_file = File.open("ars_dump.yaml")
      #reviews = Array.new
      YAML::load_documents(dump_file) do |doc|
        #puts doc[:title]
        self.reviews << doc
      end
      dump_file.close
      
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
      
      reviews << { :title => @title, :link => @link, :date => @date }
      puts @title
    end
    
    if @doc.css('li.g').size >= 10
      self.page += 1
      puts "Sleeping before page: #{self.page} ..."
      sleep 10
      scrape
    end
    
    File.open("ars_dump.yaml", "w") do |file|
      s.reviews.each do |hash|
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
    
end

# will get a 503 if you hammer google, so we'll cache to file
s = Scraper.new
s.scrape

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



s.reviews.each do |r|
  if r[:title][/Reach/]
    puts r
  end
end



s.reviews.each do |r|
  puts "#{r[:title]} - #{r[:link]}"
end

