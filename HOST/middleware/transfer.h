/**
* @file transfer.h
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
* @brief Copy/read operations by CPU or the DMA engine using the nfp_driver.
* @author José Fernando Zazo Rollón, josefernando.zazo@estudiante.uam.es
* @date 2014-05-23
*/
#ifndef _TRANSFER_H_
#define _TRANSFER_H_


#include <stdio.h>
#include <stdint.h>
#include "../include/ioctl_commands.h"



/**
* @brief This function returns a value in the specify bar at the specify offset.
*
* @param bar Base address register where the data is going to be read.
* @param offset Offset where the data is going to be read.
*
* @return The 32 bits  read word.
*/
uint32_t readWord (uint8_t bar, uint32_t offset);

/**
* @brief This function writes a value in the specify bar at the specify offset.
*
* @param bar Base address register where the data is going to be written.
* @param offset  Offset where the data is going to be written.
* @param data The data that will be written.
*
* @return The 32 bits word (parameter data).
*/
uint32_t writeWord (uint8_t bar, uint32_t offset, uint32_t data);

/**
 * @brief Communicate to the driver that the [CONTROL] fields of a descriptor are to be
 * written. *The user must check that the transaction is valid or the system could crash*
 *
 * @param dma_descriptor_sw The new values specify by the user program
 * @return The possible error code, 0 if ok
 */
uint32_t writeDescriptor (struct dma_descriptor_sw *l);

/**
 * @brief Communicate to the driver that the [STATUS] fields of a descriptor are to be
 * read. *The user must check that the transaction is valid or the system could crash*
 *
 * @param dma_descriptor_sw The structure where the data will be copied
 * @return The possible error code, 0 if ok
 */
uint32_t readDescriptor (struct dma_descriptor_sw *l);


/**
 * @brief Asked the kernel for a buffer sustained on kernel pages
 *
 * @param npages Number of 4KB pages that will be asked
 * @return The pointer to the buffer in userspace. NULL if it is
 * impossible to obtain such buffer
 */
void *getFreePages(uint32_t npages);
/**
 * @brief Asked the kernel for a buffer sustained on huge pages
 *
 * @param npages Number of 1GB pages that will be asked
 * @return The pointer to the buffer in userspace. NULL if it is
 * impossible to obtain such buffer
 */
void *getFreeHugePages(uint32_t npages);

/**
 * @brief Free a previously allocated buffer in kernel space
 *
 * @param address Returned address by getFreePages
 * @param npages Number of pages that were asked in the invocation of getFreePages
 */
void unsetFreePages(void *address, uint32_t npages);

/**
 * @brief Free a previously allocated buffer with huge pages
 *
 * @param address Returned address by getFreeHugePages
 * @param npages Number of pages that were asked in the invocation of getFreeHugePages
 */
void unsetHugeFreePages(void *address, uint32_t npages);

/**
 * @brief Update the number of concurrent tags in memory read requests.
 *
 * @param ws The new value to be established
 * @return 0 if everything was OK
 */
uint32_t setWindowSize (uint64_t ws);


#endif
