require 'aws-sdk'
require 'rufus-scheduler'
require 'mini_cache'

module AWSElastigroup
  @@store = MiniCache::Store.new
  @@scheduler = Rufus::Scheduler.new
  
  attr_accessor :store, :scheduler
  
  def self.store
    @@store
  end
  
  def self.scheduler
    @@scheduler
  end
  
  class Configuration
    attr_accessor :key, :secret, :groups
    
    # Start Group class
    class Group
      attr_accessor :name, :region, :on_demand_name, :spot_name, :safe_interval
      
      def check_spot_status
        client = AWSElastigroup.aws::AutoScaling::Client.new(:region => @region)
        resource = Aws::AutoScaling::Resource.new(client: client)
        spot_group = resource.group(@spot_name)
        demand_group = resource.group(@on_demand_name)
        
        #If spot instances not running        
        if spot_group.instances.count < spot_group.desired_capacity # Spot group does not have required capacity          
          
          # Set last time spot group failed
          AWSElastigroup.store.set('aws-elastigroup-last-fail-'+@spot_name){ Time.now()}          
            
          # Set demand group to max capacity 
          if demand_group.desired_capacity != demand_group.max_size
            puts "Starting up on-demand instances"
            demand_group.set_desired_capacity({
              :desired_capacity => demand_group.max_size
            })
          end
        else # Spot group ok
          # Check how long spot instances have been running (consecutively)
          last_fail_time = AWSElastigroup.store.get('aws-elastigroup-last-fail-'+@spot_name)
          
          # Default last fail time is 30 minutes = 1800 sec
          if last_fail_time.nil?
            last_fail_time = Time.now() - 1800
          end
          last_fail = ((Time.now() - last_fail_time) / 60).floor
          
          # Get safe_interval
          safe_interval = @safe_interval
          safe_interval ||= 30 # Default safe_interval value
          
          # If spot group has passed the safer interval and demand group has running instances
          if last_fail >= safe_interval && demand_group.desired_capacity != demand_group.min_size
            
            # Stopping on-demand instances
            demand_group.set_desired_capacity({
              :desired_capacity => demand_group.min_size
            })
          end
        end
      end      
      
    end # End Group class    
    
    def initialize
      @groups = Array.new
    end
    
    def add_group
      @groups << yield(Group.new)
    end
    
  end
  
  @@config = Configuration.new
  @@aws = Aws
  
  def configure
    yield(@@config)
    @@aws.config.update({
      credentials: Aws::Credentials.new(@@config.key, @@config.secret)
    })
  end
  module_function :configure
  
  def config
    @@config
  end
  module_function :config
  
  def aws
    @@aws
  end
  module_function :aws
  
  def check_groups
    AWSElastigroup.config.groups.each do |group|
      #Check group spot status: true = ok, false = instances running < desired capacity
      puts "Checking group #{group.name}"
      group.check_spot_status
    end
  end
  module_function :check_groups
  
  def run
    AWSElastigroup.check_groups
    @@scheduler.every '1m' do
      AWSElastigroup.check_groups
    end
    
  end
  module_function :run
  
end