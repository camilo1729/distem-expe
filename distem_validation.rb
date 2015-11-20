require 'resolv'
require 'net/scp'
require 'cute'

# useful methods
load 'utils.rb'


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

old_jobs = g5k.get_my_jobs(g5k.site).select{ |j| j["name"] == job_name}

raise "You need a job running"

job = old_jobs.empty? ? g5k.reserve(reserv_param) : old_jobs.first


log.info "Downloading necessary scripts"

`wget -N https://raw.githubusercontent.com/camilo1729/distem-expe/master/deploy_cluster`
`wget -N https://raw.githubusercontent.com/camilo1729/distem-expe/master/deploy_NAS_on_cluster.rb`

if metadata["multi_machine"] then
  `wget -N https://raw.githubusercontent.com/camilo1729/distem-expe/master/expe_NAS_distem_multi.rb`
else
  `wget -N https://raw.githubusercontent.com/camilo1729/distem-expe/master/expe_NAS_distem.rb`
end

nodelist = job['assigned_nodes'].uniq

log.info "Running with #{nodelist.length} nodes"

KERNEL_VERSIONS.each do |kernel|

  log.info "Testing with kernel version #{kernel}"

  jessie_env = "http://public.rennes.grid5000.fr/~cruizsanabria/jessie-distem-expe_k#{kernel}.yaml"

  `ruby deploy_cluster.rb -n #{NB} -w #{WALLTIME} -e #{jessie_env}`

  log.info "Bench real multi activated" if BENCH_REAL_TEST

  num_machines = BENCH_REAL_TEST ? BENCH_REAL_TEST : [nodelist.length]
  cores = CORES > 1 ? CORES : 1

  log.info "Experiments will run with #{num_machines} machines"

  num_machines.each do |num|

    File.open("machine_file",'w+') do |f|
      nodelist[0..(num-1)].each do |node|
        cores.times{f.puts node }
      end
    end

    `ruby deploy_NAS_on_cluster.rb #{num*cores} #{RUNS}`
  end

  `mkdir -p real_k#{kernel}`
  `mv profile-* real_k#{kernel}/`

  log.info "Installing Distem"

  local_repository = "http://public.nancy.grid5000.fr/~cruizsanabria/distem.git"
  # now Install Distem into the nodes
  `ruby #{DISTEM_BOOTSTRAP_PATH}/distem-bootstrap -r "ruby-cute" -c #{nodelist.first} -g --debian-version jessie -f #{machinefile} --git-url #{local_repository}`

  log.info "Starting containers"

  if metadata["multi_machine"] then
    `ruby expe_NAS_distem_multi.rb #{nodelist.first} #{CORES} #{NUM_CONTAINERS}`
  else
    `ruby expe_NAS_distem.rb #{nodelist.first} #{CORES}`
  end
  `mv distem_temp/ distem_k#{kernel}/`
end

log.info "All experiments finished"
