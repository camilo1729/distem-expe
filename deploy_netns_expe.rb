require 'resolv'
require 'net/scp'
require 'cute'
require 'socket'

# useful methods
load 'utils.rb'

NB = ARGV[0].to_i

raise "You must specify the number of nodes" if NB.nil?

WALLTIME = ARGV[1].to_s || "2:00:00"

## getting experiment metadata
metadata = YAML.load(File.read("expe_metadata.yaml"))
job_name = metadata["job_name"]
RUNS = metadata["runs"]
CORES = metadata["container_cores"].to_i


log_file = File.open(metadata["log_file"], "a")
log = Logger.new MultiIO.new(STDOUT, log_file)

log.level = Logger::INFO
#log.level = Logger::DEBUG

# parameter subnets makes the reservation  compatible with an installation of distem

log.info "Downloading necessary scripts"

`wget -N https://raw.githubusercontent.com/camilo1729/distem-expe/master/deploy_NAS_on_cluster.rb`

g5k = Cute::G5K::API.new()

old_jobs = g5k.get_my_jobs(g5k.site).select{ |j| j["name"] == job_name}

raise "You need a job running" if old_jobs.empty?

job = old_jobs.first

nodelist = job['assigned_nodes'].uniq

nodelist = nodelist[0..(NB-1)] # choosing the require amount of nodes
log.info "Running with #{NB} nodes"

test_num = 1
loop do

  log.info "deploying based environment"

  jessie_env = "http://public.rennes.grid5000.fr/~cruizsanabria/jessie-kernel-git.yaml"

  `ruby deploy_cluster.rb -n #{NB} -w #{WALLTIME} -e #{jessie_env}`

  machinefile = File.absolute_path("machine_file")
  log.info "Installing new kernel"
  install_kernel(nodelist)
  log.info "rebooting nodes into the new kernel"
  `kareboot3 -f #{machinefile} -l hard`


  if metadata["performance_check"] then
    badnodes = check_cpu_performance(nodelist,18)

    while not badnodes.empty? do
      log.info "Redeploying nodes because of performance #{badnodes}"
      g5k.deploy(job,:nodes => badnodes, :env => jessie_env)
      g5k.wait_for_deploy(job)
      badnodes = check_cpu_performance(nodelist,18)
    end
  end

  cores = CORES > 1 ? CORES : 1

  log.info "Experiments will run with #{num_machines} machines"

  File.open("machine_file",'w+') do |f|
    nodelist[0..(num-1)].each do |node|
      cores.times{f.puts node }
    end
  end

  `ruby deploy_NAS_on_cluster.rb #{num*cores} #{RUNS}`

  `mkdir -p real#{test_num}`
  `mv profile-* real#{test_num}`

  log.info "Deploying NETNS"

  net = g5k.get_subnets(job)
  ips = net[1].map{ |ip| ip}
  ips.pop #Get rid of the last ip
  ips.shift #Get rid of the first ip
  vnode_ips = []
  nodelist.each do |node|

    log.info "Creating scripts"

    File.open("script_#{node}",'w+') do |f|
      f.puts "DEBIAN_FRONTEND=noninteractive apt-get install -q -y bridge-utils"
      f.puts "export http_proxy=http://proxy:3128"
      f.puts "export https_proxy=http://proxy:3128"
      f.puts "gem install ruby-cute"
      f.puts "brctl addbr br0"
      ip_node = IPSocket.getaddress(node)
      f.puts "ip addr add dev br0 #{ip_node}/20"
      f.puts "ip link set dev br0 up"
      f.puts "brctl addif br0 eth0"
      f.puts "ifconfig eth0 0.0.0.0 up"

      ip_reserv = ips.pop
      f.puts "ifconfig br0:1 #{ip_reserv.to_string} netmask #{net[1].netmask}"
      # it is not necessary because it is added automatically by the command ifconfig
      #f.puts "ip route add #{net[1].to_string} via #{ip_reserv.address} dev br0"

      # For the moment the rennes gateway is hardcoded

      f.puts "ip route add default via 172.16.111.254"
      f.puts "ip link add name ext1 type veth peer name int0"
      f.puts "ip link set ext1 up"
      f.puts "brctl addif br0 ext1"

      ip_vnode = ips.shift
      vnode_ips.push(ip_vnode.address)
      f.puts "ip netns add vnode"
      f.puts "ip link set dev int0 netns vnode"
      f.puts "ip netns exec vnode ip addr add  #{ip_vnode.to_string} dev int0"
      f.puts "ip netns exec vnode ip link set dev int0 up"
      # loopback interface necessary for MPI
      f.puts "ip netns exec vnode ip link set dev lo up"
      f.puts "ip netns exec vnode /usr/sbin/sshd -p 22"
    end

    Net::SCP.start(node, "root") do |scp|
      log.info "Transfering script to  #{node}"
      scp.upload "script_#{node}","script_#{node}"
    end

    Net::SSH.start(node, "root") do |ssh|
      log.info "Setting up bridge in node: #{node}"
      ssh.exec! "chmod +x script_#{node}"
      ssh.exec! "bash script_#{node}"

    end

  end

  log.info "Running NAS inside NETNS"
  log.info "Creating new machine files for VNODES"
  File.open("vnode_ips",'w+') do |f|
    vnode_ips.each{ |ip|
      cores.times{f.puts ip}
    }
  end

  Net::SCP.start(nodelist.first, "root") do |scp|
      log.info "Transferring vnodes machine file  #{nodelist.first}"
      scp.upload "vnode_ips", "machine_file"
      scp.upload "deploy_NAS_on_cluster.rb", "deploy_NAS_on_cluster.rb"
      scp.upload "expe_metadata.yaml","expe_metadata.yaml"
  end

  Net::SSH.start(nodelist.first, "root") do |ssh|
      log.info "Executing NAS in: #{nodelist.first}"
      ssh.exec! "ruby deploy_NAS_on_cluster.rb #{nodelist.length*cores} #{RUNS}"
  end

  `mkdir -p distem#{test_num}`
  `rsync -av root@#{nodelist.first}:~/profile-* distem#{test_num}/`
  test_num+=1
end

log.info "All experiments finished"
