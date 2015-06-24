require 'cute'


puts "filling the ARP tables"

nodes = []

f = File.open("machine_file", "r")
f.each_line do |line|
  nodes.push(line.chop)
end
f.close

Net::SSH.start(nodes.first, 'root') do |ssh|
  ssh.exec!("for i in $(cat machine_file); do ssh $i hostname; done")
  ssh.exec!("arp -n | awk '{ print $1, $3}' | grep ^[0-9] > arpfile")
end

puts "Downloading ARP file"
Net::SCP.start(nodes.first,'root') do |scp|
    scp.download "arpfile", "arpfile"
end

puts "Transferring to all nodes"
Cute::TakTuk.start(nodes, :user => 'root') do |tak|
  tak.put("arpfile","arpfile")
  tak.exec!("arp -f arpfile")
end
