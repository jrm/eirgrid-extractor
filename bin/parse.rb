#!/usr/bin/env ruby


require 'bundler'
Bundler.require :default

LoadPath.configure do
   add sibling_directory('lib')
   add child_directory('lib')
end

require 'file_processor'



processor = FileProcessor.new('input.pdf')


processor.to_csv