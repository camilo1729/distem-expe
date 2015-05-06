def check_deployment(deploy_info)
  # It returns an array of machines that didnt deploy
  deploy_info["result"].select{ |p,v|  v["state"] == "KO"}.keys
end

def check_cpu_performance(machines,ref_value)
  badnodes = {}
  Net::SSH::Multi.start do |session|
    machines.each{ |node| session.use("root@#{node}")}
    session.exec! ""
    session.exec! "DEBIAN_FRONTEND=noninteractive apt-get install -q -y sysbench"
    results = session.exec! "sysbench --num-threads=16 --test=cpu run --cpu-max-prime=100000 | grep \"execution time\" | awk '{print $4}' | cut -d / -f 1"
    puts results
    badnodes = results.select{ |name,res| res[:output].to_i > (ref_value +2)}
  end
  badnodes.values
end
