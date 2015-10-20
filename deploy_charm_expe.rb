require 'resolv'
require 'net/scp'
require 'cute'

# useful methods
load 'utils.rb'

NB = ARGV[0].to_i
job_name = ARGV[2]


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
CORES = metadata["container_cores"].to_i
SITE = metadata["site"]
CLUSTER = metadata["cluster"]
NUM_CONTAINERS = ARGV[1].to_i if metadata["multi_machine"] # it controls if we want to iterate with the benchmark
BENCH_REAL_TEST = metadata["bench_real_test"]

log_file = File.open(metadata["log_file"], "a")
log = Logger.new MultiIO.new(STDOUT, log_file)


log.level = Logger::INFO
#log.level = Logger::DEBUG

# parameter subnets makes the reservation  compatible with an installation of distem

g5k = Cute::G5K::API.new()


g5k.logger = log
# always take the whole switch
reserv_param = {:site => SITE,
                :switches => 1+ NB/36,
                :nodes => NB,
                :cluster => CLUSTER,
                :wait => false,
                :walltime => "03:00:00",
                :type => :deploy, :name => job_name,
  :subnets => [18,1]}

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

nodelist = job['assigned_nodes'].uniq

nodelist = nodelist[0..(NB-1)] # choosing the require amount of nodes
log.info "Running with #{NB} nodes"

KERNEL_VERSIONS.each do |kernel|

  log.info "Testing with kernel version #{kernel}"

  jessie_env = "http://public.rennes.grid5000.fr/~cruizsanabria/jessie-distem-expe_k#{kernel}.yaml"
  # g5k.deploy(job,:nodes => nodelist, :env => jessie_env)
  # g5k.wait_for_deploy(job)

  # badnodes = check_deployment(job["deploy"].last)
  # # redeploying for bad nodes
  # while not badnodes.empty? do
  #   log.info "Redeploying nodes #{badnodes}"
  #   g5k.deploy(job,:nodes => badnodes, :env => jessie_env)
  #   g5k.wait_for_deploy(job)
  #   badnodes = check_deployment(job["deploy"].last)
  # end

  if metadata["performance_check"] then
    badnodes = check_cpu_performance(nodelist,18)

    while not badnodes.empty? do
      log.info "Redeploying nodes because of performance #{badnodes}"
      g5k.deploy(job,:nodes => badnodes, :env => jessie_env)
      g5k.wait_for_deploy(job)
      badnodes = check_cpu_performance(nodelist,18)
    end
  end

  log.info "Generating machine file"

  if nodelist.length > NB then
    log.info "Names in the nodelist are not unique exiting"
    exit
  end

  iplist = nodelist.map{|node| Resolv.getaddress node}

  File.open("machine_file",'w+') do |f|
    iplist.each{ |node| f.puts node }
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
    log.info "setting parameter in the kernel for kernel migration"

    log.info "to be compatible with CHARM"
    session.exec! "echo 0 > /proc/sys/kernel/randomize_va_space"
    session.exec! "echo export https_proxy=http://proxy:3128 >> /root/.bash_profile"
    session.exec! "echo export http_proxy=http://proxy:3128 >> /root/.bash_profile"

  end

  log.info "Installing Distem"

  local_repository = "http://public.nancy.grid5000.fr/~cruizsanabria/distem.git"
 # now Install Distem into the nodes

  coordinator = iplist.first
  `ruby #{DISTEM_BOOTSTRAP_PATH}/distem-bootstrap -r "ruby-cute" -c #{coordinator} --env #{jessie_env} -g --debian-version jessie -f #{machinefile} --git-url #{local_repository} --branch lxc-kill`

  log.info "Starting containers"

  `ruby build_lxc_cluster.rb #{iplist.first} 0`

  # executing the application

  MTBF = 1
  exec_time = 400 #seconds

  log.info "Uploading files to the coordinator: #{coordinator}"
  expe_files = ["expe_charm_ft.rb","churn_node.rb"]

  Net::SCP.start(coordinator, "root") do |scp|
    expe_files.each do |file|
      #      `wget -N https://raw.githubusercontent.com/camilo1729/distem-expe/master/#{file}`
      scp.upload file, file
    end
    #scp.upload "expe_metadata.yaml", "expe_metadata.yaml"
  end

  # log.info "Adding lxc-stop -k"

  # Net::SSH.start(coordinator, 'root') do |ssh|
  #   ssh.exec!("/usr/bin/distem -q &>/dev/null")
  #   `ruby #{DISTEM_BOOTSTRAP_PATH}/distem-bootstrap -c #{coordinator} -g --debian-version jessie -f #{machinefile} --git-url #{local_repository} --branch lxc-kill`
    
  # end


  # ["sync_ft","mlogft"].each do |algo_ft|
  #   Net::SSH.start(coordinator, 'root') do |ssh|
  #     ssh.exec("ruby expe_charm_ft.rb #{algo_ft} &")
  #     log.info "Running CHURN during #{exec_time} with MTBF= #{MTBF}"
  #     ssh.exec!("ruby churn_node.rb all #{exec_time} #{MTBF}")
  #   end
  #   log.info "Getting execution output"

  #   `mkdir -p charm_ft_results`
  #   `rsync -a root@#{coordinator}:~/output-charm-ft* charm_ft_results/`

  # end
end

log.info "All experiments finished"
