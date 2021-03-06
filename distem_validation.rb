require 'resolv'
require 'net/scp'
require 'cute'

# useful methods
load 'utils.rb'

NB = ARGV[0].to_i

raise "You must specify the number of nodes" if NB.nil?

WALLTIME = ARGV[1].to_s || "2:00:00"

no_deploy = ARGV[2].to_s

## getting experiment metadata
metadata = YAML.load(File.read("expe_metadata.yaml"))
job_name = metadata["job_name"]
DISTEM_BOOTSTRAP_PATH=metadata["distem_bootstrap_path"]
RUNS = metadata["runs"]
KERNEL_VERSIONS = metadata["kernel_versions"]
CORES = metadata["container_cores"].to_i
SITE = metadata["site"]
CLUSTER = metadata["cluster"]


# NUM_CONTAINERS = ARGV[1].to_i if metadata["multi_machine"] # it controls if we want to iterate with the benchmark
BENCH_REAL_TEST = metadata["bench_real_test"]

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
                :switches => 1+ NB/36,
                :nodes => NB,
                :cluster => CLUSTER,
                :wait => false,
                :walltime => WALLTIME,
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

log.info "Running with #{nodelist.length} nodes"

KERNEL_VERSIONS.each do |kernel|

  log.info "Testing with kernel version #{kernel}"

  jessie_env = "http://public.rennes.grid5000.fr/~cruizsanabria/jessie-distem-expe_k#{kernel}.yaml"

  # the command below deploy an image and then installs a kernel
  `ruby deploy_cluster.rb -n #{NB} -w #{WALLTIME} -e #{jessie_env} --kernel #{metadata["kernel_package"]}` if no_deploy.empty?

  log.info "Bench real multi activated" if BENCH_REAL_TEST

  num_machines = BENCH_REAL_TEST ? BENCH_REAL_TEST : [nodelist.length]
  cores = CORES > 1 ? CORES : 1

  log.info "Experiments will run with #{num_machines} machines"


  # choosing a Coordinator
  coordinator = nodelist.first

  log.info "Downloading necessary files"
  expe_files = ["utils.rb","deploy_NAS_on_cluster.rb","build_lxc_cluster.rb"]

  Net::SCP.start(coordinator, "root") do |scp|

    expe_files.each do |file|
      `wget -N https://raw.githubusercontent.com/camilo1729/distem-expe/master/#{file}`
      scp.upload file, file
    end
    scp.upload "expe_metadata.yaml", "expe_metadata.yaml"
  end


  num_machines.each do |num|

    `ruby deploy_NAS_on_cluster.rb #{num*cores} #{RUNS}`

  end

  `mkdir -p real_k#{kernel}`
  `mv profile-* real_k#{kernel}/`

  log.info "Installing Distem"

  local_repository = "http://public.nancy.grid5000.fr/~cruizsanabria/distem.git"

  # now Install Distem into the nodes
  `ruby #{DISTEM_BOOTSTRAP_PATH}/distem-bootstrap -r "ruby-cute" -c #{coordinator} -g --debian-version jessie -f machine_file --git-url #{local_repository}`

  log.info "Deploying container cluster"

  `ruby build_lxc_cluster.rb #{nodelist.first} #{CORES}`


  Net::SSH.start(coordinator, 'root') do |ssh|
    log.info "printing kernel version"
    log.info ssh.exec!("uname -a")
    log.info "Verifying connectivity"
    num_machines.each do |num|
      #just one line per node. The number of processes is then manage with the parameter --npernode of mpirun
      ssh.exec!("ruby create_machinefile.rb 1 #{num}")
      log.debug ssh.exec!("for i in $(cat machine_file); do ssh $i hostname; done")
      lines = ssh.exec!("wc -l machine_file")
      num_nodes = lines.split(" ").first.to_i
      log.info ssh.exec!("ruby deploy_NAS_on_cluster.rb #{num_nodes*CORES} #{RUNS}")
    end
  end

  log.info "Containers test finished"
  log.info "Getting the results"
  `mkdir -p distem_temp`
  `rsync -a root@#{coordinator}:~/profile* distem_temp/`
  `mv distem_temp/ distem_k#{kernel}/`

  # This is now incompatible after code factorization
  # to FIX
  # if metadata["multi_machine"] then
  #   `ruby expe_NAS_distem_multi.rb #{nodelist.first} #{CORES} #{NUM_CONTAINERS}`
  # else
  #   `ruby expe_NAS_distem.rb #{nodelist.first} #{CORES}`
  # end

end

log.info "All experiments finished"
