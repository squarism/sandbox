# this is actually taking 50 hours to run
# unbelievable CPU load for something that should be simple
# have an algorithm problem or using Arrays when should be using a Hash
# or something

require 'action_view'
include ActionView::Helpers
require 'ruby-prof'

# change to location of rubygems mirror
GEM_DIR = ARGV[1]

gems = Dir.glob("#{GEM_DIR}/**/*.gem"); 1
# test comparision problem
# gems = Dir.glob("#{GEM_DIR}/**/springboard*.gem")

class Version
  include Comparable
  attr_reader :major, :feature_group, :feature, :bugfix, :version_string

  def initialize(version="")
    @version_string = version
    
    v = version.split(".")
    # puts v.join("|")

    if v[0]; @major = v[0]; else; @major = 0; raise "Major number blank."; end
    if v[1]; @feature_group = v[1]; else; @feature_group = 0; end
    if v[2]; @feature = v[2]; else; @feature = 0; end
    if v[3]; @bugfix = v[3]; else; @bugfix = 0; end
  end
  
  def <=>(other)
    return @major <=> other.major if ((@major.to_i <=> other.major.to_i) != 0)
    return @feature_group <=> other.feature_group if ((@feature_group.to_i <=> other.feature_group.to_i) != 0)
    return @feature <=> other.feature if ((@feature.to_i <=> other.feature.to_i) != 0)
    return @bugfix <=> other.bugfix if ((@bugfix.to_i <=> other.bugfix.to_i) != 0)
  end

  def self.sort
    self.sort!{|a,b| a <=> b}
  end

  def to_s
    @version_string
  end
end

# temporary benchmarking
RubyProf.start

gem_names = gems.collect{|g| g.split("/").last}; 1

latest_gems = []
gem_names.each do |file|
  # split the gem name and gem version text
  matches = file.scan(/(.*)-(.*)\.gem$/).flatten
  gem_family_name = matches.first
  
  # find all gems named similarly
  # gem_family =  gem_names.find_all{|item| item =~ /^#{gem_family_name}-(\d+.*\d+)\.gem$/}

  # find all gems named similarly
  # find_all and Array#select are too slow.  39.647s on 10 files  :(
  # Use fs glob.  04.289s on 10 files  :)
  gem_family = Dir.glob("#{GEM_DIR}/**/#{gem_family_name}-[0-9]*.gem") #.collect{|f| f.split("/").last}

  begin
    versions = gem_family.collect{|gem| gem.scan(/.*-(.*)\.gem$/).flatten.first }
  rescue Exception => e
    puts "Version numbering problem in #{file}: #{e}"
  end

  # bah, I wish I could do some kind of deep sort here instead of doing string tricks
  begin
    latest = versions.collect {|v| Version.new(v)}.sort.reverse.first  
  rescue RuntimeError => e
    puts "Weird versioning convention in the gem family: #{file}: #{e}"
  rescue ArgumentError => e
    puts "Comparison failed: #{file}: #{e}"
  end
  
  
  # delete older gems
  # gem_names.delete_if {|item| item =~ /^#{gem_family_name}-.*.gem$/}

  latest_gems << "#{matches.first}-#{latest.to_s}.gem"
  # if latest_gems.count > 5
  #   break
  # end
end

total = 0
latest_gems.each do |gem|
  begin
    total = total + File.size("#{GEM_DIR}/#{gem}")
  rescue Errno::ENOENT => e
    puts "WTF no #{gem}"
  end
  
end

result = RubyProf.stop
printer = RubyProf::FlatPrinter.new(result)
printer.print(STDOUT, {})

puts "Total size of newest gems in #{GEM_DIR} is #{number_to_human_size(total)}"
