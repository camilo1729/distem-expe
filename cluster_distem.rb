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

  opts.on('-i', '--image <path image>', String, 'Path for the container file system') do |n|
    raise "Image file does not exist" unless File.exist?(n)
    options[:image] = "file://#{File.absolute_path(n)}"
  end

  opts.on('-u', '--user <g5k user>', String, 'Sets the g5k user necessary to get the job') do |n|
    options[:user] = n
  end

  opts.on('-r', '--cpu-ratio <ratio>', String, 'Degrades CPU the ratio specified') do |n|
    options[:cpu_ratio] = n
  end

  opts.on('-c', '--nbcores <number>', Integer, 'Specifies the number of cores per vnode') do |n|
    options[:nbcores] = n
  end

  opts.on( '--net <subnetwork>', String, 'subnet work range' ) do |c|
    options[:net] = c
  end

  opts.on( '-a', '--arp', 'pre-fill ARP tables' ) do |c|
    options[:arp] = true
  end

end

optparse.parse!

# getting job


## change the assigments of ipS
vnet = {'name' => 'testnet','address' => options[:net]}

nodelist = []


Distem.client do |cl|

  puts 'Creating virtual network'

  cl.vnetwork_create(vnet['name'],vnet['address'])

  puts 'Creating containers'

  count = 0

  pnodes = cl.pnodes_info

  private_key = IO.readlines('/root/.ssh/id_rsa').join
  public_key = IO.readlines('/root/.ssh/id_rsa.pub').join

  ssh_keys = {'private' => private_key,'public' => public_key}

  pnodes.each do |pnode|

    pnode_list = []
    options[:num_lxc].times do

      nodename = "node-#{count}"

      pnode_list.push(nodename)
      count += 1
    end

    res = cl.vnodes_create(pnode_list,{
                                    'host' => pnode[0],
                                    'vfilesystem' =>{'image' => options[:image],'shared' => true},
                                    'vifaces' => [{'name' => 'if0', 'vnetwork' => vnet['name']}]
                                      }, ssh_keys)
    nodelist+=pnode_list
  end


  if options[:cpu_ratio] then
    nodelist.each{ |vnode|
      cl.vcpu_create(vnode, options[:cpu_ratio], 'ratio', options[:nbcores])
    }
  end

  puts 'Starting containers'

  cl.vnodes_start(nodelist)

  puts 'Waiting for containers to be accessible'
  start_time = Time.now

  cl.wait_vnodes()

  cl.set_global_arptable() if options[:arp]

  puts "Initialization of containers took #{(Time.now-start_time).to_f}"

end
