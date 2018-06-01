# Copyright (c) 2018
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
# José Fernando Zazo Rollón. 2018-06-01

cmake_minimum_required (VERSION 2.8.11)
project (pciebenchmark)

option(VERBOSE_APP "Show the output of the Vivado commands that are executed by the Makefile" off)
set(fpga  "netfpga") # netfpga / vcu709

INCLUDE(constants.cmake)

set(CMAKE_HOST_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/HOST)

check_for_program(vivado)
check_vivado_version("2014.4 2017.4")


add_subdirectory (FPGA)

add_custom_command(
    OUTPUT ${CMAKE_HOST_DIRECTORY}/bin/nfp_driver
    COMMAND make driver
    WORKING_DIRECTORY ${CMAKE_HOST_DIRECTORY}
    COMMENT "Compiling the driver"    
)
add_custom_command(
    OUTPUT  ${CMAKE_HOST_DIRECTORY}/bin/benchmark
    COMMAND make benchmark
    WORKING_DIRECTORY ${CMAKE_HOST_DIRECTORY}
    COMMENT "Compiling the SW: benchmarking utility"    
)
add_custom_command(
    OUTPUT  ${CMAKE_HOST_DIRECTORY}/bin/rwBar
    COMMAND make rwBar
    WORKING_DIRECTORY ${CMAKE_HOST_DIRECTORY}
    COMMENT "Compiling the SW: R/W register utility"    
)
add_custom_target (driver DEPENDS ${CMAKE_HOST_DIRECTORY}/bin/nfp_driver)
add_custom_target (benchmark DEPENDS ${CMAKE_HOST_DIRECTORY}/bin/rwBar ${CMAKE_HOST_DIRECTORY}/bin/benchmark)
add_custom_target (sw ALL DEPENDS driver benchmark)

