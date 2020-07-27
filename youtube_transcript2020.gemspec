Gem::Specification.new do |s|
  s.name = 'youtube_transcript2020'
  s.version = '0.1.0'
  s.summary = 'Makes it easier to digest a Youtube video by reading the transcript.'
  s.authors = ['James Robertson']
  s.files = Dir['lib/youtube_transcript2020.rb']
  s.add_runtime_dependency('subunit', '~> 0.5', '>=0.5.2')
  s.add_runtime_dependency('simple-config', '~> 0.7', '>=0.7.1')    
  s.signing_key = '../privatekeys/youtube_transcript2020.pem'
  s.cert_chain  = ['gem-public_cert.pem']
  s.license = 'MIT'
  s.email = 'james@jamesrobertson.eu'
  s.homepage = 'https://github.com/jrobertson/youtube_transcript2020'
end
