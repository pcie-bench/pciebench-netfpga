#
# Copyright (c) 2016
# All rights reserved.
#
#
# @NETFPGA_LICENSE_HEADER_START@
#
# Licensed to NetFPGA C.I.C. (NetFPGA) under one or more contributor
# license agreements.  See the NOTICE file distributed with this work for
# additional information regarding copyright ownership.  NetFPGA licenses this
# file to you under the NetFPGA Hardware-Software License, Version 1.0 (the
# "License"); you may not use this file except in compliance with the
# License.  You may obtain a copy of the License at:
#
#   http://www.netfpga-cic.org
#
# Unless required by applicable law or agreed to in writing, Work distributed
# under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
# CONDITIONS OF ANY KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations under the License.
#
# @NETFPGA_LICENSE_HEADER_END@
#

CC=gcc
CPLUS=g++

# The list of the executables that will be generated.

EXEC1=rwBar
EXEC3=benchmark



ARCHIVE_PREFIX=nfp_driver
ARCHIVE_SUFFIX=$(shell date "+%Y_%m_%d")
ARCHIVE=$(ARCHIVE_PREFIX)-$(ARCHIVE_SUFFIX)

#Use _GNU_SOURCE for O_DIRECT flag
CXXFLAGS += -Wall -pthread   -D_GNU_SOURCE  -g
COPTFLAGS =  # -O3

SRC = middleware/init.c middleware/debug.c middleware/huge_page.c middleware/transfer.c  #List of all .c of the user example.
INC = middleware/init.h middleware/debug.h  middleware/huge_page.h middleware/transfer.h  #List of all .h
OBJ = $(SRC:.c=.o)

SRC1 = user/rwBar/rwBar.c
OBJ1 = $(SRC1:.c=.o)
LINKER_FLAGS1= -o ./bin/$(EXEC1) -lm
DRIVER_PATH=middleware

SRC3 = user/benchmark/benchmark.c
OBJ3 = $(SRC3:.c=.o)
LINKER_FLAGS3= -o ./bin/$(EXEC3) -lm

all: rwBar benchmark driver

.PHONY: create_bin


create_bin:
	@mkdir -p bin

rwBar: create_bin $(OBJ1)  $(OBJ)  Makefile
	$(CC) $(CFLAGS) $(OBJ1)  $(OBJ) $(LINKER_FLAGS1)	

benchmark: create_bin $(OBJ3)  $(OBJ)  Makefile
	$(CC) $(CFLAGS) $(OBJ3)  $(OBJ) $(LINKER_FLAGS3)	


$(OBJ): %.o : %.c $(INC) 
	$(CC) -c $(CXXFLAGS) $< -o $@


$(OBJ1): %.o : %.c $(INC) 
	$(CC) -c $(CXXFLAGS) $(COPTFLAGS)  -I$(DRIVER_PATH) $< -o $@

$(OBJ2): %.o : %.c $(INC) 
	$(CC) -c $(CXXFLAGS) $(COPTFLAGS)  -I$(DRIVER_PATH) $< -o $@

$(OBJ3): %.o : %.c $(INC) 
	$(CC) -c $(CXXFLAGS) $(COPTFLAGS)  -I$(DRIVER_PATH) $< -o $@

.PHONY: driver

driver: create_bin
	@cd driver; make; mv *.ko ../bin/

.PHONY: doc

doc: 
	@cd doc; doxygen Doxyfile_user
	@cd doc; doxygen Doxyfile_middleware
	@cd doc; doxygen Doxyfile_driver

clean:
	@cd driver; make clean
	@rm -rf user/*.o user/rwBar/*.o user/benchmark/*.o user/rwDma/*.o middleware/*.o ./bin
	@rm -f *~ */*~
	@find . -name '$(ARCHIVE_PREFIX)*' -exec rm -rf '{}' ';'

realclean: clean
	@find ./doc/* -maxdepth 0 -name 'Doxyfile*' -prune -o -exec rm -rf '{}' ';' #Delete everything except doxyfile


dist: realclean
	@zip -r $(ARCHIVE).zip .


.PHONY: help

help:
	@echo "-------------------------------------------------------------------------------------------------"
	@echo "This makefile supports the following options:"
	@echo "-------------------------------------------------------------------------------------------------"
	@echo "     + make all: Generates user and driver design under the bin path."
	@echo "     + make clean: Removes user and driver design."
	@echo "     + make doc: Generates doxygen documentation under the doc path."
	@echo "     + make realclean: Removes everything: user and driver design plus the doxygen documentation."
	@echo "     + make dist: Creates a .zip file with the current directory files."
	@echo "--------------------------------------------------------------------------Jose Fernando Zazo ----"
