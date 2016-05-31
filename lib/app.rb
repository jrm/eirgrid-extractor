require "sinatra/base"
require "file_processor"
require "json"

class App < Sinatra::Base
  
  set :views,  File.expand_path('../../views', __FILE__)
  set :public_folder, File.expand_path('../../views', __FILE__)
  set :data_folder, File.expand_path('../../data', __FILE__)
  
  
  
  get '/' do
    puts settings.data_folder.inspect
    haml :index 
  end
  
  post '/process' do
    puts params.inspect
    filename = params["0"][:filename]
    filepath = params["0"][:tempfile].path
    processor = FileProcessor.new(filepath, {name: filename})
    processor.process do |p|
      content_type :json
      p.json
    end
  end
  
  get '/download/:id.?:format?' do
  #get '/download/*.*' do |id, format|
    send_file File.join(settings.data_folder, "eigrid-#{params[:id]}.#{params[:format]}")    
  end
  
end  