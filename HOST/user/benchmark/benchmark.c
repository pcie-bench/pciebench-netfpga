/**
* @file benchmark.c
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
* @brief Utility that lets the user to perform PCIe benchmarking
* @author José Fernando Zazo Rollón, josefernando.zazo@estudiante.uam.es
* @date 2016-02-05
*/

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <sys/mman.h>
#include <ctype.h>
#include <fcntl.h>
#include "nfp_common.h"
#include <time.h>
#include "../middleware/huge_page.h"
#include "../include/ioctl_commands.h"

#define PAGE_SIZE            4096
#define MEMORY_READ_BOUNDARY 4096 // Do not touch. According to PCIe spec (section 2.2.7)
#define MAX_WINDOW_SIZE      32
#define MAX_DMA_DESCRIPTORS  1024
#define CACHE_SIZE           (16*1024*1024) // 16MB
#define MAX_READ_REQUEST_SIZE 4096
#define MAX_PAYLOAD           128

// Comment the following two lines if huge pages are not required
#define USE_HUGE_PAGES
#define NUMBER_PAGES         1

//#define NUMBER_PAGES         MAX_PAGES-1 //If using kenel pages, check that this value do NOT exced the one predefined in HOST/include/ioctl_commands.h

#ifndef ARRAY_SIZE
#define ARRAY_SIZE(arr) (sizeof(arr)/sizeof(*(arr)))
#endif

static uint64_t large_array[8*1024*1024];

struct offset_pattern {
  uint64_t initial_offset;
  uint64_t offset;
};

struct fixed_pattern {
  uint64_t initial_offset;
};
struct random_pattern {
  uint64_t initial_offset;
  uint64_t nsystempages;
  uint64_t cachelines;
  uint64_t windowsize;
};
struct sequential_pattern {
};

union properties {
  struct fixed_pattern      pfix;
  struct offset_pattern     poff;
  struct random_pattern     pran;
  struct sequential_pattern pseq;
};

enum pattern {
  FIX, // Fixed: always the same address
  SEQ, // Sequential
  RAN, // Random
  OFF  // Offset
};

enum direction {
  D2H,  // Device2host
  H2D,  // Host2device
  BOTH
};

enum cache {
  IGNORE,
  DISCARD,
  WARM
};

/**
* @brief Fields that will be extracted from args.
*/
struct arguments {
  uint64_t          niters;
  uint64_t          nbytes;
  uint64_t          wsize;
  uint8_t           pat;
  uint8_t           dir;
  uint8_t           cache;
  union properties  prop;
}; /**< Global variable with the user arguments */




/**
* @brief Explanation about how to run the program.
*/
void printUsage()
{
  printf ("This program has sveral modes of usage:\n"
          "· $benchmark -d <DIR> -p <PATTERN> [properties] -n <BYTES> -w <WINDOW_SIZE> -c <CACHE_OPTIONS> -l <NITERS>\n"
          "\tWhere \n"
          "\t\t <DIR> can be R/W/RW: \n"
          "\t\t\tR represents memory write requests from the FPGA \n"
          "\t\t\tW represents memory read requests from the FPGA \n"
          "\t\t\tRW represents a memory write request from the FPGA follow by a memory read request\n"
          "\t\t <PATTERN> can be FIX/SEQ/OFF/RAN for same address,sequential, fixed offset and random tests \n"
          "\t\t\t- FIX <offset> \n"
          "\t\t\t- OFF <offset> <unit size>  \n"
          "\t\t\t- RAN <offset> <window size (multiple of system PAGE_SIZE)>  \n"
          "\t\t <BYTES> is a value greater than 0 (necessarily a multiple of 4). Number of bytes per descriptor\n"
          "\t\t <WINDOW_SIZE> total tags that can be asked simultaneously in memory reads. Min 1, Max 32 \n"
          "\t\t <CACHE_OPTIONS> are: \n"
          "\t\t\t- ignore: Do nothing  \n"
          "\t\t\t- discard: Access in a random way before using the buffer  \n"
          "\t\t\t- warm: Preload in the cache the buffer before accessing to it \n"
          "\t\t <NITERS> is the number of iterations of the experiment\n"
         );
}



static unsigned long int string2bytes(char *s)
{
  int rmember;
  char unit;
  unsigned long int size;

  rmember = sscanf (s, "%ld%c", &size, &unit);

  if (rmember == 2) {
    if (toupper (unit) == 'G') {
      size *= 1024 * 1024 * 1024;
    } else if (toupper (unit) == 'M') {
      size *= 1024 * 1024;
    } else if (toupper (unit) == 'K') {
      size *= 1024;
    }
  }
  return size;
}

/**
* @brief Get information from user parameters.
*
* @param argc Number of arguments
* @param argv String associated with the arguments.
* @param arg The structure where the data will be stored.
*
* @return A negative value indicates en error.
*/
static int readArguments (int argc, char **argv, struct arguments *arg)
{
  int i;

  if (argc < 2 || argc > 16) {
    return -1;
  }

  memset (arg, 0, sizeof (struct arguments));
  arg->wsize = MAX_WINDOW_SIZE; // Default
  for (i = 1; i <= argc - 1; i++) {
    if (!strcmp (argv[i], "-n")) {
      i++;
      arg->nbytes = string2bytes(argv[i]);
    } else if (!strcmp (argv[i], "-l")) {
      i++;
      arg->niters = string2bytes(argv[i]);
    } else if (!strcmp (argv[i], "-w")) {
      i++;
      arg->wsize = string2bytes(argv[i]);
    } else if (!strcmp (argv[i], "-d")) {
      i++;
      if (strcmp(argv[i], "RW") == 0 || strcmp(argv[i], "rw") == 0 ) {
        arg->dir = BOTH;
      } else if (strcmp(argv[i], "R") == 0 || strcmp(argv[i], "r") == 0 ) {
        arg->dir = D2H;
      } else if (strcmp(argv[i], "W") == 0 || strcmp(argv[i], "w") == 0 ) {
        arg->dir = H2D;
      } else {
        return -1;
      }
    } else if (!strcmp (argv[i], "-c")) {
      i++;
      if (strcmp(argv[i], "discard") == 0) {
        arg->cache = DISCARD;
      } else if (strcmp(argv[i], "warm") == 0) {
        arg->cache = WARM;
      } else if (strcmp(argv[i], "ignore") == 0) {
        arg->cache = IGNORE;
      } else {
        return -1;
      }
    } else if (!strcmp (argv[i], "-p")) {
      i++;
      if (strcmp(argv[i], "SEQ") == 0) {
        arg->pat = SEQ;
      } else if (strcmp(argv[i], "FIX") == 0) {
        arg->pat = FIX;
        i++;
        arg->prop.pfix.initial_offset = string2bytes(argv[i]);;
      } else if (strcmp(argv[i], "RAN") == 0) {
        arg->pat = RAN;
        i++;
        arg->prop.pran.initial_offset = string2bytes(argv[i]);
        i++;
        arg->prop.pran.nsystempages = (string2bytes(argv[i])+PAGE_SIZE-1)/PAGE_SIZE;
        arg->prop.pran.cachelines = string2bytes(argv[i])/64;
        arg->prop.pran.windowsize = string2bytes(argv[i]);
        if(arg->prop.pran.nsystempages == 0) {
                return -1;
        }
        srand(time(NULL));
      } else if (strcmp(argv[i], "OFF") == 0) {
        arg->pat = OFF;
        i++;
        arg->prop.poff.initial_offset = string2bytes(argv[i]);
        i++;
        arg->prop.poff.offset =  string2bytes(argv[i]);
      } else {
        return -1;
      }
    } else {
      return -1;
    }
  }
  if (arg->wsize > MAX_WINDOW_SIZE || arg->wsize < 1)  {
    fprintf(stderr, "niter is greater or equal than the total number of descriptors\n");
    return -1;
  }

  if (arg->nbytes % 4)  {
    fprintf(stderr, "nbytes is not a multiple of 4\n");
    return -1;
  }
  if (arg->niters >= MAX_DMA_DESCRIPTORS || arg->niters <= 0 )  {
    fprintf(stderr, "niter is greater or equal than the total number of descriptors\n");
    return -1;
  }
  return 0;
}

/*
 * Before starting a test we aim thrash the cache by randomly
 * writing to elements in a 64MB large array.
 */
static void thrash_cache(void) {
  uint64_t i, r;
  for (i = 0; i < 4*ARRAY_SIZE(large_array); i++) {
      r = rand();
      large_array[r % ARRAY_SIZE(large_array)] = (uint64_t)i * r;
  }
}

/* Warm the host buffers for a given window size. The window size is
 * rounded up to the nearest full page. */
static void warm_cache(uint64_t *pmem, uint64_t total_size)
{
  uint64_t i;
  for (i = 0; i < 4 * total_size; i++) {
    pmem[i % (total_size / sizeof(uint64_t))] = (uint64_t)i;
  }
}

struct dma_descriptor_sw dlist [MAX_DMA_DESCRIPTORS];
int main(int argc, char **argv)
{
  void *pmem;
  struct arguments args;
  int i, j;
  char success;
  uint64_t total_size;
  uint64_t prev_page=-1;
  uint64_t page=0;
  uint64_t r;
  uint64_t address;


  if (readArguments (argc, argv, &args)) {
    printUsage();
    return 0;
  }

  /* Initialize the driver */
  if (fpgaInit (argc, argv) < 0) {
    fpgaExit (-1, "There was an error");
  }


#ifdef USE_HUGE_PAGES
  pmem = getFreeHugePages(NUMBER_PAGES);
  total_size = NUMBER_PAGES ? NUMBER_PAGES * hugepage_size() : hugepage_number() * hugepage_size();
#else
  pmem = getFreePages(NUMBER_PAGES); // Get a buffer in kernel space (NPAGES*PAGE_SIZE = NPAGES*1GB)
  total_size = NUMBER_PAGES * KERNEL_PAGE_SIZE;
#endif
  if (pmem == NULL) {
    printf(  "[MEMORY]     No free pages\n");
    fpgaExit (-1, "Error mapping kernel memory\n");
  }

  setWindowSize(args.wsize);
  dlist[0].address = 0;
  fprintf(stderr, "pattern,descriptor,size,address,time_req_ns,bytes_req,bandwidth_req_gbps,time_comp_ns,bytes_comp,bandwidth_comp_gbps,total_time_ns,total_bytes,bidirectional_bandwidth_gbps\n");

  for (i = 0, j = 0; j < args.niters; i++, j++) {
    dlist[i].length        = args.nbytes;
    dlist[i].is_c2s_op     = args.dir == D2H || args.dir == BOTH;
    dlist[i].is_s2c_op     = args.dir == H2D || args.dir == BOTH;
    dlist[i].index         = i;
    dlist[i].enable        = 1;

    switch (args.pat) {
    case FIX:
      dlist[i].address       = args.prop.pfix.initial_offset; // No offset but we can specify the initial
      success = !((((args.nbytes - 1) % MEMORY_READ_BOUNDARY + dlist[i].address) / MEMORY_READ_BOUNDARY != (dlist[i].address) / MEMORY_READ_BOUNDARY)
                  || (args.nbytes % MEMORY_READ_BOUNDARY == 0 && dlist[i].address % MEMORY_READ_BOUNDARY != 0)); // End of boundary reached
      break;
    case OFF:
      dlist[i].address       = i * args.prop.poff.offset + args.prop.poff.initial_offset;         // Fixed offset + initial unalignment
      success = !((((args.nbytes - 1) % MEMORY_READ_BOUNDARY + dlist[i].address) / MEMORY_READ_BOUNDARY != (dlist[i].address) / MEMORY_READ_BOUNDARY)
                  || (args.nbytes % MEMORY_READ_BOUNDARY == 0 && dlist[i].address % MEMORY_READ_BOUNDARY != 0)); // End of boundary reached
      break;
    case SEQ:
      dlist[i].address       = i * args.nbytes;                 // Sequential
      success = !((((args.nbytes - 1) % MEMORY_READ_BOUNDARY + dlist[i].address) / MEMORY_READ_BOUNDARY != (dlist[i].address) / MEMORY_READ_BOUNDARY)
                  || (args.nbytes % MEMORY_READ_BOUNDARY == 0 && dlist[i].address % MEMORY_READ_BOUNDARY != 0)); // End of boundary reached
      break;
    case RAN:
        while(1) {
        	r = rand();
                address = (r % args.prop.pran.cachelines) * 64;
                address %= args.prop.pran.windowsize;

                page = address / PAGE_SIZE;

                if(args.prop.pran.nsystempages == 1 || page != prev_page) {
                        prev_page = page;
                        break;
                }
        }

        dlist[i].address = address;

        success = !((((args.nbytes-1)%MEMORY_READ_BOUNDARY+dlist[i].address)/MEMORY_READ_BOUNDARY!=(dlist[i].address)/MEMORY_READ_BOUNDARY)
                  || (args.nbytes%MEMORY_READ_BOUNDARY==0 && dlist[i].address%MEMORY_READ_BOUNDARY!=0));  // End of boundary reached
        break;
    default:
      fprintf(stderr, "Pattern not implemented\n");
      success = 0;
      break;
    }

    if (!success) {
      //fprintf(stderr, "An error was detected\n"); // Just ignore that combination of address-size
      i--;
    } else {
      switch (args.pat) {
      case FIX:
        fprintf(stderr, "FIX,");
        break;
      case OFF:
        fprintf(stderr, "OFF,");
        break;
      case SEQ:
        fprintf(stderr, "SEQ,");
        break;
      case RAN:
        fprintf(stderr, "RAN,");
        break;
      default:
        fprintf(stderr, "Pattern not implemented\n");
        success = 0;
        break;
      }
      switch (args.cache) {
      case WARM:
        if (args.pat != RAN) {
          warm_cache((uint64_t *)((uint8_t *)pmem + (uint64_t)((dlist[i].address >> 2) << 2)), args.nbytes);
        }
        break;
      case DISCARD:
          thrash_cache();
       	  break;
      }
      fprintf(stderr, "%d,%ld,%ld", i, args.nbytes, dlist[i].address );
      writeDescriptor(&(dlist[i]));
      dlist[i].index = (dlist[i].index + 1) % MAX_DMA_DESCRIPTORS;
      readDescriptor(&(dlist[i]));

      if (args.cache == WARM) { // Give some time to the system to populate the cache memory. In this case, all the window is we warmed up
        if (args.pat == RAN) {
	  warm_cache((uint64_t *)((uint8_t *)pmem), args.prop.pran.windowsize);
        }
      }

      //fprintf(stderr, "waiting....");
      //getchar();	
      fprintf(stderr, ",%ld,%ld,%lf", dlist[i].time_at_req * 4, dlist[i].bytes_at_req * 4, dlist[i].time_at_req ? args.nbytes * 8.0 / (dlist[i].time_at_req * 4) : 0);
      fprintf(stderr, ",%ld,%ld,%lf", dlist[i].time_at_comp * 4, dlist[i].bytes_at_comp * 4, dlist[i].time_at_comp ? args.nbytes * 8.0 / (dlist[i].time_at_comp * 4) : 0);
      fprintf(stderr, ",%ld,%ld,%lf\n", dlist[i].latency * 4,   (dlist[i].bytes_at_comp + dlist[i].bytes_at_req) * 4, (args.nbytes) * 8.0 / (dlist[i].latency * 4));
    }
  }
  // Free the memory
#ifdef USE_HUGE_PAGES
  unsetHugeFreePages(pmem, NUMBER_PAGES );
#else
  unsetFreePages(pmem, NUMBER_PAGES );
#endif
  // Free FPGA resources
  fpgaExit (0, "");
  return 0;
}
