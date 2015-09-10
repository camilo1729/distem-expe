#!/usr/bin/ruby

nodes = [64,32,16,8]

puts "Downloading necessary files"

`wget https://raw.githubusercontent.com/camilo1729/distem-expe/master/deploy_lxc_expe.rb`
`wget https://raw.githubusercontent.com/camilo1729/distem-expe/master/utils.rb`


nodes.each do |num|

  # It does not handle return codes
  `ruby deploy_lxc_expe.rb #{num}`
  if $?.to_i > 0 then
    puts "An error was found"
    exit
  end
  `mkdir nodes_#{num}`
  `mv real_* nodes_#{num}/`
  `mv distem_* nodes_#{num}/`
end
