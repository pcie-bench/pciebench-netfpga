/**
* @file init.h
*
* Copyright (c) 2016
* All rights reserved.
*
* as part of the DARPA MRC research programme.
*
* @NETFPGA_LICENSE_HEADER_START@
*
* Licensed to NetFPGA C.I.C. (NetFPGA) under one or more contributor
* license agreements.  See the NOTICE file distributed with this work for
* additional information regarding copyright ownership.  NetFPGA licenses this
* file to you under the NetFPGA Hardware-Software License, Version 1.0 (the
* "License"); you may not use this file except in compliance with the
* License.  You may obtain a copy of the License at:
*
*   http://www.netfpga-cic.org
*
* Unless required by applicable law or agreed to in writing, Work distributed
* under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
* CONDITIONS OF ANY KIND, either express or implied.  See the License for the
* specific language governing permissions and limitations under the License.
*
* @NETFPGA_LICENSE_HEADER_END@
*
*
* @brief Functions that will initialize the HW design and alloc the huge pages memory if necessary.
* @author José Fernando Zazo Rollón, josefernando.zazo@estudiante.uam.es
* @date 2014-05-23
*/
#ifndef _INIT_H_
#define _INIT_H_

#include <stdint.h>


#define CPU_AFFINITY 0x00        /**< CPU mask. The user design will use the proccessor 0 (see isolcpus) */
#define DATA_IN_FIFO_BEFORE_PROCEED 1000 /**< Number of 64 bits words in the fifo design before transmit any data */

/**
* @brief This function will alloc the HP memory and start the HW traffic generator.
*
* @param argc The number of user arguments.
* @param argv User arguments.
*
* @return  A distinct 0 value will indicate an error in the operation.
*/
int rte_eal_init (int argc, char **argv);
int rte_eal_init_hp (int argc, char **argv);  /* Alloc 1 huge page */

#define fpgaInit rte_eal_init

/**
* @brief This function will free the allocated structures of a rte_eal_init/rte_eal_init_hp
* invocation but the program wont exit.
*
* @param exit_code The error code the user wants to return.
* @param format A string format.
* @param ... Arguments of format.
*/
void rte_free (int exit_code, const char *format, ...);

/**
* @brief This function will free the allocated structures of a rte_eal_init/rte_eal_init_hp
* invocation and the program will exit.
*
* @param exit_code The error code the user wants to return.
* @param format A string format.
* @param ... Arguments of format.
*/
void rte_exit (int exit_code, const char *format, ...);
#define fpgaExit rte_exit

/**
* @brief Return the file id associated to /dev/nfp.
*
* @return The file identifier.
*/
int getCharDeviceDescriptor (void);

#endif
