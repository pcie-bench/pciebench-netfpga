/**
* @file transfer.c
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
* @brief Copy/read operations by CPU or the DMA engine using the nfp_driver.
* @author José Fernando Zazo Rollón, josefernando.zazo@estudiante.uam.es
* @date 2014-05-23
*/
#include "transfer.h"
#include "init.h"
#include "huge_page.h"
#include "../include/ioctl_commands.h"
#include <sys/ioctl.h>
#include <sys/mman.h>

static struct hugepage hp; /**< Local variable that stores the fields associated to the current map */

uint32_t writeWord (uint8_t bar, uint32_t offset, uint32_t data)
{
  struct reg32 reg;
  int fd = getCharDeviceDescriptor();
  reg.bar    = bar;
  reg.data   = data;
  reg.offset = offset;
  ioctl (fd, NFPIOC_WRITE_32, &reg);
  return reg.data;
}

uint32_t readWord (uint8_t bar, uint32_t offset)
{
  struct reg32 reg;
  int fd = getCharDeviceDescriptor();
  reg.bar    = bar;
  reg.data   = 0;
  reg.offset = offset;
  ioctl (fd, NFPIOC_READ_32, &reg);
  return reg.data;
}

void *getFreePages(uint32_t npages)
{
  int fd = getCharDeviceDescriptor();

  void * address = NULL;
  address = mmap(NULL, KERNEL_PAGE_SIZE * npages, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
  if (address == MAP_FAILED) {
    perror("mmap: ");
    return NULL;
  }
  return address;
}

void unsetFreePages(void *address, uint32_t npages)
{
  munmap(address, KERNEL_PAGE_SIZE * npages);
}

void *getFreeHugePages(uint32_t npages)
{
  struct dma_buffer db;

  int fd = getCharDeviceDescriptor();

  uint64_t tsize;

  if (npages == 0) { // Alloc all possible free hugepages if 0
    npages = hugepage_number();
  }
  tsize = npages * hugepage_size();

  if (alloc_hugepage (&hp, tsize)) {
    close (fd);
    rte_exit (-1, "Hugepage alloc error\n");
  }


  db.is_hp  = 1;
  db.data   = hp.data;
  db.hp_size = hugepage_size();
  db.length = tsize;
  db.n_hp = npages;


  /* Comunicate driver the initial setup */
  /* di must point to the region of data and indicates its length */
  ioctl (fd, NFPIOC_REGISTER_BUFFER, &db);
  return hp.data;
}


void unsetHugeFreePages(void *address, uint32_t npages)
{
  int fd = getCharDeviceDescriptor();

  if (hp.data) {
    ioctl (fd, NFPIOC_UNREGISTER_BUFFER);
    free_hugepage (&hp);    /* Protect against possible reentry. */
  }
}

uint32_t writeDescriptor (struct dma_descriptor_sw *l)
{
  int fd = getCharDeviceDescriptor();

  ioctl (fd, NFPIOC_WRITE_DMA_DESCRIPTOR, l);
  return 0;
}

uint32_t readDescriptor (struct dma_descriptor_sw *l)
{
  int fd = getCharDeviceDescriptor();

  ioctl (fd, NFPIOC_READ_DMA_DESCRIPTOR, l);
  return 0;
}

uint32_t setWindowSize (uint64_t ws)
{

  int fd = getCharDeviceDescriptor();

  ioctl (fd, NFPIOC_WINDOW_SIZE, &ws);

  return 0;
}
