Gem::Specification.new do |s|
  s.name        = 'aws-elastigroup'
  s.version     = '0.0.3'
  s.date        = '2017-01-17'
  s.summary     = "AWS Elastigroup"
  s.description = "Gem for running and managing spot instances in a production environment with failover to on-demand instances in case spot price spikes"
  s.authors     = ["Stephen Edwards"]
  s.email       = 'stephen.edwards@foostix.com'
  s.files       = ["lib/aws-elastigroup.rb"]  
  s.license       = 'MIT'
  
  s.add_runtime_dependency 'aws-sdk', '~> 2.6', '>= 2.6.44'
  s.add_runtime_dependency 'rufus-scheduler', '=3.3.2'    
end
