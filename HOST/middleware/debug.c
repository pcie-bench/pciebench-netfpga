/**
* @file debug.c
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
*
* @brief Implementation of internal functions of debug manage by the middleware layer.
* @author José Fernando Zazo Rollón, josefernando.zazo@estudiante.uam.es
* @date 2014-05-23
*/
#include "debug.h"


/**
* @brief Variable of type struct rte_logs internal to the module.
*/
struct rte_logs rte_logs = {
  .file = NULL        /**< The file identificator (FILE *) */
};

int rte_openlog_stream (FILE *f)
{
  rte_logs.file = f;
  return 0;
}


FILE *rte_actuallog_stream (void)
{
  return rte_logs.file;
}


/*
 * Generate a log message. The message will be sent in the stream
 * defined by the previous call to rte_openlog_stream().
 */
int rte_vlog (__attribute__ ( (unused)) uint32_t level,
              __attribute__ ( (unused)) uint32_t logtype,
              const char *format, va_list ap)
{
  int ret;
  FILE *f = rte_logs.file;
  ret = vfprintf (f, format, ap);
  fflush (f);
  return ret;
}

