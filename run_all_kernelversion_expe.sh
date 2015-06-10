#!/usr/bin/sh

ruby deploy_kernel_version_expe.rb 8
mkdir nodes_8
mv real_* nodes_8/
mv distem_* nodes_8/
ruby deploy_kernel_version_expe.rb 16
mkdir nodes_16
mv real_* nodes_16/
mv distem_* nodes_16/
ruby deploy_kernel_version_expe.rb 32
mkdir nodes_32
mv real_* nodes_32/
mv distem_* nodes_32/
ruby deploy_kernel_version_expe.rb 64
mkdir nodes_64
mv real_* nodes_64/
mv distem_* nodes_64/
