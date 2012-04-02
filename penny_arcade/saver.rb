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
