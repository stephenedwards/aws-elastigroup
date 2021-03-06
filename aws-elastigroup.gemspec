Gem::Specification.new do |s|
  s.name        = 'aws-elastigroup'
  s.version     = '0.0.8'
  s.date        = '2017-02-15'
  s.summary     = "AWS Elastigroup"
  s.description = "Gem for running and managing spot instances in a production environment with failover to on-demand instances in case spot price spikes"
  s.authors     = ["Stephen Edwards"]
  s.email       = 'stephen.edwards@foostix.com'
  s.files       = ["lib/aws-elastigroup.rb"]  
  s.license       = 'MIT'
  
  s.add_runtime_dependency 'aws-sdk', '~> 2.6', '>= 2.6.44'
  s.add_runtime_dependency 'rufus-scheduler', '=3.4.0'    
  s.add_runtime_dependency 'mini_cache', '~> 1.0', '>= 1.0.1'
  
end
