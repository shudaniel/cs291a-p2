require 'sinatra'
require "google/cloud/storage"
require 'digest'


storage = Google::Cloud::Storage.new(project_id: 'cs291a')
bucket = storage.bucket 'cs291project2', skip_lookup: true
correct_string_format = /^\w{2}\/\w{2}\/\w{60}$/

get '/' do
  redirect to('/files/')
end

get '/files/' do 
  all_files = bucket.files
  filenames = []
  all_files.all do |file|
    puts file.name, file.name.match(correct_string_format)
    if file.name and file.name.match(correct_string_format)
      f_name = file.name.gsub!(/[^0-9A-Za-z]/, '')
      filenames.append(f_name)
    end
  end
  puts filenames
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

    filename = hash_contents.insert(4, "/")
    filename = filename.insert(2, "/")
    bucket.create_file StringIO.new(params["file"]["tempfile"].read), filename
    
    return 201, {"uploaded": hash_contents}
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

  puts downloaded.read
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