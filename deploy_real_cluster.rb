
require 'resolv'
require 'net/scp'
require 'cute'

NB = ARGV[0].to_i


if NB.nil? then

  puts "You need to specify the number of nodes"
  exit
end

# parameter subnets makes the reservation  compatible with an installation of distem

g5k = Cute::G5K::API.new()

job = g5k.reserve(:site => "rennes", :switches => 1, :nodes => NB,  :cluster => "paravance", :wait => false,
                  :walltime => "03:00:00", :type => :deploy, :name => 'distem', :subnets => [22,1],:queue => "testing")#,:vlan => :routed)
begin
  job = g5k.wait_for_job(job, :wait_time => 7200)
  puts "Nodes assigned #{job['assigned_nodes']}"
rescue  Cute::G5K::EventTimeout
  puts "We waited too long in site let's release the job and try in another site"
  g5k.release(job)
end

puts "Downloading NAS script"

`wget https://raw.githubusercontent.com/camilo1729/distem-expe/master/deploy_NAS_on_cluster.rb`

kernel_versions = ["3.2","3.16","4.0"]

kernel_versions.each do |kernel|

  puts "Testing with kernel version #{kernel}"

  g5k.deploy(job,:env => "http://public.rennes.grid5000.fr/~cruizsanabria/jessie-distem-expe_k#{kernel}.yaml")
  g5k.wait_for_deploy(job)

  puts "Generating machine file"

  nodelist = job['assigned_nodes'].uniq


  if nodelist.length > NB then

    puts "Names in the nodelist are not unique exiting"
    exit

  end

  nodelist.map!{|node| Resolv.getaddress node}

  File.open("machine_file",'w+') do |f|
    nodelist.each{ |node| f.puts node }
  end

  key_dir = Dir.mktmpdir("keys")
  system "ssh-keygen -P \'\' -f #{key_dir}/keys"
  puts "Keys generated in #{key_dir}"


  ssh_conf = Tempfile.new('config')
  File.open(ssh_conf.path,'w+') do |f|
    f.puts "Host *"
    f.puts "StrictHostKeyChecking no"
    f.puts "UserKnownHostsFile=/dev/null "
  end


  nodelist.each do |node|

    Net::SCP.start(node, "root") do |scp|
      puts "Transfering key to #{node}"
      scp.upload "#{key_dir}/keys.pub", "/root/.ssh/id_rsa.pub"
      scp.upload "#{key_dir}/keys", "/root/.ssh/id_rsa"
      scp.upload ssh_conf.path, "/root/.ssh/config"
    end

  end

  Net::SSH::Multi.start do |session|
    nodelist.each{ |node| session.use("root@#{node}")}
    session.exec! "cat .ssh/id_rsa.pub >> .ssh/authorized_keys"
  end


# running NAS benchmark
  20.times.each{
    `ruby deploy_NAS_on_real.rb #{nodelist.length}`
    sleep(5)
  }

  `mkdir -p results_kernel_#{kernel}`
  `mv profile-* results_kernel_#{kernel}/`
end
