# find the inflection point of how ruby calculates object_ids predictably
# for example:
# x = 4; x.object_id == ( (x << 1) + 1 )
# => true
# however,
# x = 5000000000000000000; x.object_id == ( (x << 1) + 1 )
# => false

# answer = 4611686018427387903

# we'll start with a number that's close
starting_number = 4000000000000000000

# this will be the number we'll try with
current_number = starting_number

#
starting_length = starting_number.to_s.length

# our decimal position that will be used for the loop
# we don't need to start with 4, which is starting_nmber[0..0]
index = 1
digit_at_index = current_number.to_s[index..index].to_i

# digit state
digit_second = 0
digit_third = 0

# vector for current_number
# true = up, false = down
direction = true
last_direction = direction
changed_directions = 0

# have we exhausted all digits for the current rank/position
# if so, we move on to the next position
digit_done = false

jump = 5


# is our result the same as shift left plus one?
def predictable?(number)
  number.object_id == ( (number << 1) + 1 )
end


# go until we've iterated along the length of starting_number
while (index <= starting_number.to_s.length - 1)
  
  digit_at_index = current_number.to_s[index..index].to_i

  # shift our cheap history variables
  digit_third = digit_second
  digit_second = digit_at_index
  
  # this tests whether we went over our solution
  if predictable?(current_number.to_i)
    # if true, try incrementing but only if we can later
    direction = true
  else
    # if false, number is too high
    direction = false
  end
  
  #puts "index: #{index}"
  if last_direction != direction
    jump -= jump / 2
    changed_directions += 1
  else
    jump -= 1 unless jump == 1
  end
  
  last_direction = direction
  

  # split the distance
  # if we start with 0, this becomes 5 if going up
  # if we start with 5, this becomes 3 if going down
  # it's a half to target number
  if direction
    puts "increase"
    
    digit_at_index += jump unless digit_at_index == 9
    
    #puts digit_at_index
    if digit_at_index == 9 && digit_second == 9
      digit_done = true
    else
      digit_done = false
      
      if changed_directions == 4
        puts "INCREASE: #{digit_second} #{digit_third}"
        digit_done = true
        digit_at_index = digit_second
      end
      
    end
    
  # decrease
  else
        
    puts "decrease"
    digit_at_index -= jump unless digit_at_index == 0
    
    if digit_at_index == 0 && digit_second == 0
      digit_done = true
    else
      digit_done = false
      
      if changed_directions == 4
        digit_done = true
        digit_at_index = digit_third
      end
      
    end

  end

  # substitute our done digit in place
  current_number_string = current_number.to_s
  
  current_number_array = current_number_string.chars.to_a
  current_number_array[index] = digit_at_index
  current_number = current_number_array.join.to_i
  
  
  #dig_hist.push digit_at_index
  
  if digit_done
    
    # move on to the next digit
    index += 1
    digit_at_index = current_number.to_s[index..index].to_i
    digit_ceiling = 10
    digit_floor = 0
    jump = 5
    
    changed_directions = 0
    direction = true

    digit_second = 0
    digit_third = 0

    
    #dig_hist = [10]
  end
  

puts "current_number:#{current_number} index:#{index} digit_at_index:#{digit_at_index} digit_second:#{digit_second} digit_third:#{digit_third} jump:#{jump} chdir:#{changed_directions}"


# bug avoid
if current_number.to_s.length != starting_number.to_s.length
 exit
end

sleep 0.1
  
  # move one decimal place if we can't increment
  
  
end

