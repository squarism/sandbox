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
require 'open-uri'
require 'faraday'

require './saver.rb'
require './scraper.rb'


# real start page
start_page = "http://www.penny-arcade.com/comic"

# test last comic
# start_page = "http://www.penny-arcade.com/comic/1998/11/25/"

# bomb out bug on 2008
#start_page = "http://www.penny-arcade.com/comic/2008/7/23/"

# undefined attribute nilclass
#start_page = "http://www.penny-arcade.com/comic/2001/9/14/"

# another nil class
#start_page = "http://www.penny-arcade.com/comic/1998/11/23/"

# another nil class WOW HELLO TESTING
# TODO: STOP BEING A LAZY !@#$
# start_page = "http://penny-arcade.com/comic/2008/05/09"

# another nil
# start_page = "http://penny-arcade.com/comic/2005/12/30"

# now just stopping for no reason
# start_page = "http://penny-arcade.com/comic/2004/11/29"

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
