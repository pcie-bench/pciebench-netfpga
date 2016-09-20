/**
* @file include/ioctl_commands.h
*
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
* @brief  This file contain common structures and ioctl commands that driver
* and user design will shared.
* @author José Fernando Zazo Rollón, josefernando.zazo@estudiante.uam.es
* @date 2013-07-03
*/

#ifndef IOCTLC_H
#define IOCTLC_H

#include <linux/ioctl.h>


#define KERNEL_PAGE_SIZE 4096 /**< Default page size in the system*/


#define MAX_PAGES      1024  /**< Maximum number of 4KB pages to be allocated.   */
#define LOG2_MAX_PAGES 10    /**< log2 of the maximum number of 4KB pages to be allocated. */

struct reg32 {
  uint32_t  data;      /**< The 4 byte data to write */
  uint32_t  bar;       /**< 0 represents BAR0, 1 the BAR1, etc. */
  uint64_t  offset;    /**< The offset in BAR0 where store the data */
};


/**
* @brief A general structure with all the information about a DMA transfer.
*/
struct dma_transfer {
  void *data;         /**< Pointer to the region of memory where
                         the driver will write/read */
  uint64_t length;    /**< Quantity of data to transfer/receive. Maximum the size of a page in the system, 4KB */
};

struct dma_buffer {
  char is_hp;         /**< Indicates if the buffer is stored in a huge page */
  void *data;         /**< Pointer to the region of memory where
                         the driver will write/read. Virtual direction */
  uint64_t length;    /**< Quantity of data to transfer/receive */
  uint64_t hp_size;    /**< Size in bytes of each huge page (2MB/1GB typically) */
  uint32_t n_hp;      /**< Number of Huge Pages in the virtual direction pointed by data */

};


/**
* @brief The structure that represents the descriptor of memory read/write request
*/
struct  dma_descriptor_sw {
  uint64_t address;              /**< [CONTROL] Address of the operation */
  uint64_t buffer_size;          /**< [CONTROL] Size of the buffer pointed by the address field */
  uint64_t length;               /**< [CONTROL] Length of the operation */
  uint64_t enable       : 1;     /**< [CONTROL] Activate dma engine when this descriptor has been dumped to the NIC */
  uint64_t u1           : 1;     /**< Unused */
  uint64_t is_c2s_op    : 1;     /**< [CONTROL] Is this is an operation from the NIC to the host ? */
  uint64_t is_s2c_op    : 1;     /**< [CONTROL] Is this is an operation from the host to the NIC ? */
  uint64_t address_mode : 2;     /**< [CONTROL] Is this is an operation from the host to the NIC ? */
  uint64_t u0           : 58;
  uint64_t number_of_tlps;
  uint64_t latency;
  uint64_t address_offset;          /**< [STATUS] Time attending request TLPs*/
  uint64_t address_inc;          /**< [STATUS] Time attending request TLPs*/
  uint64_t time_at_req;          /**< [STATUS] Time attending request TLPs*/
  uint64_t time_at_comp;         /**< [STATUS] Time attending completion TLPs*/
  uint64_t bytes_at_req;         /**< [STATUS] Bytes involved in request TLPs*/
  uint64_t bytes_at_comp;        /**< [STATUS] Bytes involved in completion TLPs*/
  uint64_t  index;               /**< [CONTROL] Index of the descriptor to update/retrieve information */
};

/* IOCTL operations */
#define IOCTL_MAGIC_NUMBER  '9' /**< Magic number of nfp_driver IOCTL operations.
                                    Check Documentation/magic-number.txt in the kernel tree */


#define NFPIOC_WRITE_32 _IOR(IOCTL_MAGIC_NUMBER, 1, struct reg32) /**< Store the data pointed by reg32.data in BAR0+reg32.offset */


#define NFPIOC_READ_32  _IOWR(IOCTL_MAGIC_NUMBER, 2, struct reg32) /**< Store the data pointed by BAR0+reg32.offset in reg32.data */

#define NFPIOC_WRITE_DMA_DESCRIPTOR         _IOR(IOCTL_MAGIC_NUMBER, 3, struct dma_descriptor_sw)

#define NFPIOC_READ_DMA_DESCRIPTOR         _IOWR(IOCTL_MAGIC_NUMBER, 4, struct dma_descriptor_sw)

#define NFPIOC_REGISTER_BUFFER   _IOR(IOCTL_MAGIC_NUMBER, 5, struct dma_transfer) /**< Register a buffer.
                                                         [INPUT]   dma_transfer.data will point to a region of memory
                                                         where we want to transfer to the card.
                                                         [INPUT]   dma_transfer.length indicates the size of the region. */

#define NFPIOC_UNREGISTER_BUFFER _IO(IOCTL_MAGIC_NUMBER, 6)  /**< Unregister a buffer. */

#define NFPIOC_WINDOW_SIZE _IOR(IOCTL_MAGIC_NUMBER, 7,uint64_t)  /**< Set the concurrent number of tags in reception. */

#define IOC_MAXNR 6 /**< Total number of IOCTL operations. */

#endif
