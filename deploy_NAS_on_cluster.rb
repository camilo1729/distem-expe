require 'cute'
require 'net/scp'
require 'yaml'
load 'utils.rb'
nodes = []
SOURCE_NAS =  "http://public.rennes.grid5000.fr/~cruizsanabria/NPB3.3.tar"

## getting experiment metadata
metadata = YAML.load(File.read("expe_metadata.yaml"))

NUM_PROCS = ARGV[0]
RUNS = ARGV[1].to_i

log_file = File.open(metadata["log_file"], "a")
log = Logger.new MultiIO.new(STDOUT, log_file)
log.level = Logger::INFO
#log.level = Logger::DEBUG

log.info "Reading machine file"

f = File.open("machine_file", "r")
f.each_line do |line|
  nodes.push(line.chop)
end
f.close

# making nodes unique
nodes.uniq!

nper_node = NUM_PROCS/nodes.length

log.info "Downloading NAS if does not exist"
`wget #{SOURCE_NAS} -O /tmp/NAS.tar`


# Transferring code to the first machine
log.info "Sending machine file and code to the first node: #{nodes.first}"
Net::SCP.start(nodes.first,'root') do |scp|
   log.debug scp.upload "machine_file", "machine_file"
   log.debug scp.upload "/tmp/NAS.tar", "/tmp/NAS.tar"
end


# enabling MPI libraries. This is only necessary for compiled MPI
log.info "Enabling MPI libraries"
Cute::TakTuk.start(nodes, :user => 'root') do |tak|
  tak.exec!("ldconfig")
end


# Compiling on the first machine
TAU_MAKE = "/usr/local/tau-install/x86_64/lib/Makefile.tau-mpi-pdt"

# Reading the benchs to deploy
benchs = YAML.load(File.read("expe_metadata.yaml"))["benchs"]

binaries = []
log.info "compiling NAS bench with with TAU"
Net::SSH.start(nodes.first, 'root') do |ssh|
  ssh.exec!("cd /tmp/; tar -xvf NAS.tar")
  benchs.each do |bench|
    compile = "export PATH=/usr/local/tau-install/x86_64/bin/:$PATH;"
    compile += "export TAU_MAKEFILE=#{TAU_MAKE};"
    compile += "make #{bench[:type]} NPROCS=#{NUM_PROCS} CLASS=#{bench[:class]} MPIF77=tau_f90.sh -C /tmp/NPB3.3/NPB3.3-MPI/"
    log.debug ssh.exec!(compile)
    binaries.push("#{bench[:type]}.#{bench[:class]}.#{NUM_PROCS}")
  end
end

log.info "Downloading the generated binaries"
Net::SCP.start(nodes.first,'root') do |scp|
  binaries.each do |binary|
    log.debug scp.download "/tmp/NPB3.3/NPB3.3-MPI/bin/#{binary}",binary
  end
end

log.info "Transferring to all nodes"
nodes.each do |node|
  Net::SCP.start(node,'root') do |scp|
    binaries.each do |binary|
      log.info "sending binary to #{node}"
      log.debug scp.upload binary, binary
    end
  end
end



# I get rid of taktuk because It has a strange behavior when using plain netns
# as interconnection

# Cute::TakTuk.start(nodes, :user => 'root') do |tak|
#   binaries.each do |binary|
#     tak.put(binary,binary)
#   end
#   log.info "Cleaning previous state"
#   tak.exec!("rm profile*")
# end

log.info "Executing #{RUNS} runs per type of bench"

Net::SSH.start(nodes.first, 'root') do |ssh|
  RUNS.times do |iteration|
    log.info "Starting run: #{iteration+1}/#{RUNS}"
    binaries.each do |binary|
      log.info "Executing binary: #{binary}"
      mpi_cmd = "mpirun  --mca btl self,sm,tcp --machinefile machine_file #{binary}"
      mpi_cmd = "mpirun  --allow-run-as-root --mca btl self,sm,tcp -npernode #{nper_node}--machinefile machine_file #{binary}" if metadata["mpi_version"] == "1.8.5"
      ssh.exec!(mpi_cmd)
      log.info "Getting the profile files"
      profile_dir = "profile-#{binary}-#{Time.now.to_i}"
      Dir.mkdir profile_dir
      nodes.each do |ip|
        `cd #{profile_dir} && scp root@#{ip}:~/profile* .`
      end
    end
  end
end
