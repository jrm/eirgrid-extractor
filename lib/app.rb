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
      if p.rows.size > 1
        p.preview.to_json
      else
        halt 500, "Unable to extract data from PDF"
      end
    end
  end
  
  get '/download/:id.?:format?' do
    send_file File.join(settings.data_folder, "eigrid-#{params[:id]}.#{params[:format]}")    
  end
  
end  