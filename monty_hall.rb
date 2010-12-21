#!/usr/bin/ruby
# a simulation of the monty hall problem

# monkey patch
class Array
  def shuffle!
    size.downto(1) { |n| push delete_at(rand(n)) }
    self
  end
end

class Player
  attr_accessor :name
  attr_accessor :choice
  attr_accessor :played
  attr_accessor :won
  attr_accessor :lost
  
  def initialize(name)
    self.name = name
    self.played = 0
    self.won = 0
    self.lost = 0
  end
  
  def pick_door(door_number)
    self.choice = door_number
    #puts "PLAYER PICKS: #{self.choice}"
  end
  
  def win
    self.won += 1
    self.played += 1
  end
  
  def lose
    self.lost += 1
    self.played += 1
  end
  
  def percentage
    num = (self.won.to_f/self.played.to_f) * 100
    sprintf('%.2f', num) + "%"
  end
  
end

class Game
  attr_accessor :doors
  attr_accessor :door_states
  
  def initialize
    # set up doors
    self.doors = Array.new
    self.doors = [ "goat", "goat", "car" ]
    self.doors.shuffle!
    
    # set up door states
    self.door_states = Array.new
    self.door_states = [ "closed", "closed", "closed" ]
  end
  
  # main loop
  def run(player_1, player_2)
    # Player 1 randomly picks a door
    # Player 2 uses this door for simplicity
    player_choice = rand(3)
    player_1.pick_door(player_choice)
    player_2.pick_door(player_choice)
    
    # Host picks a door with a goat and reveals door
    goats = []
    self.doors.each_index {|d| goats << d if doors[d] == "goat"}
    goats.delete player_choice
    
    # if player won already then there are two goat doors, host picks one
    if goats.length > 1
      goats.delete_at rand(2)
    end

    # first is redundant but safe
    door_states[goats.first] = "open"

    # Player 1 switches between two remaining doors
    # Player 2 does not switch so do nothing
    remaining = []
    self.door_states.each_index {|d| remaining << d if door_states[d] == "closed"}
    remaining.delete player_choice
    player_1.choice = remaining.first      # first is redundant but safe


    # Log result
    if win?(player_1)
      player_1.win
    else
      player_1.lose
    end
    
    if win?(player_2)
      player_2.win
    else
      player_2.lose
    end
    
  end
  
  # did player win?
  def win?(player)
    if self.doors[player.choice] == "car"
      true
    else
      false
    end
  end
  
  # print out the game statistics
  def stats(p1, p2)
    # terminal clear code
    print %x{clear}
    
    puts "Monty Hall Games Played: #{p1.played}"
    puts "#{p1.name} (switches): #{p1.won}/#{p1.played} : #{p1.percentage}"
    puts "#{p2.name} (stays)   : #{p2.won}/#{p2.played} : #{p2.percentage}"
  end
  
end


# Create players
player_1 = Player.new("Player 1")
player_2 = Player.new("Player 2")

# Create new game show
while player_1.played < 1000
  g = Game.new
  g.run(player_1, player_2)
  g.stats(player_1, player_2)

  # for terminal sanity if terminal blinks too much
  #sleep 0.02
end

