# This script must be executed inside Grid'5000

require 'resolv'
require 'net/scp'
require 'cute'

CORD = ARGV[0]

home = ENV['HOME']
g5k_user = ENV['USER']

vnodes_tests = [1, 2, 4, 8]

LXC_IMAGE_PATH = "/home/cruizsanabria/jessie-tau-lxc.tar.gz"

puts "Downloading necessary scripts"
expe_scripts = ["create_machinefile.rb","cluster_distem.rb","delete_cluster.rb","deploy_NAS_on_cluster.rb"]


Net::SCP.start(CORD, "root") do |scp|

  expe_scripts.each do |script|
    `wget https://raw.githubusercontent.com/camilo1729/distem-expe/master/#{script}`
    scp.upload script, script
  end
  scp.upload "expe_metadata.yaml", "expe_metadata.yaml"
end


vnodes_tests.each{ |vnodes|


  puts "Creating cluster #{vnodes} vnodes per pnode"
  Net::SSH.start(CORD, 'root') do |ssh|
    puts "printing kernel version"
    puts ssh.exec!("uname -a")
    puts ssh.exec!("ruby cluster_distem.rb -i #{LXC_IMAGE_PATH} -n #{vnodes} -u #{g5k_user}")
    puts ssh.exec!("ruby create_machinefile.rb")
    puts "Verifying connectivity"
    puts ssh.exec!("for i in $(cat machine_file); do ssh $i hostname; done")
    lines = ssh.exec!("wc -l machine_file")
    num_nodes = lines.split(" ").first
    puts ssh.exec!("ruby deploy_NAS_on_cluster.rb #{num_nodes} 20")
    puts "Deleting cluster"
    puts ssh.exec!("ruby delete_cluster.rb")
  end

}

puts "Getting the results"
`rsync -a root@#{CORD}:~/ .`
