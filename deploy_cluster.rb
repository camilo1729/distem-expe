require 'resolv'
require 'net/scp'
require 'cute'
require 'optparse'

load 'utils.rb'

options = {}


optparse = OptionParser.new do |opts|

  opts.on( '-n', '--nodes <number>',Integer,'Number of physical machines to deploy') do |n|
    raise "You have to specify the number of nodes" if n.nil?
    options[:nodes] = n.to_i
  end

  opts.on('-w', '--walltime <time>', String, 'Walltime for the job') do |n|
    options[:walltime] = n || "2:00:00"
  end

  opts.on('--nodeploy', String, 'Sets the g5k user necessary to get the job') do |n|
    options[:user] = n
  end

  opts.on('-e', '--env <environment>', String, 'Kadeploy environment') do |n|
    options[:env] = n || "jessie-x64-nfs"
  end

end

## getting experiment metadata

metadata = YAML.load(File.read("expe_metadata.yaml"))
job_name = metadata["job_name"]

SITE = metadata["site"]
CLUSTER = metadata["cluster"]

log_file = File.open(metadata["log_file"], "a")
log = Logger.new MultiIO.new(STDOUT, log_file)

log.level = Logger::INFO
#log.level = Logger::DEBUG

# parameter subnets makes the reservation  compatible with an installation of distem
g5k = Cute::G5K::API.new()

#Reassigning the logger for capturing Grid'5000 API output
g5k.logger = log

# always take nodes on the same switch
reserv_param = {:site => SITE,
                :switches => 1+ options[:nodes]/36,
                :nodes => options[:nodes],
                :cluster => CLUSTER,
                :wait => false,
                :walltime => options[:walltime],
                :type => :deploy, :name => job_name,
                :subnets => [18,1]}#,:vlan => :routed)

# In case we have already a reservation
old_jobs = g5k.get_my_jobs(g5k.site).select{ |j| j["name"] == job_name}

job = old_jobs.empty? ? g5k.reserve(reserv_param) : old_jobs.first

begin
  job = g5k.wait_for_job(job, :wait_time => 7200)
  log.info "Nodes assigned #{job['assigned_nodes']}"
rescue  Cute::G5K::EventTimeout
  log.info "We waited too long in site let's release the job and try in another site"
  g5k.release(job)
end

nodelist = job['assigned_nodes'].uniq

nodelist = nodelist[0..(options[:nodes]-1)] # choosing the require amount of nodes

log.info "Running with #{options[:nodes]} nodes"

log.info "Deploying environment: #{options[:nodes]}"

g5k.deploy(job,:nodes => nodelist, :env => options[:env])
g5k.wait_for_deploy(job)
badnodes = g5k.check_deployment(job["deploy"].last)

# redeploying for bad nodes
while not badnodes.empty? do
  log.info "Redeploying nodes #{badnodes}"
  g5k.deploy(job,:nodes => badnodes, :env => options[:env])
  g5k.wait_for_deploy(job)
  badnodes = check_deployment(job["deploy"].last)
end

if metadata["performance_check"] then
  badnodes = check_cpu_performance(nodelist,18)

  while not badnodes.empty? do
    log.info "Redeploying nodes because of performance #{badnodes}"
    g5k.deploy(job,:nodes => badnodes, :env => options[:env])
    g5k.wait_for_deploy(job)
    badnodes = check_cpu_performance(nodelist,18)
  end
end

log.info "Generating machine file"

if nodelist.length > options[:nodes] then
  raise "Names in the nodelist are not unique exiting"
end

#  iplist = nodelist.map{|node| Resolv.getaddress node}

File.open("machine_file",'w+') do |f|
  nodelist.each{ |node| f.puts node }
end

machinefile = File.absolute_path("machine_file")

key_dir = Dir.mktmpdir("keys")
system "ssh-keygen -P \'\' -f #{key_dir}/keys"
log.info "Keys generated in #{key_dir}"

ssh_conf = Tempfile.new('config')
File.open(ssh_conf.path,'w+') do |f|
  f.puts "Host *"
  f.puts "StrictHostKeyChecking no"
  f.puts "UserKnownHostsFile=/dev/null "
end

nodelist.each do |node|

  Net::SCP.start(node, "root") do |scp|
    log.info "Transfering key to #{node}"
    scp.upload "#{key_dir}/keys.pub", "/root/.ssh/id_rsa.pub"
    scp.upload "#{key_dir}/keys", "/root/.ssh/id_rsa"
    scp.upload ssh_conf.path, "/root/.ssh/config"
  end

end

Net::SSH::Multi.start do |session|
  nodelist.each{ |node| session.use("root@#{node}")}
  session.exec! "cat .ssh/id_rsa.pub >> .ssh/authorized_keys"
  log.info session.exec! "uname -a"

  log.info "Setting http proxy"

  session.exec! "echo export https_proxy=http://proxy:3128 >> /root/.bash_profile"
  session.exec! "echo export http_proxy=http://proxy:3128 >> /root/.bash_profile"

  log.info "setting parameter in the kernel for kernel migration"
  log.info "to be compatible with CHARM"

  session.exec! "echo 0 > /proc/sys/kernel/randomize_va_space"
end

log.info "Cluster setup finished"
