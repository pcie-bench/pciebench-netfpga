#!/bin/bash - 
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
# José Fernando Zazo Rollón. 2016-03-16


operationMenu() {
	case $1 in
		s) sh scripts/create_pcie_ref_project.sh; sh scripts/build_project_sume.sh; sh clean.sh;;
		v) sh scripts/create_pcie_ref_project.sh; sh scripts/build_project_vc709.sh; sh clean.sh;;
		w) sh scripts/implement_design.sh; sh clean.sh;;
		p) sh scripts/program_fpga.sh; sh clean.sh;;
		0) echo "Bye"; sh clean.sh;;
		*) echo "Oopps!!! Bad option"; sh clean.sh;;
	esac
}

exitMenu() {
	[ -f $INPUT ] && rm $INPUT
}


# "Main program" starts here
if hash dialog 2>/dev/null; then
	INPUT=/tmp/menu.sh.$$

	dialog --clear --backtitle "PCIe Benchmarking" \
	--title "[ DMA Core Project Generation utility ]" \
	--menu "Select your option." 15 100 6 \
	s "Create a vivado project with its core IPs for NetFPGA SUME" \
	v "Create a vivado project with its core IPs for VC709" \
	w "Synthesize, implement and generate bitstream" \
	p "Program the FPGA with a previously generated bitstream" \
	0 "Exit" 2>"${INPUT}"
	 
	menuOption=`cat ${INPUT}`
	operationMenu $menuOption
	exitMenu
	
	clear
else
	echo "***************************************************************"
	echo "*         DMA Core Project Generation utility                 *"
	echo "***************************************************************"
	echo "* [s] Create a vivado project with its core IPs (SUME)        *"
	echo "* [v] Create a vivado project with its core IPs (VC709)       *"
	echo "* [w] Synthesize, implement and generate bitstream            *"
	echo "* [p] Program the FPGA with a previously generated bitstream  *"
	echo "* [0] Exit/Stop                                               *"
	echo "***************************************************************"
	echo -n "Enter your menu choice [svwp0]: "
	read menuOption
	operationMenu $menuOption
fi


