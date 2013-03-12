Gem::Specification.new do |s|
  s.name        = "stardog-rb"
  s.version     = "0.0.3"
  s.summary     = "HTTP Bindings for Stardog RDF data base"
  s.date        = "2013-03-08"
  s.description = "Port of the JS bindings for Stardog."
  s.authors     = ["Antonio Garrote"]
  s.email       = ["antoniogarrote@gmail.com"]
  s.homepage    = "http://antoniogarrote.com/social/stream"
  s.files       = ["lib/stardog.rb"]
  s.add_runtime_dependency 'rest-client'
  s.add_runtime_dependency 'nokogiri'
end