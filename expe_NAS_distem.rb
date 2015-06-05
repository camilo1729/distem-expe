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

log.info "Downloading necessary scripts"
expe_scripts = ["create_machinefile.rb","cluster_distem.rb","delete_cluster.rb","deploy_NAS_on_cluster.rb"]



Net::SCP.start(CORD, "root") do |scp|

  expe_scripts.each do |script|
    `wget https://raw.githubusercontent.com/camilo1729/distem-expe/master/#{script}`
    scp.upload script, script
  end
  scp.upload "expe_metadata.yaml", "expe_metadata.yaml"
end


vnodes_tests.each{ |vnodes|

  log.info "Creating cluster #{vnodes} vnodes per pnode"
  Net::SSH.start(CORD, 'root') do |ssh|
    log.info "printing kernel version"
    log.info ssh.exec!("uname -a")

    if CORES > 0 then
      log.info ssh.exec!("ruby cluster_distem.rb -i #{LXC_IMAGE_PATH} -n #{vnodes} -u #{g5k_user} -r 1 -c #{CORES}")
    else
      log.info ssh.exec!("ruby cluster_distem.rb -i #{LXC_IMAGE_PATH} -n #{vnodes} -u #{g5k_user}")
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
`rsync -a root@#{CORD}:~/ .`
