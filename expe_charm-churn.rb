#!/usr/bin/ruby

require 'distem'
require 'cute'
require 'net/scp'
require 'yaml'
load 'utils.rb'

## getting experiment metadata
metadata = YAML.load(File.read("expe_metadata.yaml"))
DISTEM_BOOTSTRAP_PATH=metadata["distem_bootstrap_path"]

log_file = File.open(metadata["log_file"], "a")
log = Logger.new MultiIO.new(STDOUT, log_file)
log.level = Logger::INFO

RUNS = metadata["runs"]
iplist = []

fault_type = ARGV[0]
Distem.client do |cl|


  info = cl.vnodes_info

  log.info "Getting ips of vnodes"
  info.each do |vnode|
      iplist.push(cl.viface_info(vnode["name"],'if0')['address'].split('/')[0])
  end

  `ruby create_charmfile.rb`

  log.info "Sending nodelist file"
  iplist.each do |node|
    Net::SCP.start(node,'root') do |scp|
      log.debug scp.upload "nodelist", "nodelist"   
    end
  end
  
  jacobi_path = "/root/charm-6.6.0/net-linux-x86_64-syncft/tests/charm++/jacobi3d/"

  log.info "compiling"
  Cute::TakTuk.start(iplist, :user => 'root') do |tak|
    tak.exec!("make -C #{jacobi_path}")
  end
  
  # Failure trace 
  trace = [{:date => 60, :node => "node-1"},
           {:date => 120, :node => "node-3"},
           {:date => 180, :node => "node-5"},
           {:date => 240, :node => "node-7"}]

  RUNS.times.each do |t|
    log.info "Executing run #{t} of #{RUNS}"

    
    log.info "Adding trace event"
    trace.each do |t|
      cl.event_trace_add({ 'vnodename' => t[:node], 'type' => 'vnode' },'churn', { t[:date] => 'down' }) # fail after first checkpoint
      log.info "Adding event to node #{t[:node]}"
    end

    num_procs = iplist.length
    
    log.info "Starting event manager"
    begin
      cl.event_manager_start
    rescue Distem::Lib::ClientError => e
      puts "Unable to start event manager (maybe it is already started?)"
    end 
    
    log.info "Event manager started"
    log.info "Running Charm jacobi"

    Net::SSH.start(iplist.first, 'root') do |ssh|
      
      cmd = "cd #{jacobi_path}; time ./charmrun ++p #{num_procs} ++nodelist ~/nodelist ./jacobi3d 512 512 256 64 64 64"
      log.info "running cmd: #{cmd}"
      result = ssh.exec!(cmd)
      outputfile = "output-charm-ft-#{fault_type}-#{Time.new.to_i}"
      File.open(outputfile,'w+'){ |f| f.puts(result)}
    
    end

    cl.event_manager_stop
    log.info "Restarting nodes..."
    
    nodes_to_restart = []
    cl.vnodes_info.each {|n| 
      if(n['status'] != 'RUNNING')
        nodes_to_restart << n['name']
      end                    
    }
    cl.vnodes_start(nodes_to_restart, async=false)
    # cl.vnodes_start(["node-1","node-3","node-5"], async=false)
    cl.wait_vnodes
  end
  
end
 
