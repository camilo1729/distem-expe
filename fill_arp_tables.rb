require 'cute'

NODE= ARGV[0]

puts "filling the ARP tables"

Net::SSH.start(NODE, 'root') do |ssh|
  ssh.exec!("for i in $(cat machine_file); do ssh $i hostname; done")
  ssh.exec!("arp -n | awk '{ print $1, $3}' | grep ^[0-9] > arpfile")
end

puts "Downloading ARP file"
Net::SCP.start(NODE,'root') do |scp|
    scp.download "arpfile", "arpfile"
end

log.info "Transferring to all nodes"
Cute::TakTuk.start(NODE, :user => 'root') do |tak|
  tak.put("arpfile","arpfile")
  tak.exec!("arp -f arpfile")
end
