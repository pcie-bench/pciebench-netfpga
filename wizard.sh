#!/bin/bash - 
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
# José Fernando Zazo Rollón. 2016-03-16


operationMenu() {
	case $1 in
		s) cd FPGA; sh scripts/create_pcie_ref_project.sh; sh scripts/build_project_sume.sh; sh clean.sh; cd ..;;
		v) cd FPGA; sh scripts/create_pcie_ref_project.sh; sh scripts/build_project_vc709.sh; sh clean.sh; cd ..;;
		w) cd FPGA; sh scripts/implement_design.sh; sh clean.sh; cd ..;;
		p) cd FPGA; sh scripts/program_fpga.sh; sh clean.sh; cd ..;;
		t) cd FPGA; perl scripts/enable_bw_test.pl -s; sh clean.sh; cd ..;;
		d) cd FPGA; perl scripts/enable_bw_test.pl -u; sh clean.sh; cd ..;;
		0) echo "Bye"; cd FPGA; sh clean.sh; cd ..;;
		*) echo "Oopps!!! Bad option"; cd FPGA; sh clean.sh; cd ..;;
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
	t "Modify the sources in order to perform bandwidth measures"		 \
	d "Modify the sources in order to disable bandwidth measures"		 \
	p "Program the FPGA with a previously generated bitstream" \
	0 "Exit" 2>"${INPUT}"
	 
	menuOption=`cat ${INPUT}`
	operationMenu $menuOption
	exitMenu
	
	clear
else
	echo "******************************************************************"
	echo "*         DMA Core Project Generation utility                    *"
	echo "******************************************************************"
	echo "* [s] Create a vivado project with its core IPs (SUME)           *"
	echo "* [v] Create a vivado project with its core IPs (VC709)          *"
	echo "* [w] Synthesize, implement and generate bitstream               *"
	echo "* [p] Program the FPGA with a previously generated bitstream     *"
	echo "* [t] Modify the sources in order to perform bandwidth measures  *"
	echo "* [d] Modify the sources in order to disable bandwidth measures  *"
	echo "* [0] Exit/Stop                                                  *"
	echo "******************************************************************"
	echo -n "Enter your menu choice: "
	read menuOption
	operationMenu $menuOption
fi


