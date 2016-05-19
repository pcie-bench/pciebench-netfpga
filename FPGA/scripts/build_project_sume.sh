#!/bin/bash
#
# Copyright (c) 2016
# All rights reserved.
#
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
if [ -d "./project" ]; then
	while true; do
		echo -n "Output dir (./project) exists. Do you really want to overwrite this directory [y/n]? "
		read yn

	    case $yn in
	        [Yy] ) rm -rf ./project; break;;
	        [Nn] ) exit;;
	    esac
	done
fi

mkdir -p ./project
vivado -mode batch -source scripts/create_project_sume.tcl


