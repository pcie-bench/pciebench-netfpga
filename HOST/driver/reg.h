/**
* @file   reg.h
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
* @brief  Read/write 4byte data from a specified offset
* @author José Fernando Zazo Rollón, josefernando.zazo@estudiante.uam.es
* @date 2013-09-23
*/
#include "nfp_types.h"

#ifndef NFPREG32_H
#define NFPREG32_H

/**
* @brief Write to bar0 with  the data pointed by r and the position specify
* by r.
*
* @param r A reg32 structure pointer.
* @param card The main structure of the driver.
*/
void WriteReg32 (struct reg32 *r, struct nfp_card *card);


/**
* @brief Reads from bar0 in the direction pointed by r and writes the result in r.
*
* @param r A reg32 structure pointer.
* @param card The main structure of the driver.
*/
void ReadReg32 (struct reg32 *r, struct nfp_card *card);

#endif
