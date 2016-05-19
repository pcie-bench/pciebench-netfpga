/**
* @file init.c
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
* @brief Functions that will initialize the HW design and alloc the huge pages memory if necessary.
* @author José Fernando Zazo Rollón, josefernando.zazo@estudiante.uam.es
* @date 2014-05-23
*/
#include "init.h"
#include "debug.h"

#include "../include/ioctl_commands.h"



#include <stdio.h>
#include <stdint.h>
#include <stdarg.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#ifndef __USE_GNU
#define __USE_GNU
#endif
#include <sched.h>


static int fd = 0;

/**
* @brief This function invoke the scheduler to use the indicate CPU.
*
* @return The possible error code.
*/
static void set_affinity()
{
  cpu_set_t my_set;        /* Define your cpu_set bit mask. */
  CPU_ZERO (&my_set);      /* Initialize it all to 0, i.e. no CPUs selected. */
  CPU_SET (CPU_AFFINITY, &my_set);    /* set the bit that represents core 0. */
  sched_setaffinity (0, sizeof (cpu_set_t), &my_set);     /* Set affinity of tihs process to */
}


int rte_eal_init (int argc, char **argv)
{
  FILE *log;
  /* Set up log */
  log = fdopen (STDOUT_FILENO, "w");
  rte_openlog_stream (log);
  set_affinity();
  /* Alloc huge pages. */
  fd = open ("/dev/nfp", O_RDWR);

  if (fd <= 0) {
    rte_exit (-1, "Error opening /dev/nfp. Do you have privileges?\n");
  }

  return 0;
}

void rte_free (int exit_code, const char *format, ...)
{
  va_list ap;

  va_start (ap, format);
  rte_vlog (0, 0, format, ap);
  va_end (ap);

  if (fd) {
    fclose (rte_actuallog_stream());
    close (fd);
    fd = 0;
  }
}

void rte_exit (int exit_code, const char *format, ...)
{
  rte_free (exit_code, format);
  exit (exit_code);
}


int getCharDeviceDescriptor (void)
{
  return fd;
}
