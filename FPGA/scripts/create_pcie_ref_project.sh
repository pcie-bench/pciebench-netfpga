#!/bin/bash
#
# Copyright (c) 2016
# All rights reserved.
#
# as part of the DARPA MRC research programme.
#
# @NETFPGA_LICENSE_HEADER_START@
#
# Licensed to NetFPGA C.I.C. (NetFPGA) under one or more contributor
# license agreements.  See the NOTICE file distributed with this work for
# additional information regarding copyright ownership.  NetFPGA licenses this
# file to you under the NetFPGA Hardware-Software License, Version 1.0 (the
# "License"); you may not use this file except in compliance with the
# License.  You may obtain a copy of the License at:
#
#   http://www.netfpga-cic.org
#
# Unless required by applicable law or agreed to in writing, Work distributed
# under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
# CONDITIONS OF ANY KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations under the License.
#
# @NETFPGA_LICENSE_HEADER_END@
#
if [ -d "/tmp/pcie3_7x_0_example" ]; then
	while true; do
		echo -n "Output dir (/tmp/pcie3_7x_0_example) exists. Do you really want to remove it and create it again [y/n]? "
		read yn

	    case $yn in
	        [Yy] ) break;;
	        [Nn] ) exit;;
	    esac
	done
fi

rm -rf /tmp/pcie3_7x_0_example /tmp/tmp_project

vivado -mode batch -source scripts/create_pcie_ref_project.tcl

mkdir -p source/hdl/pcie_support

for f in /tmp/pcie3_7x_0_example/pcie3_7x_0_example.srcs/sources_1/imports/pcie3_7x_0/example_design/support/*
do
 echo "Processing $f"
 perl scripts/alter_nettype.pl $f > source/hdl/pcie_support/`basename $f` 
done
#cp /tmp/pcie3_7x_0_example/pcie3_7x_0_example.srcs/sources_1/imports/pcie3_7x_0/example_design/support/* source/hdl/pcie_support/

