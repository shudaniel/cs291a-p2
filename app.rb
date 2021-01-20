require 'sinatra'
require "google/cloud/storage"
require 'digest'
require 'json'
require 'tempfile'


storage = Google::Cloud::Storage.new(project_id: 'cs291a')
bucket = storage.bucket 'cs291project2', skip_lookup: true
correct_string_format = /^[0-9a-f]{2}\/[0-9a-f]{2}\/[0-9a-f]{60}$/


get '/' do
  redirect '/files/', 302
end

get '/files/' do 
  all_files = bucket.files
  filenames = []
  all_files.all do |file|
    if file.name and file.name.match(correct_string_format)
      f_name = file.name.dup
      f_name = f_name.delete "/"
      filenames.append(f_name)
    end
  end
  filenames.to_json
end

post '/files/' do

  if params["file"] and params["file"]["tempfile"] and params["file"]["tempfile"].is_a?(Tempfile)
    puts params["file"]
    puts "SIZE", params["file"]["tempfile"].size
  end

  if  params["file"] and params["file"]["tempfile"] and params["file"]["tempfile"].is_a?(Tempfile) and  params["file"]["tempfile"].size <= 1048576
    hash_contents = Digest::SHA2.hexdigest params["file"]["tempfile"].read
    response_body = {uploaded: hash_contents.dup}

    hash_contents.insert(4, "/")
    hash_contents.insert(2, "/")
    file = bucket.file hash_contents
    if file
      return 409, ''
    end

    # all_files = bucket.files
    # all_files.all do |file|

    #   if file.name and file.name.match correct_string_format 
    #     f_name = file.name.gsub!(/[^0-9A-Za-z]/, '')
    #     if f_name == hash_contents
    #       return 409, ''
    #     end
    #   end

    # end

    
    
    bucket.create_file(params["file"]["tempfile"], hash_contents,  content_type: params["file"]["type"] )
    
    return 201, JSON.generate(response_body)
  else 
    return 422, ''
  end
end


get '/files/:digest?' do

  filepath = params['digest'].dup
  filepath = filepath.downcase
  filepath.insert(4, "/")
  filepath.insert(2, "/")
  puts "GET DIGEST match", filepath, filepath.match(correct_string_format)
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
  filepath = params['digest'].dup
  filepath = filepath.downcase
  filepath.insert(4, "/")
  filepath.insert(2, "/")
  puts "DELETE DIGEST match", filepath, filepath.match(correct_string_format)
  if not filepath.match(correct_string_format)
    return 422, ''
  end
  file = bucket.file filepath
  if file
    file.delete
  end

  return 200, ''

end