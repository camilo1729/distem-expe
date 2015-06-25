#!/usr/bin/ruby

require 'distem'

new_cpu_freq = ARGV[0].to_f

# Updates the values of cpu frequency

Distem.client do |cl|

  info = cl.vnodes_info

  info.each do |vnode|
    cl.vcpu_update(vnode["name"], new_cpu_freq, 'ratio')

  end

end
