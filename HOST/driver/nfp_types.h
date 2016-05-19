/**
* @file nfp_types.h
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
* @brief  Definition of main structures in the module.
* @author José Fernando Zazo Rollón, josefernando.zazo@estudiante.uam.es
* @date 2013-07-03
*/

#ifndef NFPDRIVER_H
#define NFPDRIVER_H

#include <linux/netdevice.h>
#include <linux/cdev.h>
#include <asm/atomic.h>
#include <linux/ioctl.h>

#include <linux/workqueue.h>
#include <linux/module.h>
#include <linux/moduleparam.h>
#include <linux/kernel.h>
#include <linux/init.h>
#include <linux/stat.h>
#include <linux/pci.h>
#include <linux/interrupt.h>

#include "../include/ioctl_commands.h"

#define PCI_VENDOR_ID_NFP 0x10EE /**< Vendor of the PCI device */
#define PCI_DEVICE_ID_NFP 0x7038 /**< Device code */


#define DEVICE_NAME        "nfp"     /**< Name of the device ( a char device will be create under /dev/DEVICE_NAME ) */
#define CPU_AFFINITY_MASK  0x02      /**< Core that will run the module. it must be a mask. Example: Proccessors 3 and 4 1100b */

#define MAX_NUM_DMA_ENGINES 2        /**< Maximum number of DMA engines in the device */

#define ADDRES_OFFSET           0x199  /**< Initial offset in the BAR0 that indicates the address of the second bar (so a translation from PCIe addresses to FPGA ones can be made). */
#define MAX_NUM_DMA_DESCRIPTORS 1024   /**< Maximum number of DMA engines in the device */
#define OFFSET_BETWEEN_ENGINES  0x4000 /**< Offset in 64b words between engines in the HDL design */
#define DMA_OFFSET              0x200  /**< Initial offset in the BAR0 to the DMA registers.
At DMA_OFFSET                          dma_engine[0]
At DMA_OFFSET+OFFSET_BETWEEN_ENGINES   dma_engine[1]

.
.
.

At DMA_OFFSET+i*OFFSET_BETWEEN_ENGINES dma_engine[i]



At DMA_OFFSET+MAX_NUM_DMA_ENGINES*OFFSET_BETWEEN_ENGINES:  dma_common_block

*/


#define MAX_TLP_SIZE   128     //In bytes. It must be a 32b multiple


struct  __attribute__ ((__packed__)) dma_descriptor {
  u64  address;
  u64  size;
  u64  generate_irq : 1;
  u64  u0           : 63;
  u64  latency;

  u64  time_at_req;   // Divided by 4
  u64  time_at_comp;  // Divided by 4
  u64  bytes_at_req;  // Divided by 4
  u64  bytes_at_comp; // Divided by 4

};


struct  __attribute__ ((__packed__)) dma_engine {
  u64  enable         : 1;
  u64  reset          : 1;
  u64  is_c2s         : 1;
  u64  is_s2c         : 1;
  u64  u0             : 60;
  u16  complete_until_descriptor;
  u16  u1;
  u32  u3;
  u64  total_time;             //Read: Time that consumed the previous operation. Write: Maximum timeout for a C2S operation
  u64  total_bytes;            //Only read
  struct dma_descriptor  dma_descriptor[MAX_NUM_DMA_DESCRIPTORS];

  u64 u2[OFFSET_BETWEEN_ENGINES - 4 - MAX_NUM_DMA_DESCRIPTORS * sizeof(struct dma_descriptor) / 8];    // Unused
};

struct __attribute__ ((__packed__)) dma_common_block {
  uint64_t max_payload : 3; // The maximum payload size being used by the DMA core.
  // this size may be different than the system-programmed Max Payload
  // The size is expressed as: 2^{max_payload} * 128 bytes. Common examples:
  //    · 000 = 128  Bytes
  //    · 001 = 256  Bytes
  //    · 010 = 512  Bytes
  //    · 011 = 1024 Bytes
  //    · 100 = 2048 Bytes
  //    · 101 = 4096 Bytes
  uint64_t max_read_request : 3; // The read request size being used by the DMA core.
  // this size may be different than the system-programmed Max Read Request
  // The size is expressed as: 2^{max_payload} * 128 bytes. Common examples:
  //    · 000 = 128  Bytes
  //    · 001 = 256  Bytes
  //    · 010 = 512  Bytes
  //    · 011 = 1024 Bytes
  //    · 100 = 2048 Bytes
  //    · 101 = 4096 Bytes
  uint64_t irq_enable  : 1; // Global DMA Interrupt Enable; this bit globally enables/disables interrupts.
  uint64_t user_reset  : 1;

  uint64_t engine_finished : 16;  // Bitmask of engines that have completed the operation. It is useful if
  // a polling strategy is applied.
  uint64_t u0 : 32;

};



struct  __attribute__ ((__packed__)) dma_core {
  struct dma_engine       dma_engine[MAX_NUM_DMA_ENGINES];
  struct dma_common_block dma_common_block;
};



struct mem {
  void      *virtual;        /**<  Pointer to a region of memory */

  u64       length;          /**<  Length of the allocated memory */
  u64       page_size;          /**<  Length of the allocated memory */
  u64       npages;          /**<  Number of pages pointed by virtual */
  u64       page_address[16];   /**<  Direction of such pages */
};

struct mmap_info {
  char *data; /* the data */
  int last;       /* A circular buffer of pages */
  int first;
  int active;
  dma_addr_t dma_handle;
  struct page *page_list;
};


/**
* @brief Main structure of the driver. All information about the device and the DMA transactions
* (descriptors, user memory,...) are registered here.
*/
struct nfp_card {
  struct pci_dev *pdev;        /**< Pointer to the physical dev */
  void *bar0;                  /**< Pointer to bar0 */
  void *bar1;                  /**< Pointer to bar1 */
  void *bar2;                  /**< Pointer to bar2 */

  struct cdev     cdev;        /**< Neccesary for the  IOCTL commands */
  dev_t  dev;                  /**< Device associated with the char device.
                                 Needed to delete the char device on rmmod call  */
  struct class *dev_class;     /**< Class of the char device.
                                  Needed to delete the char device on rmmod call  */



  struct semaphore sem_op;     /**< Mutex Semaphore for IOCTL operations. */

  struct dma_core *dma;
  struct mem  buffer;
  struct mmap_info mmap_info;
};




#endif
