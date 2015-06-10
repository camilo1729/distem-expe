#!/usr/bin/ruby

nodes = [128,64,32,16,8,4]

lxcpnode = 1
nodes.each do |num|

  `ruby deploy_kernel_version_expe.rb #{num} #{128/num}`
  `mkdir nodes_#{num}`
  `mv real_* nodes_#{num}/`
  `mv distem_* nodes_#{num}/`
end
