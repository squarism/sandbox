# this is actually taking way too long to run
# unbelievable CPU load for something that should be simple
# have an algorithm problem or using Arrays when should be using a Hash
# or something
# 227305.19 seconds = 63 hours

require 'action_view'
include ActionView::Helpers

# change to location of rubygems mirror
GEM_DIR = "/opt/rubygems/gems"

gems = Dir.glob("#{GEM_DIR}/**/*.gem"); 1
gems = gems.collect {|g| g.split("/").last}; 

class Version
  include Comparable
  attr_reader :major, :feature_group, :feature, :bugfix, :version_string

  def initialize(version="")
    @version_string = version
    @major = "0"; @feature_group = "0"; @feature = "0"; @bugfix = "0"
    
    v = version.split(".")
    # puts v.join("|")

    if v[0]; @major = v[0]; else; raise "Major number blank."; end
    if v[1]; @feature_group = v[1]; end
    if v[2]; @feature = v[2]; end
    if v[3]; @bugfix = v[3]; end
  end
  
  # strangely enough .to_i works even for
  # >> "6-mswin32".to_i
  # => 6
  def <=>(other)
    return @major <=> other.major if ((@major.to_i <=> other.major.to_i) != 0)
    return @feature_group <=> other.feature_group if ((@feature_group.to_i <=> other.feature_group.to_i) != 0)
    return @feature <=> other.feature if ((@feature.to_i <=> other.feature.to_i) != 0)
    return @bugfix <=> other.bugfix if ((@bugfix.to_i <=> other.bugfix.to_i) != 0)
    # we probably have two things equal here
    return -1
    puts "FALLING THROUGH in <=>, not good"
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

group_r = Regexp.new(/(.*)-(\d+\.\d+.*)\.gem$/)
gems_grouped = gems.group_by {|g| g.scan(group_r).flatten[0] }
# => {"firewool"=>["firewool-0.1.0.gem", "firewool-0.1.1.gem"}], ... }

latest_gems = []

gems_grouped.each do |g|
  versions = g[1].collect {|ver| ver.scan(group_r).flatten[1] }
  # => ["0.1.0", "0.1.1", "0.1.2"]

  begin
    latest = versions.collect {|v| Version.new(v)}.sort.reverse.first
    # => "0.1.2"
  rescue ArgumentError
    puts g
  rescue NoMethodError
    # somebody's got some crazy gem naming conventions
    # for example: chill-1.gem
    gems_grouped.delete g
  end

  latest_gems << "#{g[0]}-#{latest}.gem"
end

total = 0
latest_gems.each do |gem|
  begin
    total = total + File.size("#{GEM_DIR}/#{gem}")
  rescue Errno::ENOENT => e
    puts "WTF no #{gem}"
  end
  
end

puts "Total size of newest gems in #{GEM_DIR} is #{number_to_human_size(total)}"

