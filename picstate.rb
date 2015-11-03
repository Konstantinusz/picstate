#!/usr/bin/ruby

require "tempfile"
require "optparse"

user_agent=%Q{User-Agent: Mozilla/5.0 (X11; Linux i686) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/45.0.2454.101 Safari/537.36}
login=""
pass=""
thumb_size="350"

OptionParser.new do |opts|
  opts.on("-a", "--auth AUTH",/.+:.+/, "login:pass") {|arg| login,pass = arg.split(":")}
  opts.on("-t", "--thumbnail THUMB_SIZE",%w(100 150 190 250 300 350 400 450 500 550 600), "thumbnail size") {|arg| thumb_size = arg}
  opts.on_tail("-h", "--help", "PicState CLI Uploader") do
      STDERR.puts opts
      exit
  end  
  begin
    opts.parse!
  rescue OptionParser::ParseError => error
    $stderr.puts error
    $stderr.puts "(-h or --help will show valid options)"
    exit 1
  end
end

begin
	cookie_file=Tempfile.new('picstate')
	cookie_file.close
	cookie_file_path=cookie_file.path
	STDERR.puts "logging in..."
	ret=%x{ curl -s 'http://picstate.com/account/login' -c #{cookie_file_path} -H 'Origin: http://picstate.com' -H 'Accept-Encoding: gzip, deflate' -H 'Accept-Language: en-US,en;q=0.8' -H 'Upgrade-Insecure-Requests: 1' -H '#{user_agent}' -H 'Content-Type: application/x-www-form-urlencoded' -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8' -H 'Cache-Control: max-age=0' -H 'Referer: http://picstate.com/login' -H 'Connection: keep-alive' --data 'action=login&task=login&return=&username=#{login}&password=#{pass}&remember=1&submit=Login' --compressed -L }
	md=/http\:\/\/picstate\.com\/myfiles\?folder_id\=([0-9]+)/.match(ret)
	folder_id=md[1]

	#get tokens & timestamp
	STDERR.puts "getting token, session_id, timestamp ..."
	ret=%x{curl -s 'http://picstate.com/multiup' -b #{cookie_file_path} -H 'Referer: http://picstate.com/multiup' -H 'Origin: http://picstate.com' -H '#{user_agent}' --compressed -L}
	md=(/\"timestamp\" *\: *\"([0-9]+)\",.*?\"token\" *\: *\"(.*?)\",.*?\"multiup_sess\" *\: *\"(.*?)\"/m).match(ret)
	timestamp=md[1]
	token=md[2]
	multiup_sess=md[3]


	abc = [('0'..'9'), ('a'..'z')].map { |i| i.to_a }.flatten

	names=ARGV.map{|a| tmp_name = "p1a32#{(0...21).map{ abc[rand(abc.length)] }.join}.jpg";[tmp_name,a] }

	names.each{|name|
	 ret=%x{curl -# 'http://picstate.com/multiuploader.php' -b #{cookie_file_path} -H 'Origin: http://picstate.com' -H 'Accept-Encoding: gzip, deflate' -H 'Accept-Language: en-US,en;q=0.8' -H '#{user_agent}' -H 'Accept: */*' -H 'Referer: http://picstate.com/multiup' -H 'Connection: keep-alive' -F "name=p1a32#{name[0]}.jpg" -F "timestamp=#{timestamp}" -F "token=#{token}" -F "multiup_sess=#{multiup_sess}" -F "upl_ver=new" -F "file=@#{name[1]};type=image/jpeg" --compressed -L }
	 STDERR.puts ret
	}

	param="#{names.collect.with_index.map{|name,i| "uploader_#{i}_tmpname=#{name[0]}&uploader_#{i}_name=#{name[1]}&uploader_#{i}_status=done"}.join("&")}&uploader_count=#{names.size}"

	ret=%x{ curl -s 'http://picstate.com/multiup' -b #{cookie_file_path} -H 'Origin: http://picstate.com' -H 'Accept-Encoding: gzip, deflate' -H 'Accept-Language: en-US,en;q=0.8' -H 'Upgrade-Insecure-Requests: 1' -H '#{user_agent}' -H 'Content-Type: application/x-www-form-urlencoded' -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8' -H 'Cache-Control: max-age=0' -H 'Referer: http://picstate.com/multiup?folder_id=#{folder_id}' -H 'Connection: keep-alive' --data 'multiup_sess=#{multiup_sess}&action=upload&#{param}&profile_id=1&folder_id=#{folder_id}&resize=#{thumb_size}&custom_resize=&per_row=0&delimiter=' --compressed -L }

	md=(/\<div class\=\"tab\-pane\" id\=\"tab2\"\>(.*?)\<\/div\>/m).match(ret)
	md=(/<textarea[^>]*\>(.*?)\<\/textarea\>/m).match(md[1])

	STDOUT.puts md[1]
ensure
  cookie_file.unlink
end

