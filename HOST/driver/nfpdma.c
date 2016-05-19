/**
* @file nfpdma.c
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
* @brief Implementation of descriptor logic and dma engine configuration
* @author José Fernando Zazo Rollón, josefernando.zazo@estudiante.uam.es
* @date 2013-07-05
*/
#include "nfpdma.h"
#include <linux/io.h>
#include <linux/time.h>



u64 s = 0, e = 0; /* Start time, end time of the last DMA operation */
u64 llength = 0;
u32 ldescriptor = 0;


static inline u64 getToD(void)
{
  ktime_t t;
  t = ktime_get();
  return ktime_to_us(t);
}


u64 phy_addr[MAX_NUM_DMA_DESCRIPTORS];
u64 phy_size[MAX_NUM_DMA_DESCRIPTORS];

u8  phy_addr_valid[MAX_NUM_DMA_DESCRIPTORS] = {0};


void dma_set_window_size(u64 ws, struct nfp_card *card)
{
  struct dma_core *dma = card->dma;
  dma->dma_engine[0].total_bytes = ws;
  return;
}


u64 writeDMADescriptor (struct dma_descriptor_sw *dd,  struct nfp_card *card)
{
  struct dma_core *dma = card->dma;
  int i;
  u8 exit_loop = 0;
  u8 control;

  // Obtain the IO address
  phy_addr[dd->index] = (u64) pci_map_single (card->pdev, (u8 *) dd->address, dd->length,  PCI_DMA_BIDIRECTIONAL);

  // Copy address and size to the FPGA
  memcpy_toio(&(dma->dma_engine[0].dma_descriptor[dd->index].address) , &(phy_addr[dd->index]), 8);
  memcpy_toio(&(dma->dma_engine[0].dma_descriptor[dd->index].size) , &(dd->length), 8);
  phy_addr_valid[dd->index] = 1;
  phy_size[dd->index] = dd->length;

  // Copy the direction. Check dma_engine_manager.v to obtain the mapping scpecification
  control = dd->is_c2s_op << 2;
  control += dd->is_s2c_op ? (1 << 3) : 0;
  memcpy_toio(&(dma->dma_engine[0]) , &(control), 1);

  // Update the last descriptor count
  ldescriptor = (ldescriptor) % MAX_NUM_DMA_DESCRIPTORS;
  dma->dma_engine[0].complete_until_descriptor = ldescriptor;
  ldescriptor = (ldescriptor + 1) % MAX_NUM_DMA_DESCRIPTORS;

  // If we have to process this descriptor immediately, poll the device.
  if (!dd->enable) {
    return 0;
  }
  s = getToD();
  // dma->dma_engine[0].enable = 1;
  control |= 1;
  memcpy_toio(&(dma->dma_engine[0]) , &(control), 1);

  do { //Dont stub the cpu. If the OP lasts more than Xs... has the core failed? The time is measured in the FPGA, so we do not
    // loose accuracy.
    e = getToD();
    exit_loop = !(dma->dma_engine[0].enable) || (e - s) > 10000000;
  } while ( !exit_loop );

  if (e - s > 10000000) {
    printk(KERN_ERR "Exit by timeout\n");
  } else {
    //printk(KERN_ERR "Operation complete\n");
  }

  // Free the resources
  for (i = 0; i < MAX_NUM_DMA_DESCRIPTORS; i++) {
    if (phy_addr_valid[i]) {
      pci_unmap_single (card->pdev, phy_addr[i], phy_size[i], PCI_DMA_BIDIRECTIONAL);
    }
    phy_addr_valid[i] = 0;
  }
  return 0;
}

u64 readDMADescriptor (struct dma_descriptor_sw *dd,  struct nfp_card *card)
{
  struct dma_core *dma = card->dma;

  // Just access to the proper positions and copy the information from the descriptor with index dd->index
  memcpy_fromio( &(dd->latency), &(dma->dma_engine[0].dma_descriptor[dd->index].latency), 8);
  memcpy_fromio( &(dd->time_at_req), &(dma->dma_engine[0].dma_descriptor[dd->index].time_at_req), 8);
  memcpy_fromio( &(dd->time_at_comp), &(dma->dma_engine[0].dma_descriptor[dd->index].time_at_comp), 8);
  memcpy_fromio( &(dd->bytes_at_req), &(dma->dma_engine[0].dma_descriptor[dd->index].bytes_at_req), 8);
  memcpy_fromio( &(dd->bytes_at_comp), &(dma->dma_engine[0].dma_descriptor[dd->index].bytes_at_comp), 8);
  return dd->latency;
}
