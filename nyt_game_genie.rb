def all_words(dictionary = "#{__dir__}/aoed.txt")
  @all_words ||= File.read(dictionary).split("\n")
end

def five_letter_words
  @five_letter_words ||= all_words.reject{|w| w.size != 5}
end

def filtered_words_to_clipboard(letters, middle)
  filtered = all_words.select{|w| w =~ /^[#{letters}]+$/ }.select{|w| w =~ /#{middle}/}.select{|w| w.size >=4 }

  to_clip = %Q{words = [#{filtered.map{|w| "'#{w}'" }.join(',') }]}
  IO.popen("pbcopy", "w") {|f| f.puts to_clip }
end

def words_starting_with(substring, words)
  words.filter { |w| w =~ /^#{substring}/ }
end

def wordle_words(not_there = [],  regexes = [ /./, /./, /./, /./, /./ ])
  five_letter_words.
    reject{|w| w=~ /[#{not_there.join}]/}.
    select{|w|
      regexes.each_with_index.map do |re, index|
        w[index] =~ re
      end.inject { |memo, match| memo && match }
    }
end

def slice_letters(letters)
  letters.each_slice(3).to_a
end

def letter_box_words(letters, words = all_words, needle = '', except = [], found = [])
  sides = slice_letters(letters)
  return found if words.size == 0
  (sides - [except]).each do |this_side|
    this_side.each do |letter|
      search = needle + letter
      matches = words_starting_with(search, words)
      if (leaf = matches.find {|w| w == search }) && leaf.size >= 3
        found << leaf
      end
      letter_box_words(letters, matches - [(leaf || '')], search, this_side, found)
    end
  end
  found.sort_by(&:size).reverse
end

def letter_box_solve(letters)
  words = letter_box_words(letters)
  puts "Found #{words.size} words."
  chain(words, letters).sort_by{|solution| solution.size * solution.flatten.join.size }
end

def chain(words, letters, so_far = [], max_depth = 4)
  if so_far.join('').split('').uniq.sort == letters.uniq.sort
    return [so_far]
  end

  return [] if so_far.size >= max_depth

  solutions = []
  words.each do |word|
    rest = words - [word]
    solutions += chain(words_starting_with(word.last, rest), letters, so_far + [word])
  end.reject(&:empty?)

  solutions
end

def copy(s)
  IO.popen("pbcopy", mode="r+") do |io|
    io.write(s)
    io.close_write
  end
end

def paste
  `pbpaste`
end
