/**
@class dma_rq_d2h_splitter

@author      Jose Fernando Zazo Rollon (josefernando.zazo@estudiante.uam.es)
@date        05/11/2015

@brief This design just split the information into chunks when a TLAST is detected or a timeout is reached

 Copyright (c) 2016
 All rights reserved.

 as part of the DARPA MRC research programme.

 @NETFPGA_LICENSE_HEADER_START@

 Licensed to NetFPGA C.I.C. (NetFPGA) under one or more contributor
 license agreements.  See the NOTICE file distributed with this work for
 additional information regarding copyright ownership.  NetFPGA licenses this
 file to you under the NetFPGA Hardware-Software License, Version 1.0 (the
 "License"); you may not use this file except in compliance with the
 License.  You may obtain a copy of the License at:

   http://www.netfpga-cic.org

 Unless required by applicable law or agreed to in writing, Work distributed
 under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
 CONDITIONS OF ANY KIND, either express or implied.  See the License for the
 specific language governing permissions and limitations under the License.

 @NETFPGA_LICENSE_HEADER_END@


*/

`timescale  1ns/1ns


/*
NOTATION: some compromises have been adopted.

INPUTS/OUTPUTS   to the module are expressed in capital letters.
INPUTS CONSTANTS to the module are expressed in capital letters.
STATES of a FMS  are expressed in capital letters.

Other values are in lower letters.


A register will be written as name_of_register"_r" (except registers associated to states)
A signal will be written as   name_of_register"_s"

Every constante will be preceded by "c_"name_of_the_constant


In this particular module
mem_wr_* references a memory write request signal
mem_rd_* references a memory read request signal

*/


module dma_rq_d2h_splitter #(
  parameter C_MODULE_IN_USE                = 1  ,
  parameter C_BUS_DATA_WIDTH               = 256,
  parameter                                           C_BUS_KEEP_WIDTH = (C_BUS_DATA_WIDTH/8),
  parameter C_MAX_SIMULTANEOUS_DESCRIPTORS = 2  ,
  parameter C_LOG2_MAX_PAYLOAD             = 8    // 2**C_LOG2_MAX_PAYLOAD in bytes
) (
  input  wire                        CLK                      ,
  input  wire                        RST_N                    ,
  ////////////
  //  c2s fifo interface: 1 AXI-Stream (data to be transferred in memory write requests)
  ////////////
  output wire                        C2S_FIFO_TREADY          ,
  input  wire [C_BUS_DATA_WIDTH-1:0] C2S_FIFO_TDATA           ,
  input  wire                        C2S_FIFO_TLAST           ,
  input  wire                        C2S_FIFO_TVALID          ,
  input  wire [C_BUS_KEEP_WIDTH-1:0] C2S_FIFO_TKEEP           ,
  ////////////
  //  Divided data: 1 AXI-Stream (data to be transferred in memory write requests). The descriptor has been corrected with the appropiate value
  //  if a TLAST has been detected.
  ////////////
  input  wire                        C2S_PROC_TREADY          ,
  output wire [C_BUS_DATA_WIDTH-1:0] C2S_PROC_TDATA           ,
  output wire                        C2S_PROC_TLAST           ,
  output wire                        C2S_PROC_TVALID          ,
  output wire [C_BUS_KEEP_WIDTH-1:0] C2S_PROC_TKEEP           ,
  ////////////
  //  Descriptor interface: Interface with the necessary data to complete a memory read/write request.
  ////////////
  input  wire [                15:0] ENGINE_STATE             ,
  input  wire [                15:0] C2S_STATE                ,
  input  wire [                63:0] CURRENT_DESCRIPTOR_SIZE  ,
  input  wire [                63:0] DESCRIPTOR_MAX_TIMEOUT   ,
  output wire                        HW_REQUEST_TRANSFERENCE  ,
  output wire [                63:0] HW_NEW_SIZE_AT_DESCRIPTOR
);

  assign C2S_FIFO_TREADY = C2S_PROC_TREADY;
  assign C2S_PROC_TDATA  = C2S_FIFO_TDATA;
  assign C2S_PROC_TLAST  = C2S_FIFO_TLAST;
  assign C2S_PROC_TVALID = C2S_FIFO_TVALID;
  assign C2S_PROC_TKEEP  = C2S_FIFO_TKEEP;


  assign HW_REQUEST_TRANSFERENCE   = 1'b0;
  assign HW_NEW_SIZE_AT_DESCRIPTOR = 64'h0;

endmodule