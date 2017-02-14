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
      
      def spot_group
        client = AWSElastigroup.aws::AutoScaling::Client.new(:region => @region)
        resource = Aws::AutoScaling::Resource.new(client: client)
        group = resource.group(@spot_name) 
      end
      
      def check_spot_status
        client = AWSElastigroup.aws::AutoScaling::Client.new(:region => @region)
        resource = Aws::AutoScaling::Resource.new(client: client)
        spot_group = resource.group(@spot_name)
        demand_group = resource.group(@on_demand_name)
        
        #If spot instances not running        
        if spot_group.instances.count < spot_group.desired_capacity # Spot group does not have required capacity          
          
          # Set last time spot group failed
          AWSElastigroup.store.set('aws-elastigroup-last-fail--'+@spot_name){ Time.now()}          
            
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
          if last_fail_time.nil?
            last_fail_time = Time.now() - 1800
          end
          last_fail = ((Time.now() - last_fail_time) / 60).floor
          safe_interval = @safe_interval
          safe_interval ||= 15 # Default safe_interval value
          
          if last_fail >= safe_interval && demand_group.desired_capacity != demand_group.min_size
            # Stopping on-demand instances
            demand_group.set_desired_capacity({
              :desired_capacity => demand_group.min_size
            })
          end
        end
      end
      
      def failover
        client = AWSElastigroup.aws::AutoScaling::Client.new(:region => @region)
        resource = Aws::AutoScaling::Resource.new(client: client)        
        on_demand_group = resource.group(@on_demand_name)
        on_demand_group.desired_capacity = on_demand_group.max_size
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
    #client = @@aws::AutoScaling::Client.new(:region => "eu-central-1")
    #resource = Aws::AutoScaling::Resource.new(client: client)
    #resource.group("foostix-app-group")
    
    #ec2 = @@aws::EC2::Client.new
    #resp = ec2.describe_spot_price_history(
    #  :instance_types => ['m4.xlarge'], 
    #  :product_descriptions => ['Linux/UNIX'],
    #  :start_time => (Time.now - 60*15).iso8601
    #)
    #resp
    
    @@scheduler.every '1m' do
      AWSElastigroup.config.groups.each do |group|
        #Check group spot status: true = ok, false = instances running < desired capacity
        puts "Checking group #{group.name}"
        group.check_spot_status
      end
    end
    
    AWSElastigroup.config.groups.each do |group|
      #Check group spot status: true = ok, false = instances running < desired capacity
      puts "Checking group #{group.name}"
      group.check_spot_status
    end

  end
  module_function :run
  
end