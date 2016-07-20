#!/usr/bin/perl
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


use strict;

my $orig_sw_file = "../HOST/user/benchmark/benchmark.c";
my $orig_hw_file = "source/hdl/dma/dma_logic.v";
my $sw_file = "../HOST/user/benchmark/benchmark.bak";
my $hw_file = "source/hdl/dma/dma_logic.bak";

`mv $orig_sw_file $sw_file`;
`mv $orig_hw_file $hw_file`;

my $enable_string_sw = "#define BW_TEST\n";
my $disable_string_sw = "// #define BW_TEST\n";

my $enable_string_hw = "\tdma_benchmarking #(.C_MODE(1)) dma_benchmarking_i (\n";
my $disable_string_hw = "\tdma_benchmarking #(.C_MODE(0)) dma_benchmarking_i (\n";

my $mode;

my $num_args = $#ARGV + 1;
if ($num_args > 1) {
    print "\nUsage: enable_bw_test.pl [-s|-u]\n";
    print "\n  -s: Set the mode to device to host bandwidth measurement\n";
    print "\n  -u: Unset the mode  device to host bandwidth measurement (default option) \n";
    exit;
}

my $user_arg=$ARGV[0];

if($user_arg eq "-s") {
	$mode = 1;
} elsif($user_arg eq "-u") {
	$mode = 0;
} else {
    print "\nUnidentified argument $user_arg\n";
	exit;
}


open(my $fd, $sw_file)
  or die "Could not open file '$sw_file' $!";

open (my $fout, ">", $orig_sw_file) or die $!;

if($mode==1) { 
	while (my $line = <$fd>) {
		if (index($line, $disable_string_sw) != -1) {
		    print $fout $enable_string_sw;
		} else {
			print $fout $line;
		}
	}
} else {
	while (my $line = <$fd>) {
		if (index($line, $enable_string_sw) != -1) {
		    print $fout $disable_string_sw;
		} else {
			print $fout $line;
		}
	}	
}
close($fd);
close($fout);


open($fd, $hw_file)
  or die "Could not open file '$hw_file' $!";

open (my $fout, ">", $orig_hw_file) or die $!;

if($mode==1) { 
	while (my $line = <$fd>) {
		if (index($line, $disable_string_hw) != -1) {
		    print $fout $enable_string_hw;
		} else {
			print $fout $line;
		}
	}
} else {
	while (my $line = <$fd>) {
		if (index($line, $enable_string_hw) != -1) {
		    print $fout $disable_string_hw;
		} else {
			print $fout $line;
		}
	}	
}
close($fd);
close($fout);
