#!/usr/bin/ruby

require 'distem'

NBCORES = ARGV[0] || 1

iplist = []
Distem.client do |cl|

  info = cl.vnodes_info

  info.each{ |vnode| iplist.push(cl.viface_info(vnode["name"],'if0')['address'].split('/')[0]) }

end


puts "Generating machine file"
File.open("machine_file",'w+') do |f|
  iplist.each do |ip|
    NBCORES.times{ f.puts ip }
  end
end
