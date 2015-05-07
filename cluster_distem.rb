#!/usr/bin/ruby

require 'distem'
require 'cute'
require 'optparse'

options = {}

options[:num_lxc] = 2

optparse = OptionParser.new do |opts|

  opts.on( '-n', '--number-lxc <number>',Integer,'Number of containers to deploy per physical machine') do |n|
    options[:num_lxc] = n.to_i
  end

  opts.on( '-p', '--number-p <number>',Integer,'Number of containers Pnodes') do |n|
    options[:num_pn] = n.to_i
  end

  opts.on('-i', '--image <path image>', String, 'Path for the container file system') do |n|
    raise "Image file does not exist" unless File.exist?(n)
    options[:image] = "file://#{File.absolute_path(n)}"
  end

  opts.on('-u', '--user <g5k user>', String, 'Sets the g5k user necessary to get the job') do |n|
    options[:user] = n
  end

  opts.on('-c', '--cpu <ratio>', String, 'Degrades CPU the ratio specified') do |n|
    options[:cpu_ratio] = n
  end

end

optparse.parse!

# getting job

g5k_api = {:uri => "https://api.grid5000.fr/",
           :user => options[:user],
           :version => "sid"}

g5k = Cute::G5K::API.new(g5k_api)

job = g5k.get_my_jobs(g5k.site).select{ |j| j["name"] == "distem"}.first

nodes = job["assigned_nodes"]

nodes = nodes[0..(options[:num_pn]-1)] if options[:num_pn]

net = g5k.get_subnets(job).first

vnet = {'name' => 'testnet','address' => net.to_string}

nodelist = []

Distem.client do |cl|

  puts 'Creating virtual network'

  cl.vnetwork_create(vnet['name'],vnet['address'])

  puts 'Creating containers'

  count = 0

  private_key = IO.readlines('/root/.ssh/id_rsa').join
  public_key = IO.readlines('/root/.ssh/id_rsa.pub').join

  ssh_keys = {'private' => private_key,'public' => public_key}

  nodes.each do |pnode|

    pnode_list = []
    options[:num_lxc].times do

      nodename = "node-#{count}"

      pnode_list.push(nodename)
      count += 1
    end

    res = cl.vnodes_create(pnode_list,{
                                    'host' => pnode,
                                    'vfilesystem' =>{'image' => options[:image],'shared' => true},
                                    'vifaces' => [{'name' => 'if0', 'vnetwork' => vnet['name']}]
                                      }, ssh_keys)
    nodelist+=pnode_list
  end


  if options[:cpu_ratio] then
    nodelist.each{ |vnode|
      cl.vcpu_create(vnode, :cpu_ratio, 'ratio', 1)
    }
  end



  puts 'Starting containers'

  cl.vnodes_start(nodelist)

  puts 'Waiting for containers to be accessible'
  start_time = Time.now

  cl.wait_vnodes()

  puts "Initialization of containers took #{(Time.now-start_time).to_f}"

end
