#!/usr/bin/ruby

require 'distem'

iplist = []
nbcores = ARGV[0].to_i

nbcores = 1 if nbcores < 1
Distem.client do |cl|

  info = cl.vnodes_info

  info.each do |vnode|
    # I have to investigate what happens with this field if any core is assigned from the beginning.
    nbcores.times{
      iplist.push(cl.viface_info(vnode["name"],'if0')['address'].split('/')[0])
    }
  end

end


puts "Generating machine file"
File.open("machine_file",'w+') do |f|
  iplist.each do |ip|
    f.puts ip
  end
end
