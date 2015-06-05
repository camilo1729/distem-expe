require 'cute'
require 'net/scp'
require 'yaml'

nodes = []
SOURCE_NAS =  "http://public.grenoble.grid5000.fr/~cruizsanabria/NPB3.3.tar"

puts "Reading machine file"

f = File.open("machine_file", "r")
f.each_line do |line|
  nodes.push(line.chop)
end
f.close


# making nodes unique
num_procs = nodes.length
nodes.uniq!

puts "Downloading NAS if does not exist"
`wget #{SOURCE_NAS} -O /tmp/NAS.tar` unless File.exist?("/tmp/NAS.tar")


# Transferring code to the first machine
puts "Sending machine file and code to the first node: #{nodes.first}"
Net::SCP.start(nodes.first,'root') do |scp|
   puts scp.upload "machine_file", "machine_file"
   puts scp.upload "/tmp/NAS.tar", "/tmp/NAS.tar"
end


# Compiling on the fist machine
TAU_MAKE = "/usr/local/tau-install/x86_64/lib/Makefile.tau-mpi-pdt"

# Reading the bench to deploy
benchs = YAML.load(File.read("expe_metadata.yaml"))["benchs"]

NUM_PROCS = ARGV[0]
RUNS = ARGV[1].to_i

binaries = []
puts "compiling NAS bench with with TAU"
Net::SSH.start(nodes.first, 'root') do |ssh|
  ssh.exec!("cd /tmp/; tar -xvf NAS.tar")
  benchs.each do |bench|
    compile = "export PATH=/usr/local/tau-install/x86_64/bin/:$PATH;"
    compile += "export TAU_MAKEFILE=#{TAU_MAKE};"
    compile += "make #{bench[:type]} NPROCS=#{NUM_PROCS} CLASS=#{bench[:class]} MPIF77=tau_f90.sh -C /tmp/NPB3.3/NPB3.3-MPI/"
    puts ssh.exec!(compile)
    binaries.push("#{bench[:type]}.#{bench[:class]}.#{NUM_PROCS}")
  end
end

puts "Downloading the generated binaries"
Net::SCP.start(nodes.first,'root') do |scp|
  binaries.each do |binary|
    puts scp.download "/tmp/NPB3.3/NPB3.3-MPI/bin/#{binary}",binary
  end
end

puts "Transferring to all nodes"
Cute::TakTuk.start(nodes, :user => 'root') do |tak|
  binaries.each do |binary|
    tak.put(binary,binary)
  end
  puts "Cleaning previous state"
  tak.exec!("rm profile*")
end

puts "Executing #{RUNS} runs per type of bench"



Net::SSH.start(nodes.first, 'root') do |ssh|
  RUNS.times do
    binaries.each do |binary|
      puts "Executing binary: #{binary}"
      ssh.exec!("mpirun  --mca btl self,sm,tcp --machinefile machine_file #{binary}")
      puts "Getting the profile files"
      profile_dir = "profile-#{binary}-#{Time.now.to_i}"
      Dir.mkdir profile_dir
      nodes.each do |ip|
        `cd #{profile_dir} && scp root@#{ip}:~/profile* .`
      end
    end
  end
end
