#!/usr/bin/env ruby

# file: youtube_transcript2020.rb

require 'yawc'
require 'subunit'
require 'youtube_id'
require 'simple-config'


class YoutubeTranscript2020

  attr_reader :to_a, :author, :id, :title

  def initialize(id=nil, debug: false)

    return unless id

    @debug = debug

    @id = id[/https?:\/\//] ? YoutubeID.from(id) : id

    # Fetching the transcript from the following statement no longer works.
    # Instead, copy and paste the transcript from the YouTube video page into
    # a text file and import it.
    #
    #s = Net::HTTP.get(URI("http://video.google.com/timedtext?lang=en&v=#{@id}"))
    #@s = parse(s) unless s.empty?

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

  def to_text()
    @a.map(&:last).join("\n")
  end

  # reads a plain text transcript which has been modified to include headings
  #
  def import(obj)

    s = RXFReader.read(obj).first

    if s =~ /------+/ then
      header, body = s.split(/-----+/,2)

      h = SimpleConfig.new(header).to_h
      @id, @author, @title = h[:id], h[:author], h[:title]
      @s = body
    else
      body = obj
      raw_transcript = true
    end

    puts 'body: ' + body[0..400] if @debug
    a = body.lines.map(&:chomp).partition {|x| x =~ /\d+:\d+/ }
    @a = a[0].zip(a[1])

    @s = join_sentences(@a) if raw_transcript

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

    puts '@html_embed: ' + @html_embed.inspect if @debug
    doc = Rexle.new(@html_embed.to_s)
    puts 'before attributes'
    doc.root.attributes[:name] = 'video'
    embed = doc.xml(declaration: false)
    puts 'embed: ' + embed.inspect if @debug
    #embed = @html_embed

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
#{embed}
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

  # returns a Hash object containing the frequenecy of each word
  # level: 2 (ignores commond words including stop words)
  # level: 3 (ignores dictionary words)
  #
  def to_keywords(level: 2)
    Yawc.new(self.to_text(), level: level).to_h
  end

  private

  def fetch_info(id)

    url = "https://www.youtube.com/oembed?url=http://www.youtube.com/watch?v=#{id}&format=xml"
    s = Net::HTTP.get(URI(url))

    e = Rexle.new(s).root

    @title = e.text('title')
    @author = e.text('author_name')
    @html_embed = e.text('html').unescape
    puts '@html_embed: ' + @html_embed.inspect if @debug

  end

  def join_sentences(a)

    if @debug then
      puts 'inside join_sentence'
      puts 'a: ' + a.take(3).inspect
    end

    a2 = []

    # the following cleans up sentences that start with And, Or, But, So etc.

    (0..a.length - 1).each do |n|

      time, s = a[n]

      puts 's: ' + s.inspect if @debug

      if s[/^[a-z|0-9]|I\b|I'/] then

        if a2.any? then

          # only join two parts together if there was no full stop in
          # the previous line

          if a2[-1][-1] != /\.$/ then
            a2[-1][-1] = a2[-1][-1].chomp + ' ' + s
          else
            a2 << [time, s]
          end

        else
          a2 << [time, s.capitalize]
        end

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
      elsif s[/^\[(?:Music|Applause)\]/i]

        # ignore it
        puts 'ignoring action commentary' if @debug
        a2 << [time, '.']

        # To promote the next sentence to a new timestamp we
        # capitalize the 1st letter
        a[n+1][-1] = a[n+1][-1].capitalize if a[n+1]
      else

        if a2.any? and not a2[-1][-1] =~ /\.\s*$/ then
            a2[-1][-1] = a2[-1][-1].chomp + ' ' + s
        else
            a2 << [time, s]
        end

      end

    end

    # Remove those modified entries which were labelled [Music] etc
    a2.reject! {|time, s| s.length < 2}

    # formats the paragraph with the timestamp appearing above
    @a = a2
    a2.map {|time, s| "\n%s\n\n%s" % [time, s]}.join("\n")

  end

  def parse(s)

    doc = Rexle.new(s)

    a = doc.root.elements.each.map do |x|
      timestamp = Subunit.new(units={minutes:60, hours:60}, \
        seconds: x.attributes[:start].to_f).to_s(verbose: false)
      [timestamp, x.text.unescape.gsub("\n", ' ').gsub('&#39;',"'").gsub('&quot;','"')]
    end

    @to_a = a

    join_sentences(a)

  end

end
