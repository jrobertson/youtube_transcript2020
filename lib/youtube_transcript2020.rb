#!/usr/bin/env ruby

# file: youtube_transcript2020.rb

require 'subunit'
require 'simple-config'


class YoutubeTranscript2020

  attr_reader :to_a, :author, :id, :title

  def initialize(id=nil)

    return unless id

    @id = if id[/https:\/\/www\.youtube\.com\/watch\?v=/] then
      id[/(?<=^https:\/\/www\.youtube\.com\/watch\?v=).*/]
    elsif id[/https:\/\/youtu\.be\//]
      id[/(?<=^https:\/\/youtu\.be\/).*/]
    else
      id
    end

    s = Net::HTTP.get(URI("http://video.google.com/timedtext?lang=en&v=#{@id}"))
    @s = parse s

    fetch_info(@id)

  end
  
  def to_a()
    @a
  end

  # returns the transcript in plain text including timestamps
  #
  def to_s()

    h = {id: @id, title: @title, author: @author}
    SimpleConfig.new(h).to_s + "\n#{'-'*78}\n\n" + @s
  end

  # reads a plain text transcript which has been modified to include headings
  #
  def import(obj)

    s = RXFHelper.read(obj).first

    header, body = s.split(/-----+/,2)

    h = SimpleConfig.new(header).to_h
    @id, @author, @title = h[:id], h[:author], h[:title]
    @s = body
    
    a = body.lines.map(&:chomp).partition {|x| x =~ /\d+:\d+/ }    
    @a = a[0].zip(a[1])    

  end

  # Outputs HTML containing the embedded video and transcription
  #
  def to_html()

    url = 'https://www.youtube.com/embed/' + @id

    links = @a.map do |timestamp, s|
      
      seconds = Subunit.new(units={minutes:60, hours:60}, 
                  timestamp.split(':').map(&:to_i)).to_i
      "<li><a href='%s?start=%s&autoplay=1' target='video'>%s</a><p>%s</p></li> " \
          % [url, seconds, timestamp, s]
    end

<<EOF
<!DOCTYPE html>
<html lang="en">
  <head>
    <title></title>
    <meta charset="utf-8" />
  </head>
  <body>
<div style="width: 1080px; background: white">
<div style="float:left; width: 580px; background: white">
<iframe width="560" height="315" src="#{url}?start=67&autoplay=1" name="video" frameborder="0" allow="accelerometer; autoplay; encrypted-media; gyroscope; picture-in-picture" allowfullscreen></iframe>
<h1>#{@title}</h1>
</div>
<div style="float:right; width: 500px; overflow-y: scroll; height: 400px">
<ul>#{links.join("\n")}</ul>
</div>

</div>
  </body>
</html>
EOF
  end

  # Outputs plain text containing the headings including timestamps
  # note: This can be helpful for copyng and pasting directly into a YouTube comment
  #
  def to_headings()    
    
    @to_a.select {|timestamp, _| timestamp =~ / /}.map(&:first)    

  end

  private

  def fetch_info(id)
    
    url = "http://www.youtube.com/oembed?url=http://www.youtube.com/watch?v=#{id}&format=json"    
    s = Net::HTTP.get(URI(url))
    
    h = JSON.parse(s, symbolize_names: true)
    @title = h[:title]
    @author = h[:author_name]
    
  end

  def parse(s)

    doc = Rexle.new(s)

    a = doc.root.elements.each.map do |x| 
      timestamp = Subunit.new(units={minutes:60, hours:60}, \
        seconds: x.attributes[:start].to_f).to_s(verbose: false)
      [timestamp, x.text.unescape.gsub("\n", ' ').gsub('&#39;',"'").gsub('&quot;','"')]
    end

    @to_a = a

    a2 = []

    # the following cleans up sentences that start with And, Or, But, So etc.

    a.each do |time, s|

      if s[/^[a-z|0-9]/]then
        a2[-1][-1] = a2[-1][-1].chomp + ' ' + s
      elsif s[/^And,? /]
        a2[-1][-1] += ' ' + s.sub(/^And,? /,'').capitalize
      elsif  s[/^Or,? /]
        a2[-1][-1] = a2[-1][-1].chomp + ' ' + s
      elsif  s[/^But /]
        a2[-1][-1] += ' ' + s.sub(/But,? /,'').capitalize
      elsif s[/^"/]
        a2[-1][-1] = a2[-1][-1].chomp + ' ' + s
      elsif s[/^So,? /]
        a2[-1][-1] += ' ' + s.sub(/^So,? /,'').capitalize
      else
        a2 << [time, s]
      end

    end

    # formats the paragraph with the timestamp appearing above
    @a = a2
    a2.map {|time, s| "\n%s\n\n%s" % [time, s]}.join("\n")

  end

end
