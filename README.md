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

First, you have to download the following files from this repository:

```bash
	$ wget https://raw.githubusercontent.com/camilo1729/distem-expe/master/expe_metadata.yaml
	$ wget https://raw.githubusercontent.com/camilo1729/distem-expe/master/deploy_lxc_expe.rb
	$ wget https://raw.githubusercontent.com/camilo1729/distem-expe/master/utils.rb
```

Then, we execute the following:

```bash
	$ ruby deploy_real_cluster.rb 8 #Number of nodes

```

By default it will make a reservation in `paravance` cluster, you can edit it to change the parameter of reservation.
