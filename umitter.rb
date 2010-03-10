#! /usr/bin/ruby -Ku

require 'net/http'
require 'kconv'
require 'yaml'
require 'rexml/document'
require 'uri'

$locate = Dir::pwd

class Umitter
  attr_accessor :user, :password, :message

  def initialize
    config = YAML.load_file("#{$locate}/config.yml")
    @user = config[:user]
    @password = config[:password]
    @message = YAML.load_file("#{$locate}/message.yml")
  end

  def twitter_write(msg)
    msg_utf8 = Kconv.toutf8(msg)

    Net::HTTP.version_1_2
    req = Net::HTTP::Post.new('/statuses/update.json')
    req.basic_auth(@user, @password)
    req.body = 'status=' + URI.encode(msg_utf8)

    res = ""
    Net::HTTP.start('twitter.com', 80) do |http|
      res = http.request(req)
    end
  end

end


def e2j(eng)
  eng.downcase.gsub("east", "東").gsub("north", "北").gsub("south", "南").gsub("west", "西").gsub("e", "東").gsub("n", "北").gsub("s", "南").gsub("w", "西")
end

def convert_rss2string(info)
  converted_info = Array.new

  info.each do |info|
    info_utf8 = Kconv.toutf8(info).split(": ")

    if ("Temperature".eql?(info_utf8.first))
      converted_info.push(info_utf8.last.split(" / ").last.scan(/\d+/).pop + "℃")
    elsif ("Wind Direction".eql?(info_utf8.first))
      converted_info.push(e2j(info_utf8.last))
    elsif ("Wind Speed".eql?(info_utf8.first))
      km = info_utf8.last.scan(/\d+km\/h/).pop.to_i
      m = km * 1000 / 3600
      converted_info.push("#{m}m/s")
    else
      converted_info.push(info_utf8.last)
    end
  end
  return converted_info
end

def get_wheter_info_from_rss
  tag_reg = %r((</?)([a-z]+)([^>]*)(/?>))
  Net::HTTP.version_1_2
  req = Net::HTTP::Get.new('/auto/rss_full/global/stations/47930.xml')
  http = Net::HTTP.start('rss.wunderground.com', 80)
  res = http.request(req)

  doc = REXML::Document.new(res.body)
  link = doc.elements['rss/channel/item[1]/link'].text
  description = doc.elements['rss/channel/item[1]/description'].text
  
  info = description.strip.split(" | ").to_a
  converted_info = convert_rss2string(info)

  return converted_info.push(link)
end

def get_wheter_info_from_html
  file_name = "47930.html"
  uri = "http://nihongo.wunderground.com/global/stations/"
  system("/usr/bin/wget -q #{uri}#{file_name} -O #{$locate}/#{file_name}")
  system("/usr/bin/nkf -w --overwrite #{$locate}/#{file_name}")
  system("/bin/chmod 777 #{$locate}/#{file_name}")
  tag_reg = %r((</?)([a-z]+)([^>]*)(/?>))

  kousin = ""
  kion = nil
  tenki = ""
  huusoku = ""
  kazamuki = ""

  start_flg = FALSE
  kazamuki_flg = FALSE
  File.open("#{$locate}/#{file_name}").each do |line|

    if line.index("Okinawa, JP (Airport)")or line.index("Naha City, JP (Airport)")
      start_flg = TRUE
    end

    if line.index("Elevation:")
      start_flg = FALSE
    end
    
    if start_flg
      line.chomp!.strip!

      kousin = line.gsub(tag_reg, "") if line.index("JST")
      
      kion ||= line.gsub(tag_reg, "").gsub("\&nbsp;", "") if line.index("℃")

      tenki = line.gsub(tag_reg, "") if line.index("div class=\"b\" style=\"font-size: 14px;\"");

      if line.index("m/s")
        huusoku = line.gsub(tag_reg, "").gsub("\&nbsp;", "").gsub("/ ", "")
      end

      
      if kazamuki_flg
        kazamuki = line
        kazamuki_flg = FALSE
      end

      if line.index("winddir")
        kazamuki_flg = TRUE
      end

    end
  end

  system("/bin/rm -rf #{$locate}/#{file_name}")
  return kousin, kion, tenki, huusoku, kazamuki
end

def get_message(key)
  msg = $message[key]
  #keyが設定されていなかった場合ファイルに追加する。
  if msg.nil?
    msg = ""
    unless key.empty?
      f = File.open("#{$locate}/message.yml", 'a')
      f.puts "#{key}: #{key}ってなに？ わからないよ"
      f.close
    end
  end
  return msg
end

def analyse_tenki
  line = ""
  point = ""
  link = ""
  tenki_comment = ""
  result = Array.new

  kion, situdo, kiatu, tenki, kazamuki, huusoku, kousin, link = get_wheter_info_from_rss

  point = get_message(kazamuki)
#  tenki_comment = get_message(tenki)
  link = "( " + link +  ")"

  line = ["気温:"+kion, "天気:" + tenki, "風速:" + huusoku, "風向き:" + kazamuki, kousin + "現在" , link].join(" ")

  result.push(line)

  unless point.empty?
    result.push(point)
  end

  unless tenki_comment.empty?
    result.push(tenki_comment)
  end

  return result
end

# main

$message = YAML.load_file("#{$locate}/message.yml")
lines = analyse_tenki

#twitter_write(lines.first)
lines.each do |line|
  twitter_write(line)
  sleep 10
#  puts line
end
