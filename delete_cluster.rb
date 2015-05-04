#!/usr/bin/ruby

require 'distem'

names = []
Distem.client do |cl|

  cl.vnetwork_remove("testnet")

  info = cl.vnodes_info


  info.each{ |vnode| names.push(vnode["name"]) }


  cl.vnodes_stop(names)

  cl.vnodes_remove(names)

end
