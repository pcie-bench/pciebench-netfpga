
/**
* @file huge_page.c
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
* @brief Implementation of huge page alloc and free operations.
* @author José Fernando Zazo Rollón, josefernando.zazo@estudiante.uam.es
* @date 2013-07-05
*/
#include "huge_page.h"
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>



#ifdef __ia64__
#define ADDR (void *)(0x8000000000000000UL)
#define FLAGS (MAP_SHARED | MAP_FIXED)
#else
#define ADDR (void *)(0x0UL)
#define FLAGS (MAP_SHARED)
#endif

static uint64_t sz = 0;

int alloc_hugepage (struct hugepage *hp, uint64_t size)
{
  sz = size;

  hp->identifier = open (FILE_NAME, O_CREAT | O_RDWR, 0755);

  if (hp->identifier < 0) {
    perror ("Open failed");
    return -1;
  }

  hp->data = mmap (ADDR, //vma_addr,
                   sz,
                   PROT_READ | PROT_WRITE,
                   FLAGS,
                   hp->identifier,
                   0);

  if (hp->data == MAP_FAILED) {
    perror ("mmap");
    unlink (FILE_NAME);
    return -1;
  }

  return 0;
}

void free_hugepage (struct hugepage *hp)
{
  munmap (hp->data, sz);
  close (hp->identifier);
  unlink(FILE_NAME);
  memset (hp, 0, sizeof (struct hugepage));
}

uint64_t hugepage_size()
{
  struct stat s;
  int err = stat("/sys/kernel/mm/hugepages", &s);

  if (err == -1) {
    return 0;
  } else {
    if (S_ISDIR(s.st_mode)) { /* it's a dir */
      int err = stat("/sys/kernel/mm/hugepages/hugepages-1048576kB", &s);
      if (err == -1) {
        int err = stat("/sys/kernel/mm/hugepages/hugepages-2048kB", &s);
        if (err == -1) {
          return 0;
        }
        //printf("Size = %ld\n", 2*1024);
        return 2048;
      } else {
        //printf("Size = %ld\n", 1024*1024*1024);
        return 1024 * 1024 * 1024;
      }
    } else {
      return 0;
    }
  }
  return 0;
}
uint64_t hugepage_number()
{
  uint64_t npages;
  char string[200];
  FILE* f;

  sprintf(string, "/sys/kernel/mm/hugepages/hugepages-%ldkB/free_hugepages", hugepage_size() / 1024);
  f = fopen(string, "r");
  if (f == NULL) {
    return 0;
  }
  fscanf(f, "%ld", &npages);
  fclose(f);


  return npages;
}
