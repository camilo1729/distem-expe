#!/usr/bin/ruby

nodes = [128,64,32,16,8,4]

`wget -N https://raw.githubusercontent.com/camilo1729/distem-expe/master/deploy_lxc_expe.rb`
`wget -N https://raw.githubusercontent.com/camilo1729/distem-expe/master/utils.rb`

lxcpnode = 1
nodes.each do |num|

  `ruby deploy_lxc_expe.rb #{num} #{nodes.max/num}`
  `mkdir nodes_#{num}`
  `mv real_* nodes_#{num}/`
  `mv distem_* nodes_#{num}/`
end
