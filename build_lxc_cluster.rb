# This script must be executed inside Grid'5000

# This is a generic script to build a cluster of containers using Distem
require 'resolv'
require 'net/scp'
require 'cute'

load 'utils.rb'
CORD = ARGV[0]
# number of cores
CORES = ARGV[1].to_i

HOME = ENV['HOME']
G5K_USER = ENV['USER']


metadata = YAML.load(File.read("expe_metadata.yaml"))
DISTEM_BOOTSTRAP_PATH=metadata["distem_bootstrap_path"]
LXC_IMAGE_PATH = metadata["lxc_image_path"]
RUNS = metadata["runs"]
VNODES_TESTS = metadata["container_tests"]
JOB_NAME = metadata["job_name"]

log_file = File.open(metadata["log_file"], "a")
log = Logger.new MultiIO.new(STDOUT, log_file)
log.level = Logger::INFO
#log.level = Logger::DEBUG

g5k_api = {:uri => "https://api.grid5000.fr/",
           :user => G5K_USER,
           :version => "sid"}

g5k = Cute::G5K::API.new(g5k_api)

job = g5k.get_my_jobs(g5k.site).select{ |j| j["name"] == JOB_NAME }.first

# its an array like this:

  # {"subnets"=>
  #   ["10.158.0.0/22",
  #    "10.158.4.0/22",
  #    "10.158.8.0/22",
  #    "10.158.12.0/22",
  #    "10.158.16.0/22",
  #    "10.158.20.0/22",
  #    "10.158.24.0/22",

net = g5k.get_subnets(job)

## change the assigments of ips

log.info "Downloading necessary files"
expe_files = ["utils.rb","create_machinefile.rb","cluster_distem.rb","delete_cluster.rb"]


Net::SCP.start(CORD, "root") do |scp|

  expe_files.each do |file|
    `wget -N https://raw.githubusercontent.com/camilo1729/distem-expe/master/#{file}`
    scp.upload file, file
  end
  scp.upload "expe_metadata.yaml", "expe_metadata.yaml"
#  scp.upload "create_charmfile.rb","create_charmfile.rb"
end


VNODES_TESTS.each do |vnodes|

  log.info "Creating cluster #{vnodes} vnodes per pnode"
  Net::SSH.start(CORD, 'root') do |ssh|
    log.info "printing kernel version"
    log.info ssh.exec!("uname -a")
    expe_net = net.shift.to_string
    log.info "using subnet: #{expe_net}"

    if CORES < 1 then
      log.info ssh.exec!("ruby cluster_distem.rb -i #{LXC_IMAGE_PATH} -n #{vnodes} --net #{expe_net}")
    else
      log.info ssh.exec!("ruby cluster_distem.rb -i #{LXC_IMAGE_PATH} -n #{vnodes} -r 1 -c #{CORES} --net #{expe_net}")
    end
    log.info ssh.exec!("ruby create_machinefile.rb #{CORES}")
   # log.info ssh.exec!("ruby create_charmfile.rb #{CORES}")
    log.info "Verifying connectivity"
    log.debug ssh.exec!("for i in $(cat machine_file); do ssh $i hostname; done")
    lines = ssh.exec!("wc -l machine_file")
    num_nodes = lines.split(" ").first
    log.info "cluster was setup sucessfully"
  end

end

log.info "Containers finished"
