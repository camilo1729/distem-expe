
def check_cpu_performance(machines,ref_value)
  badnodes = {}
  Net::SSH::Multi.start do |session|
    machines.each{ |node| session.use("root@#{node}")}
    session.exec! ""
    session.exec! "DEBIAN_FRONTEND=noninteractive apt-get install -q -y sysbench"
    results = session.exec! "sysbench --num-threads=16 --test=cpu run --cpu-max-prime=100000 | grep \"execution time\" | awk '{print $4}' | cut -d / -f 1"
    puts results
    badnodes = results.select{ |name,res| res[:stdout].to_i > (ref_value +2)}
  end
  badnodes.keys
end


class MultiIO
  def initialize(*targets)
     @targets = targets
  end

  def write(*args)
    @targets.each {|t|
      t.write(*args)
      # this is just to assure a coherent log for multiple scripts
      t.flush
    }

  end

  def close
    @targets.each(&:close)
  end
end

def install_kernel(machines,file)
  Net::SSH::Multi.start do |session|
    # downloading debian package
    machines.each{ |node| session.use("root@#{node}")}
    # asking the user for debian package
    puts "Enter the name of the debian package to download:"
    if file.nil?
      debian_package = STDIN.gets.chomp
    else
      debian_package = file
    end
    puts "Downloading package: #{debian_package}"
    session.exec! "wget http://public.rennes.grid5000.fr/~cruizsanabria/#{debian_package}"
    session.exec! "dpkg -i #{debian_package}"
    package_name = debian_package.split("_")[0]
    vmlinuz = session.exec! "dpkg -L #{package_name} | grep vmlinuz | cut -d'/' -f3"
    version = vmlinuz.values.first[:stdout].split("vmlinuz-")[1]
    # changing symbolic link for booting with other kernel

    session.exec! "rm /boot/vmlinuz"
    session.exec! "rm /boot/initrd"
    session.exec! "cd /boot/ && ln -s vmlinuz-#{version} vmlinuz"
    session.exec! "cd /boot/ && ln -s initrd.img-#{version} initrd"

  end
end
