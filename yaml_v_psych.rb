#! /usr/bin/env ruby

require 'benchmark'
require 'yaml'
require 'psych'
require 'ydl'

n = 100
puts "Loading files #{n} times..."
Benchmark.bm(10) do |x|
  x.report('YAML') { n.times { YAML.load_file('/home/ded/.ydl/lawyers.ydl') } }
  x.report('Psych') { n.times { Psych.load_file('/home/ded/.ydl/lawyers.ydl') } }
  x.report('Ydl') { n.times { Ydl.load_file('/home/ded/.ydl/lawyers.ydl') } }
end
puts "Done."
