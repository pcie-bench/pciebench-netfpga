/**
* @file debug.h
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
* @brief Declaration of internal functions of debug manage by the middleware layer.
* @author José Fernando Zazo Rollón, josefernando.zazo@estudiante.uam.es
* @date 2014-05-23
*/
#ifndef _DEBUG_H_
#define _DEBUG_H_

#include <stdio.h>
#include <stdarg.h>
#include <stdint.h>


/**
* @brief The structure that describes a log
*/
struct rte_logs {
  FILE *file;     /**< Pointer to current FILE* for logs. */
};


/**
* @brief Change the stream that will be used by logging system
*
* @param f The new file where the logs will be stored.
*
* @return The possible error code.
*/
int rte_openlog_stream (FILE *f);

/**
* @brief Get the actual stream.
*
* @return A FILE* to the actual log file.
*/
FILE *rte_actuallog_stream (void);

/**
* @brief Prints a message with different levels of priority.
*
* @param level Currently ignored (hold by intel dpdk similarity).
* @param logtype Currently ignored (hold by intel dpdk similarity).
* @param format The string format that will be displayed to the user through the log file
* @param ap The possible format dependences.
*
* @return 0 if success.
*/
int rte_vlog (uint32_t level,
              uint32_t logtype,
              const char *format,
              va_list ap);


#endif
