/**
* @file   reg.c
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
* @brief  Implementation Read/write 4byte data from a specified offset
* @author José Fernando Zazo Rollón, josefernando.zazo@estudiante.uam.es
* @date 2013-09-23
*/
#include "nfp_types.h"
#include "reg.h"

void WriteReg32 (struct reg32 *r, struct nfp_card *card)
{
  void *bar;

  switch (r->bar) {
  case 0:
    bar = card->bar0;
    break;

  case 1:
    bar = card->bar1;
    break;

  case 2:
    bar = card->bar2;
    break;

  default:
    bar = NULL;
    return;
    break;
  }

  if (bar == NULL) {
    printk (KERN_INFO "Trying to access to an incorrect BAR");
  } else {
    iowrite32 (r->data, (u8 *) bar + r->offset);
  }
}

void ReadReg32 (struct reg32 *r, struct nfp_card *card)
{
  void *bar;

  switch (r->bar) {
  case 0:
    bar = card->bar0;
    break;

  case 1:
    bar = card->bar1;
    break;

  case 2:
    bar = card->bar2;
    break;

  default:
    bar = NULL;
    return;
    break;
  }

  if (bar == NULL) {
    printk (KERN_INFO "Trying to access to an incorrect BAR");
  } else {
    r->data = ioread32 ( (u8 *) bar + r->offset);
  }
}
