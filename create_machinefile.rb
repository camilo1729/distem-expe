#!/usr/bin/ruby

require 'distem'

iplist = []
nbcores = ARGV[0].to_i
numnodes = ARGV[1].to_i

nbcores = 1 if nbcores < 1

Distem.client do |cl|

  info = cl.vnodes_info.values

  info.each do |vnode|
      iplist.push(cl.viface_info(vnode["name"],'if0')['address'].split('/')[0])
  end

end

# reducing the number of nodes
iplist = iplist[0..(numnodes-1)] if numnodes > 0

puts "Generating machine file"
File.open("machine_file",'w+') do |f|
  iplist.each do |ip|
    nbcores.times{
    f.puts ip
    }
  end
end
