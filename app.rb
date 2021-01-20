require 'sinatra'
require "google/cloud/storage"
require 'digest'
require 'json'


storage = Google::Cloud::Storage.new(project_id: 'cs291a')
bucket = storage.bucket 'cs291project2', skip_lookup: true
correct_string_format = /^\w{2}\/\w{2}\/\w{60}$/

get '/' do
  redirect '/files/', 302
end

get '/files/' do 
  all_files = bucket.files
  filenames = []
  all_files.all do |file|
    if file.name and file.name.match(correct_string_format)
      f_name = file.name.gsub!(/[^0-9A-Za-z]/, '')
      filenames.append(f_name)
    end
  end
  filenames.to_json
end

post '/files/' do

  if  params["file"] and params["file"]["tempfile"] and params["file"]["tempfile"].size <= 1048576
    hash_contents = Digest::SHA2.hexdigest params["file"]["tempfile"].read
    all_files = bucket.files
    all_files.all do |file|

      if file.name and file.name.match correct_string_format 
        f_name = file.name.gsub!(/[^0-9A-Za-z]/, '')
        if f_name == hash_contents
          return 409, ''
        end
      end

    end

    response_body = {uploaded: hash_contents}
    filename = hash_contents.insert(4, "/")
    filename = filename.insert(2, "/")
  
    
    
    bucket.create_file(params["file"]["tempfile"], filename,  content_type: params["file"]["type"] )
    
    return 201, JSON.generate(response_body)
  else 
    return 422, ''
  end
end


get '/files/:digest?' do

  filepath = params['digest'].insert(4, "/")
  filepath = filepath.insert(2, "/")
  if not filepath.match(correct_string_format)
    return 422, ''
  end

  file = bucket.file filepath
  if not file
    return 404, ''
  end

  downloaded = file.download
  downloaded.rewind
  return 200, {"Content-Type"   => file.content_type}, downloaded.read
end

delete '/files/:digest?' do 
  filepath = params['digest'].insert(4, "/")
  filepath = filepath.insert(2, "/")
  if not filepath.match(correct_string_format)
    return 422, ''
  end

  file = bucket.file filepath
  if file
    file.delete
  end

  return 200, ''

end