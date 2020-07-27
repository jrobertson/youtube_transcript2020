# Introducing the YouTube_transcript2020 gem

    require 'youtube_transcript2020'

    id = 'tlFGOSEI_lo'

    yt = YoutubeTranscript2020.new(id)
    yt.to_s
    File.write '/tmp/selfhelp.html', yt.to_html

In the above example the transcript from a YouTube video is fetched and saved to an HTML file for viewing  alongside the embedded video.

## Resources

* youtube_transcript2020 https://rubygems.org/gems/youtube_transcript2020

transcript youtube video gem
