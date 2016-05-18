/**
* @file rwBar.c
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
* @brief Utility that lets the user to read/write 32-bit registers from the FPGA
* @author José Fernando Zazo Rollón, josefernando.zazo@estudiante.uam.es
* @date 2016-02-05
*/

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <unistd.h>
#include <string.h>
#include <ctype.h>

#include "nfp_common.h"




enum DIRECTION {TO_CARD, FROM_CARD};

struct memory_op {
  enum DIRECTION   dir;
  uint32_t         val;
  uint32_t         offset;
  char             bar;
};

struct arguments {
  struct memory_op op;
};

/**
* @brief Explanation about how to run the program.
*/
void printUsage()
{
  printf("You can use this program in the following ways:\n"
         "· Indicating ONE read/write operation\n"
         "\nExample of operation\n\n"
         "· R 0 0x9000        -> It is translated into read a 32 bit word from the offset 0x9000 in the BAR0\n"
         "· W 1 0x9000 0xFE0  -> It is translated into write the 32 bit word (0xFEO) to the offset 0x9000 in the BAR0\n"
        );
}

/*
 This function can parse a string to an unsigned integer. Supported formats are:
  12345678    : Number in base 10.
  0x12345678  : Number in base 16.
  x12345678   : Number in base 16. Omit the initial 0 .
  0x1234_5678 : Number in base 16. In order to avoid errors, '-' or '_' can be used as separators
  x1234_5678  : Number in base 16. In order to avoid errors, '-' or '_' can be used as separators
  0x1234-5678 : Number in base 16. In order to avoid errors, '-' or '_' can be used as separators
  x1234-5678  : Number in base 16. In order to avoid errors, '-' or '_' can be used as separators
*/
static uint32_t etoi(char* string)   // 'Everything to int'
{
  int length;
  int i;
  char *value;
  char next_condition = 0;

  if ((value = strchr(string, 'x')) || (value = strchr(string, 'X'))) {
    value++;
    if ((value - string) > 2) { // 213123x3342342 -> Invalid number. Support 0x1234 or x1234
      return -1;
    }
    if (value - string == 2 && string[0] != '0') { // 2x34243
      return -1;
    }
    length =  strlen(value);
    // Check for a number of the style 0x12345678...90
    for (i = 0; i < length; i++) {
      switch (value[i]) {
      case '0':
      case '1':
      case '2':
      case '3':
      case '4':
      case '5':
      case '6':
      case '7':
      case '8':
      case '9':
      case 'a': case 'A':
      case 'b': case 'B':
      case 'c': case 'C':
      case 'd': case 'D':
      case 'e': case 'E':
      case 'f': case 'F': break;
      default: next_condition = 1;
      }
      if (next_condition) {
        break;
      }
      if (i == length - 1) {
        return strtol(value, NULL, 16);
      }
    }
    // Check for a number of the style 0x1234_5678_...90
    uint32_t cdword  = 0;
    uint32_t tdword  = 0;
    uint32_t multp  = 1;
    uint32_t multd  = 1;
    char cnt, cchar;
    for (i = length - 1; i >= 0; i--) {

      if (cnt % 4 == 0 && cnt != 0) {
        if (value[i] != '_' && value[i] != '-') {
          break;
        }
        tdword += multd * cdword;
        multd *= (65536); // 16**4
        multp = 1;
        cdword = 0;
        cnt = 0;
      } else {
        cnt++;
        switch (value[i]) {
        case '0': cchar = 0;  break;
        case '1': cchar = 1;  break;
        case '2': cchar = 2;  break;
        case '3': cchar = 3;  break;
        case '4': cchar = 4;  break;
        case '5': cchar = 5;  break;
        case '6': cchar = 6;  break;
        case '7': cchar = 7;  break;
        case '8': cchar = 8;  break;
        case '9': cchar = 9;  break;
        case 'a': case 'A':  cchar = 10;  break;
        case 'b': case 'B':  cchar = 11;  break;
        case 'c': case 'C':  cchar = 12;  break;
        case 'd': case 'D':  cchar = 13;  break;
        case 'e': case 'E':  cchar = 14;  break;
        case 'f': case 'F':  cchar = 15;  break;
        default: return -1;
        }
        cdword += cchar * multp;
        multp *= 16;
      }
      if (i == 0) {
        return tdword + multd * cdword;
      }
    }
  } else {
    length = strlen(string);
    // Check for an integer. Contemplate things such as 123213a34
    for (i = 0; i < length; i++) {
      if (!isdigit(string[i])) {
        return -1;
      }
    }
    return atoi(string);
  }

  return -1;
}
static int readArguments(int argc, char **argv, struct arguments *arg )
{

  if (argc != 2 && argc != 4 && argc != 5) {
    return -1;
  }

  memset(arg, 0, sizeof(struct arguments));
  char op = argv[1][0];

  if (op == 'R' || op == 'r') {
    arg->op.dir = FROM_CARD;
  } else if (op == 'W' || op == 'w') {
    if (argc != 5) {
      return -1;
    }
    arg->op.dir = TO_CARD;
    arg->op.val = etoi(argv[4]);
  } else {
    return -1;
  }

  arg->op.bar = etoi(argv[2]);
  arg->op.offset = etoi(argv[3]);

  return 0;
}


int main(int argc, char **argv)
{
  struct  arguments args;
  int ret;

  if ( (ret = readArguments(argc, argv, &args)) ) {
    printUsage();
    return 0;
  }

  if ( rte_eal_init(argc, argv) != 0) {
    printf(  "No target found\n" );
    return -1;
  }

  if ( args.op.dir == FROM_CARD ) {
    printf("%08X\n", readWord (args.op.bar, args.op.offset));
  } else {
    writeWord (args.op.bar, args.op.offset, args.op.val);
  }

  rte_exit(0, "Operation complete\n");

  return 0; // Ignore compiler warnings
}

