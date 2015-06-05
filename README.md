# distem-expe
# Script for deploying Distem HPC validation in Grid'5000.
Several ruby scripts aimed at evaluating Linux containers for HPC.
The scrips help to deploy and execute NAS parallel benchmarks on:
1) real cluster 2) a cluster made of containers.

## How to repeat the experiments

## Linux kernel version experiment:

First, you have to download the following files from this repository:

```bash
	$ wget https://raw.githubusercontent.com/camilo1729/distem-expe/master/expe_metadata.yaml
	$ wget https://raw.githubusercontent.com/camilo1729/distem-expe/master/deploy_kernel_version_expe.rb
	$ wget https://raw.githubusercontent.com/camilo1729/distem-expe/master/utils.rb
```

Then, we execute the following:

```bash
	$ ruby deploy_real_cluster.rb 8 #Number of nodes

```

By default it will make a reservation in `paravance` cluster, you can edit it to change the parameter of reservation.
