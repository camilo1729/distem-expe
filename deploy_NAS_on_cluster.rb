require 'cute'
require 'net/scp'


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

NUM_PROCS = ARGV[0]
NAS_CLASS = "A"
NAS_BENCH = "lu"

BIN_BENCH = "#{NAS_BENCH}.#{NAS_CLASS}.#{NUM_PROCS}"
puts "compiling the application with TAU"
Net::SSH.start(nodes.first, 'root') do |ssh|
  ssh.exec!("cd /tmp/; tar -xvf NAS.tar")
  compile = "export PATH=/usr/local/tau-install/x86_64/bin/:$PATH;"
  compile += "export TAU_MAKEFILE=#{TAU_MAKE};"
  compile += "make #{NAS_BENCH} NPROCS=#{NUM_PROCS} CLASS=#{NAS_CLASS} MPIF77=tau_f90.sh -C /tmp/NPB3.3/NPB3.3-MPI/"
  puts ssh.exec!(compile)
end

puts "Downloading the generated binary"
Net::SCP.start(nodes.first,'root') do |scp|
  puts scp.download "/tmp/NPB3.3/NPB3.3-MPI/bin/#{BIN_BENCH}", BIN_BENCH
end

puts "Transferring to all nodes"
Cute::TakTuk.start(nodes, :user => 'root') do |tak|

tak.put(BIN_BENCH, BIN_BENCH)
puts "Cleaning previous state"
tak.exec!("rm profile*")
end

puts "Executing the application"

Net::SSH.start(nodes.first, 'root') do |ssh|
  ssh.exec!("mpirun  --mca btl self,sm,tcp --machinefile machine_file #{BIN_BENCH}")
end

puts "Getting the profile files"

profile_dir = "profile-#{num_procs}-#{Time.now.to_i}"

Dir.mkdir profile_dir

nodes.each do |ip|
  `cd #{profile_dir} && scp root@#{ip}:~/profile* .`
end
