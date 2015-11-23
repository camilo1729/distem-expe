# This script must be executed inside Grid'5000

require 'resolv'
require 'net/scp'
require 'cute'

load 'utils.rb'
CORD = ARGV[0]
# number of cores

metadata = YAML.load(File.read("expe_metadata.yaml"))
RUNS = metadata["runs"]
log_file = File.open(metadata["log_file"], "a")
log = Logger.new MultiIO.new(STDOUT, log_file)
log.level = Logger::INFO
#log.level = Logger::DEBUG


log.info "Downloading necessary files"
expe_files = ["deploy_NAS_on_cluster.rb"]


Net::SCP.start(CORD, "root") do |scp|

  expe_files.each do |file|
    `wget -N https://raw.githubusercontent.com/camilo1729/distem-expe/master/#{file}`
    scp.upload file, file
  end
  scp.upload "expe_metadata.yaml", "expe_metadata.yaml"
end


Net::SSH.start(CORD, 'root') do |ssh|
  log.info "printing kernel version"
  log.info ssh.exec!("uname -a")
  log.info "Verifying connectivity"
  log.debug ssh.exec!("for i in $(cat machine_file); do ssh $i hostname; done")
  lines = ssh.exec!("wc -l machine_file")
  num_nodes = lines.split(" ").first
  log.info ssh.exec!("ruby deploy_NAS_on_cluster.rb #{num_nodes} #{RUNS}")
end


log.info "Containers test finished"
log.info "Getting the results"
`mkdir -p distem_temp`
`rsync -a root@#{CORD}:~/profile* distem_temp/`
