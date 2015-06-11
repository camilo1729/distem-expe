#!/usr/bin/ruby

nodes = [64,32,16,8]

nodes.each do |num|

  `ruby deploy_lxc_expe.rb #{num}`
  `mkdir nodes_#{num}`
  `mv real_* nodes_#{num}/`
  `mv distem_* nodes_#{num}/`
end
