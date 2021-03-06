/**
* @file nfpmem.h
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
* @brief  Creation of a char device and handleing of the IOCTL operations.
* @author José Fernando Zazo Rollón, josefernando.zazo@estudiante.uam.es
* @date 2013-07-03
*/
#ifndef NFPMEMDRIVER_H
#define NFPMEMDRIVER_H


#include "nfp_types.h"


/**
 * @brief Initialize the internal buffers of the driver. In this case, a huge page (or several)
 * that has been  previously allocated in user space are set as the default location for
 * memory read and write requests
 *
 * @param nfp_card Structure describing the device
 * @param dma_buffer The information provided by the user space
 *
 * @return 0 if everything was ok
 */
int reg_hugemem(struct nfp_card *card, struct dma_buffer *db);

/**
 * @brief Unmap a previous registered buffer
 *
 * @param nfp_card Structure describing the device
 * @return 0 if everything was ok
 */
int unreg_hugemem(struct nfp_card *card);

#endif
