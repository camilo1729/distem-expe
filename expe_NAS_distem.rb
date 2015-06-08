# This script must be executed inside Grid'5000

require 'resolv'
require 'net/scp'
require 'cute'

load 'utils.rb'
CORD = ARGV[0]
CORES = ARGV[1]

home = ENV['HOME']
g5k_user = ENV['USER']

vnodes_tests = [1, 2, 4, 8]

LXC_IMAGE_PATH = "#{home}/jessie-tau-lxc.tar.gz"

metadata = YAML.load(File.read("expe_metadata.yaml"))
DISTEM_BOOTSTRAP_PATH=metadata["distem_bootstrap_path"]

log_file = File.open(metadata["log_file"], "a")
log = Logger.new MultiIO.new(STDOUT, log_file)
log.level = Logger::INFO
#log.level = Logger::DEBUG



g5k_api = {:uri => "https://api.grid5000.fr/",
           :user => g5k_user,
           :version => "sid"}

g5k = Cute::G5K::API.new(g5k_api)

job = g5k.get_my_jobs(g5k.site).select{ |j| j["name"] == "distem"}.first


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

log.info "Downloading necessary scripts"
expe_scripts = ["utils.rb","create_machinefile.rb","cluster_distem.rb","delete_cluster.rb","deploy_NAS_on_cluster.rb"]



Net::SCP.start(CORD, "root") do |scp|

  expe_scripts.each do |script|
    `wget https://raw.githubusercontent.com/camilo1729/distem-expe/master/#{script}`
    scp.upload script, script
  end
  scp.upload "expe_metadata.yaml", "expe_metadata.yaml"
end

subnet = 0
vnodes_tests.each{ |vnodes|

  log.info "Creating cluster #{vnodes} vnodes per pnode"
  Net::SSH.start(CORD, 'root') do |ssh|
    log.info "printing kernel version"
    log.info ssh.exec!("uname -a")
    # generating new subnet
    # new_net = net.octets
    # new_net[2] = subnet
    # subnet +=2 # for the next round
    #expe_net = "#{new_net.join(".")}/#{22}"
    expe_net = net[subnet].to_string
    subnet+=1
    log.info "using subnet: #{expe_net}"

    if CORES.nil? then
      log.info ssh.exec!("ruby cluster_distem.rb -i #{LXC_IMAGE_PATH} -n #{vnodes} -u #{g5k_user} --net #{expe_net}")
    else
      log.info ssh.exec!("ruby cluster_distem.rb -i #{LXC_IMAGE_PATH} -n #{vnodes} -u #{g5k_user} -r 1 -c #{CORES} --net #{expe_net}")
    end

    log.info ssh.exec!("ruby create_machinefile.rb")
    log.info "Verifying connectivity"
    log.info ssh.exec!("for i in $(cat machine_file); do ssh $i hostname; done")
    lines = ssh.exec!("wc -l machine_file")
    num_nodes = lines.split(" ").first
    log.info ssh.exec!("ruby deploy_NAS_on_cluster.rb #{num_nodes} 20")
    log.info "Deleting cluster"
    log.info ssh.exec!("ruby delete_cluster.rb")
  end

}

log.info "Getting the results"
`mkdir -p distem_temp`
`rsync -a root@#{CORD}:~/ distem_temp/`
