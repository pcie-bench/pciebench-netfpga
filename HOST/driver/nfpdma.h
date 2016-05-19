/**
* @file nfpdma.h
*
* Copyright (c) 2016
* All rights reserved.
*
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
* @brief  DMA engine and descriptor logic is implemented in this module.
* @author José Fernando Zazo Rollón, josefernando.zazo@estudiante.uam.es
* @date 2013-07-03
*/

#ifndef NFPDESC_H
#define NFPDESC_H

#include <linux/module.h>
#include <linux/moduleparam.h>
#include <linux/kernel.h>


#include "nfp_types.h"


/**
* @brief Start a S2C transaction.
*
* @param di   Indicates the position where the data is stored
* @param card Main structure.
*
* @return Number of bytes transferred.
*/
u64 dma_write (struct dma_transfer *di,  struct nfp_card *card);

/**
* @brief Start a C2S transaction
*
* @param di   Indicates the position where the data will be stored.
* @param card Main structure of the driver.
*
* @return The possible error code
*/
u64 dma_read (struct dma_transfer *di,  struct nfp_card *card);

/**
 * @brief Write the [CONTROL] fields of a struct dma_descriptor_sw to the FPGA
 *
 * @param dma_descriptor_sw A proper initialized structure with VALID data. *A missconfiguration
 * may lead to the freeze of the system*.
 * @param nfp_card The pointer to the main structure that represents the device
 *
 * @return 0 if the operation could be completed successfully
 */
u64 writeDMADescriptor (struct dma_descriptor_sw *di,  struct nfp_card *card);

/**
 * @brief Retrieve the [STATUS] fields of a particular descriptor in the FPGA and copy them
 * to a struct dma_descriptor_sw
 *
 * @param dma_descriptor_sw A proper initialized structure with VALID data. *A missconfiguration
 * may lead to the freeze of the system*.
 * @param nfp_card The pointer to the main structure that represents the device
 *
 * @return 0 if the operation could be completed successfully
 */
u64 readDMADescriptor (struct dma_descriptor_sw *di,  struct nfp_card *card);


/**
 * @brief This function let the system to dynamically adjust the number of
 * concurrent tags (in memory read request operations)
 *
 * @param ws The new value. As a general thumb rule, 32 offers the maximum performance
 * @param nfp_card The pointer to the main structure that represents the device
 */
void dma_set_window_size(u64 ws, struct nfp_card *card);
#endif
