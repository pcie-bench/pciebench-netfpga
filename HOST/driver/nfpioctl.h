/**
* @file nfpioctl.h
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
#ifndef NFPIOCTLDRIVER_H
#define NFPIOCTLDRIVER_H


#include "nfp_types.h"


/**
* @brief Literally an ioctl doesnt need to be registered. Instead this
* function create the char device that will treat correspondant IOCTL
* defined in include/ioctl_commands.h file.
*
* @param pdev A pointer to the pci device.
* @param card A pointer to the main struct in the driver.
*
* @return The possible code error.
*/
int nfpioctl_probe (struct pci_dev *pdev, struct nfp_card *card);



/**
* @brief Remove the char device and free resources.
*
* @param pdev A pointer to the pci device.
* @param card A pointer to the main struct in the driver.
*
* @return The possible code error.
*/
int nfpioctl_remove (struct pci_dev *pdev, struct nfp_card *card);

#endif
