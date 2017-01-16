require 'aws-sdk'
require 'rufus-scheduler'

module AWSElastigroup
  class Configuration
    class Group
      attr_accessor :name, :region, :on_demand_name, :spot_name
      
      def spot_group
        client = AWSElastigroup.aws::AutoScaling::Client.new(:region => @region)
        resource = Aws::AutoScaling::Resource.new(client: client)
        group = resource.group(@spot_name) 
      end
      
      def check_spot_status
        client = AWSElastigroup.aws::AutoScaling::Client.new(:region => @region)
        resource = Aws::AutoScaling::Resource.new(client: client)
        group = resource.group(@spot_name)
        puts group.status
        return (group.instances.count == group.desired_capacity)
      end
      
      def failover
        client = AWSElastigroup.aws::AutoScaling::Client.new(:region => @region)
        resource = Aws::AutoScaling::Resource.new(client: client)        
        on_demand_group = resource.group(@on_demand_name)
        on_demand_group.desired_capacity = on_demand_group.max_size
      end
    end
          
    attr_accessor :key, :secret, :groups
    
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
    
    @@scheduler = Rufus::Scheduler.new
    
    @@scheduler.every '15s' do
      AWSElastigroup.config.groups.each do |group|
        #Check group spot status: true = ok, false = instances running < desired capacity
        puts "Checking group #{group.name}"
        
        status = group.check_spot_status
        
        puts "Group '#{group.name}' spot status: #{status}"
      end
    end

  end
  module_function :run
  
end