require 'bundler'
Bundler.require :default

LoadPath.configure do
   add sibling_directory('lib')
   add child_directory('lib')
end

require 'app'
run App
