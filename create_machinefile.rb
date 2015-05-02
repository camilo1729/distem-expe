#!/usr/bin/ruby

require 'distem'

iplist = []
Distem.client do |cl|

  info = cl.vnodes_info

  info.each{ |vnode| iplist.push(cl.viface_info(vnode["name"],'if0')['address'].split('/')[0]) }

  File.open("machine_file",'w+') do |f|
    iplist.each{ |ip| f.puts ip }
  end

end

# Creating machine file

puts "Generating machine file"
File.open("machine_file",'w+') do |f|
  iplist.each{ |ip| f.puts ip }
end
