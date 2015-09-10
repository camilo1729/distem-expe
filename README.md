# distem-expe
# Script for deploying Distem HPC validation in Grid'5000.
Several ruby scripts aimed at evaluating Linux containers for HPC.
The scrips help to deploy and execute NAS parallel benchmarks on:
1) real cluster 2) a cluster made of containers.

## How to repeat the experiments

Several parameter for the experiments can be customized using the `expe_metadata.yaml` file.

```yaml

log_file: # name of the file to be used as log file.
distem_bootstrap_path: # help script to install and start distem on the machines.
site: # Grid'5000 site
cluster: # specific cluster in the site
runs: #integer which specifies the number of times a measure will be repeated.
timeout: # deprecated
multi_machine: # active the running of scalability test
performance_check: # active the check of performance
kernel_version: # kernel versions to test. The different kadeploy config should be exist
container_tests: # an array for the number of container that will be created on a physical machine
bench_container_test: ?
container_cores: #specifies the number of cores a vnode will be configured with
benchs: # only NAS benchmarks, specifies the type of benchmark and the class to be run.

```

## Linux kernel version and oversubscription

The experiments are controlled by two files: `run_all_kernelversion_expe.rb` and `expe_metadata.yaml`.
First, you have to download them this repository:

```bash
	$ wget https://raw.githubusercontent.com/camilo1729/distem-expe/master/expe_metadata.yaml
	$ wget https://raw.githubusercontent.com/camilo1729/distem-expe/master/run_all_kernelversion_expe.rb

```

Then, we should use the following metadata:

```yaml

log_file: "Distem_expe.log"
distem_bootstrap_path: "~/Repositories/ruby-cute/examples"
site: "rennes"
cluster: "paravance"
runs: 20
multi_machine: false
performance_check: true
kernel_versions:
- "4.0"
container_tests: # For the experiment we deploy up to 8 container per machine
- 1
- 2
- 4
- 8
bench_real_test: false
container_cores: 0
benchs:
- :type: lu
  :class: B
- :type: cg
  :class: B
- :type: ep
  :class: B
- :type: ft
  :class: B
- :type: is
  :class: C
- :type: mg
  :class: C
```

Then, execute the ruby script

```bash
	$ ruby run_all_kernelversion_expe.rb

```
## Inter-container communication

Download the following scripts:

```bash
	$ wget https://raw.githubusercontent.com/camilo1729/distem-expe/master/expe_metadata.yaml
	$ wget https://raw.githubusercontent.com/camilo1729/distem-expe/master/deploy_lxc_expe.rb

```

and edit the metadata file like this:

```yaml
---
log_file: "Distem_expe.log"
distem_bootstrap_path: "~/Repositories/ruby-cute/examples"
site: "rennes"
cluster: "paravance"
runs: 20
multi_machine: false
performance_check: true
kernel_versions:
- "4.0"
container_tests: # number of containers to be created in each machine
- 1
- 2
- 4
- 8
bench_container_test:
- 2
- 4
- 8
bench_real_test:
- 2
- 4
- 8
container_cores: 2
benchs:
- :type: lu
  :class: B
- :type: cg
  :class: B
- :type: ep
  :class: B
- :type: ft
  :class: B
- :type: is
  :class: C
- :type: mg
  :class: C

```
For the test just one machine will be used.
Run the script using the follwing parameters:

```bash
	$ ruby deploy_lxc_expe.rb 1 2

```

## Multinode inter-container communication

Download the following scripts:

```bash
	$ wget https://raw.githubusercontent.com/camilo1729/distem-expe/master/expe_metadata.yaml
	$ wget https://raw.githubusercontent.com/camilo1729/distem-expe/master/deploy_lxc_expe.rb

```
and edit the metadata file like this:


```yaml

log_file: "Distem_expe.log"
distem_bootstrap_path: "~/Repositories/ruby-cute/examples"
site: "rennes"
cluster: "paravance"
runs: 20
multi_machine: true
performance_check: true
kernel_versions:
- "4.0"
container_tests: # number of containers to be created in each machine
- 1
bench_container_test: # depends on the number of machines you reserved
- 1
- 2
- 4
- 8
- 16
- 32
- 64
bench_real_test: # depends on the number of machines you reserved
- 1
- 2
- 4
- 8
- 16
- 32
- 64
container_cores: 16 # depends on the number of cores you have in the machine
benchs:
- :type: lu
  :class: B
- :type: cg
  :class: B
- :type: ep
  :class: B
- :type: ft
  :class: B
- :type: is
  :class: C
- :type: mg
  :class: C

```


By default it will make a reservation in `paravance` cluster, you can edit it to change the parameter of reservation.
