#!/usr/bin/env ruby


require 'bundler'
Bundler.require :default

LoadPath.configure do
   add sibling_directory('lib')
   add child_directory('lib')
end

require 'file_processor'



processor = FileProcessor.new('./data/input.pdf')

processor.process do |p|
  if p.rows.size > 1
    p.preview.to_json
  else
    puts "Unable to extract data from PDF"
  end
end
