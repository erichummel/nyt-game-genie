#!/usr/bin/env ruby

require 'optparse'

def main
  ARGV << '-h' if ARGV.empty?

  OptionParser.new do |opts|
    # opts.summary_width = 20
    opts.banner = "Usage: nyt_game_genie.rb [options]"

    opts.on("-d", "--dictionary=<path to file>", "path to newline-delimited dictionary") do |opt|
      options[:dictionary] = opt
    end
    opts.on("-l", "--letters=<letters>", "for letter boxed and spelling bee: valid game letters (including middle letter)") do |opt|
      options[:letters] = letters_only(opt)
    end
    opts.on("-x", "--max-depth=<depth>", "for letter boxed: maximum number of words in solution (defaults to 4)") do |opt|
      options[:max_depth] = opt.to_i
    end
    opts.on("-s", "--letters_per_side", "for letter boxed: the number of letters per side (defaults to 3)") do |opt|
      options[:letters_per_side] = opt.to_i
    end
    opts.on("-e", "--middle=<middle>", "for spelling bee: the middle letter") do |opt|
      options[:middle] = opt
    end
    opts.on("-j", "--javascript", "for spelling_bee: output javascript to automatically solve the puzzle") do |opt|
      options[:javascript] = true
    end
    opts.on("-p", "--patterns=<patterns>", "for wordle: comma separated regex, defaults to '.' for each letter") do |opt|
      options[:patterns] = opt.split(",").map{|re| Regexp.new(re)}
    end
    opts.on("-w", "--without=<without>", "for wordle: exclude all words containing provided letters") do |opt|
      options[:without] = letters_only(opt)
    end
    opts.on("-m", "--must-have=<must_have>", "for wordle: word must have provided letters") do |opt|
      options[:must_have] = letters_only(opt)
    end

    opts.on("-c", "--copy", "(on macOS) copy output to clipboard") do |opt|
      options[:copy] = true
    end

    opts.on("-g", "--game=GAME", "game name [(l)etter_boxed|(w)ordle|(s)pelling_bee] (only the first letter matters)") do |opt|
      case opt
      when /^l/
        options[:game] = :letter_boxed
      when /^w/
        options[:game] = :wordle
      when /^s/
        options[:game] = :spelling_bee
      else
        options[:game] = opt
      end
    end

  end.parse!

  case options[:game]
  when :letter_boxed
    require_options :dictionary, :letters
    letter_boxed

  when :wordle
    require_options :dictionary
    wordle

  when :spelling_bee
    require_options :dictionary, :letters, :middle
    spelling_bee

  else
    puts "game \"#{options[:game]}\" not recognized."
  end
end

def options
  @options ||= {
    max_depth: 4,
    letters_per_side: 3,
  }
end

def game
  options[:game]
end

def dictionary
  options[:dictionary]
end

def letters
  options[:letters]
end

def without
  options[:without]
end

def must_have
  options[:must_have]
end

def patterns
  options[:patterns]
end

def middle
  options[:middle]
end

def copy
  options[:copy]
end

def javascript
  options[:javascript]
end

def max_depth
  options[:max_depth]
end

def letters_per_side
  options[:letters_per_side]
end

def default_options(option_defaults = {})
  option_defaults.each do |name, default|
    options[name.to_sym] ||= default
  end
end

def require_options(*option_names)
  option_names.each do |name|
    if !options[name.to_sym] || options[name.to_sym].empty?
      raise "missing required option #{name} for game #{game}"
    end
  end
end

def letter_boxed
  puts "Letter Boxed:"
  solutions = letter_box_solve(letters, max_depth)

  solutions = solutions.map{|s| s.join(", ")}.join("\n")
  if copy
    to_clipboard(solutions)
  end

  puts solutions
end

def wordle
  puts "Wordle:"
  puts wordle_words(without, must_have, patterns).join("\n")
end

def spelling_bee
  puts "Spelling Bee:"
  solutions = spelling_bee_words(letters, middle)

  if javascript
    solutions = bee_template(solutions)
  else
    solutions = solutions.join("\n")
  end

  if copy
    to_clipboard(solutions)
  end

  puts solutions
end

def letters_only(str)
  str.split(/(\W+)?/).reject {|w| w =~/^\W+$/}.map(&:downcase)
end

def all_words(dictionary = "#{__dir__}/dictionaries/aoed.txt")
  @all_words ||= File.read(dictionary).split("\n")
end

def five_letter_words
  @five_letter_words ||= all_words.reject{|w| w.size != 5}
end

BEE_TEMPLATE = <<-JS
(function() {
  var words = [%{words}];

  function typeAll(words) {
    for(i = 0; i < words.length; i++) {
      setTimeout(typeWord, i * 1100, words[i]);
    }
  }

  function typeWord(word) {
    for (i = 0; i < word.length; i++) {
      pressKey(word[i]);
    }
    pressKey('Enter');
  }

  function pressKey(char) {
    var keyboardEvent = new KeyboardEvent("keydown", {
      bubbles: true,
      cancelable: true,
      view: window,
      key: char,
    });
    document.dispatchEvent(keyboardEvent);
  }

  typeAll(words);
})();
JS


def spelling_bee_words(letters, middle)
  all_words.select{|w| w =~ /^[#{letters}]+$/ }.select{|w| w =~ /#{middle}/}.select{|w| w.size >=4 }
end

def bee_template(words)
  BEE_TEMPLATE % {words: words.map{|w| "'#{w}'"}.join(",")}
end

def words_starting_with(substring, words)
  words.filter { |w| w =~ /^#{substring}/ }
end

def wordle_words(not_there = [],  must_have = [], regexes = [ /./, /./, /./, /./, /./ ])
  five_letter_words.
    reject{|w| w=~ (not_there && not_there.size > 0 ? /[#{not_there.join}]/ : /[^\s\S]/) }.
    select{|w|
      regexes.each_with_index.map do |re, index|
        w[index] =~ re
      end.inject { |memo, match| memo && match }
    }.select{|w|
      must_have.map{|m| w =~ /#{m}/}.inject{|w, memo| w && memo}
    }
end

def letter_box_solve(letters, max_depth, per_side=letters_per_side, words = all_words)
  words = letter_box_words(letters, per_side, words)
  puts "Found #{words.size} words. Finding solutions of max depth #{max_depth}"
  chain(words, letters, max_depth).sort_by{|solution| solution.size * solution.flatten.join.size }
end

def chain(words, letters, so_far = [], max_depth)
  if so_far.join('').split('').uniq.sort == letters.uniq.sort
    return [so_far]
  end

  return [] if so_far.size >= max_depth

  solutions = []
  words.each do |word|
    rest = words - [word]
    solutions += chain(words_starting_with(word[-1], rest), letters, so_far + [word], max_depth)
  end.reject(&:empty?)

  solutions
end

def slice_letters(letters, per_side)
  letters.each_slice(per_side).to_a
end

def letter_box_words(letters, per_side, words, needle = '', except = [], found = [])
  sides = slice_letters(letters, per_side)
  return found if words.size == 0
  (sides - [except]).each do |this_side|
    this_side.each do |letter|
      search = needle + letter
      matches = words_starting_with(search, words)
      if (leaf = matches.find {|w| w == search }) && leaf.size >= 3
        found << leaf
      end
      letter_box_words(letters, per_side, matches - [(leaf || '')], search, this_side, found)
    end
  end
  found.sort_by(&:size).reverse
end

def to_clipboard(s)
  IO.popen("pbcopy", mode="r+") do |io|
    io.write(s)
    io.close_write
  end
end

def from_clipboard
  `pbpaste`
end

main
