
require 'resolv'
require 'net/scp'
require 'cute'

# useful methods
load 'utils.rb'

NB = ARGV[0].to_i
job_name = ARGV[1]


job_name = "distem" if job_name.nil?

if NB.nil? then

  puts "You need to specify the number of nodes"
  exit
end

## getting experiment metadata
metadata = YAML.load(File.read("expe_metadata.yaml"))
DISTEM_BOOTSTRAP_PATH=metadata["distem_bootstrap_path"]
RUNS = metadata["runs"]
KERNEL_VERSIONS = metadata["kernel_versions"]
CORES = metadata["container_cores"]
SITE = metadata["site"]
CLUSTER = metadata["cluster"]

log_file = File.open(metadata["log_file"], "a")
log = Logger.new MultiIO.new(STDOUT, log_file)


log.level = Logger::INFO
#log.level = Logger::DEBUG

# parameter subnets makes the reservation  compatible with an installation of distem

g5k = Cute::G5K::API.new()

# always take the whole switch
reserv_param = {:site => SITE,
                :switches => 1+ NB/36,
                :nodes => NB,
                :cluster => CLUSTER,
                :wait => false,
                :walltime => "02:00:00",
                :type => :deploy, :name => job_name,
                :subnets => [18,1],:queue => "testing"}#,:vlan => :routed)

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

log.info "Downloading necessary scripts"

`wget https://raw.githubusercontent.com/camilo1729/distem-expe/master/deploy_NAS_on_cluster.rb`
`wget https://raw.githubusercontent.com/camilo1729/distem-expe/master/expe_NAS_distem.rb`

nodelist = job['assigned_nodes'].uniq

nodelist = nodelist[0..(NB-1)] # choosing the require amount of nodes
log.info "Running with #{NB} nodes"

KERNEL_VERSIONS.each do |kernel|

  log.info "Testing with kernel version #{kernel}"

  jessie_env = "http://public.rennes.grid5000.fr/~cruizsanabria/jessie-distem-expe_k#{kernel}.yaml"
  g5k.deploy(job,:nodes => nodelist, :env => jessie_env)
  g5k.wait_for_deploy(job)

  badnodes = check_deployment(job["deploy"].last)
  # redeploying for bad nodes
  while not badnodes.empty? do
    log.info "Redeploying nodes #{badnodes}"
    g5k.deploy(job,:nodes => badnodes, :env => jessie_env)
    g5k.wait_for_deploy(job)
    badnodes = check_deployment(job["deploy"].last)
  end


  badnodes = check_cpu_performance(nodelist,18)

  while not badnodes.empty? do
    log.info "Redeploying nodes because of performance #{badnodes}"
    g5k.deploy(job,:nodes => badnodes, :env => "http://public.rennes.grid5000.fr/~cruizsanabria/jessie-distem-expe_k#{kernel}.yaml")
    g5k.wait_for_deploy(job)
    badnodes = check_cpu_performance(nodelist,18)
  end


  log.info "Generating machine file"
  if nodelist.length > NB then

    log.info "Names in the nodelist are not unique exiting"
    exit

  end

  File.open("machine_file",'w+') do |f|
    nodelist.each{ |node| f.puts node }
    # Writing IP of hosts comment out if it necessary
    # iplist = nodelist.map{|node| Resolv.getaddress node}
    # iplist.each{ |node| f.puts node }
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
  end

  log.info "Experiments will run with #{nodelist.length} machines"

# running NAS benchmark
  `ruby deploy_NAS_on_cluster.rb #{nodelist.length} #{RUNS}`

  `mkdir -p real_k#{kernel}`
  `mv profile-* real_k#{kernel}/`

  log.info "Starting tests with Containers"

 # now Install Distem into the nodes
  `ruby #{DISTEM_BOOTSTRAP_PATH}/distem-bootstrap -r "ruby-cute" -c #{nodelist.first} --env #{jessie_env} -g --debian-version jessie --nodefile #{machinefile}`
  `ruby expe_NAS_distem.rb #{nodelist.first} #{CORES}`

  `mv distem_temp/ distem_k#{kernel}/`
end
