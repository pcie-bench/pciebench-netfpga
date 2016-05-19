/**
* @file huge_page.h
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
* @brief A basic library that can manage huge pages in user space.
* @author José Fernando Zazo Rollón, josefernando.zazo@estudiante.uam.es
* @date 2013-07-04
*/
#ifndef HP_H
#define HP_H

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <sys/mman.h>
#include <unistd.h>
#include <fcntl.h>


//#define HUGEPAGE_SIZE   (1024UL*1024UL*1024UL)     /**< Size of each page */
//#define NUMBER_HUGEPAGE 8UL                 /**< Number of pages */
#define FILE_NAME     "/dev/hugepages/test"    /**< File associated with the page (mmap will be invoked under a fd
                                            pointing to this file). */


/**
* @brief Structure of a huge page.
*/
struct hugepage {
  int  identifier; /**< File descriptor to FILE_NAME file. User doesnt need to initialize this field,
                    the library makes it. */
  void *data;      /**< Pointer to the region of memory of the huge page. */
};



/**
* @brief The "malloc" function of a huge page.
*
* @param hp Struct of type struct hugepage that will be initialized properly.
* @param size The size that we wish.
*
* @return 0 if everything was correct, a negative value in other situation.
*/
int alloc_hugepage (struct hugepage *hp, uint64_t npages);


/**
* @brief Free the previously allocated memory on the structure pointed by hp.
*
* @param hp A struct hugepage which was previously allocated by a alloc_hugepage called.
*/
void free_hugepage (struct hugepage *hp);

/**
 * @brief Get the current size configuration of huge pages (size: 2MB or 1GB)
 *
 * @return The current configuration of the system
 */
uint64_t hugepage_size();

/**
 * @brief Get the current number configuration of huge pages (Total number of free hugepages)
 *
 * @return The total number of free huge pages
 */
uint64_t hugepage_number();
#endif
