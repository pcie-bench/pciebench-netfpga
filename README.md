# PCIe Benchmark for 7 Series FPGAs of Xilinx

This project presents a **framework** that facilitates the evaluation and **measurement of PCIe features**. It is generic, and can be implemented on a number of different PCIe devices. It thus allows to compare different PCIe implementation with each others. The provided methodology has been developed
on both **commercial** (i.e., Xilinx Virtex-7 FPGA VC709 Connectivity Kit) **and research** (i.e.,NetFPGA SUME) oriented **boards**.

It is recommended that the user gets familiar with the [requisites](#section_requisites) of the workstation prior to any other task. Once that all the requirements are satisfied, some further [configuration](#section_configuration) of the system may be required. 

Additional sections are presented in this document in order to offer a guide for the generation of the [hardware project](#section_hw) and the usage of the [software](#section_sw). 




## <a name="section_requisites"></a>Requisites of the system

The design is limited to machines that verify:

* Owning a **PCIe Gen 3** slot with at least **8 lanes** available. 

  *Note: the design may not work properly if Gen3 or the 8 lanes cannot be negotiated.*



## <a name="section_configuration"></a>How to configure the system


* **Requisites for compiling a kernel module**. Some packages are required if you have not  compiled a module driver ever. That is to say, you will need to install the kernel headers and the compilation tools.
  * For Ubuntu:
  ```
  sudo apt-get install gcc make linux-headers-$(uname -r) #Ubuntu
  ```
  * For RHEL/CentOS/Oracle Linux:
  ```
  su -
  yum install gcc make kernel kernel-devel  #RHEL/CentOS
  ```

* The benchmark approach uses different types of **memory**:

  1. A buffer of **kernel pages**. The total amount of memory that can be alloced is, usually, limited to a few MiB.
  2. Alternatively, **huge pages** (pages of non-standard size) lead to tests which involve larger transferences. A greater performance and more stressful tasks can be prepared with this memory management option. They are plenty support in recent kernels and there is no need to recompile or build additional modules to the kernel. By default, 1 hugepage of size 1 GiB is used for the tests.
   
  In order to use huge pages, some **kernel parameters** have to be included. For this purpose:
  1. Edit the entries under grub:
  ```
  sudo gedit /etc/default/grub
  ```
  2. Find the line starting with *GRUB_CMDLINE_LINUX_DEFAULT*. We will configure 2 pages for this case (*Vivado might use some of the huge pages* so be careful with this detail):
  ```
  GRUB_CMDLINE_LINUX_DEFAULT="default_hugepagesz=1G hugepagesz=1G hugepages=2 ... previous options ..."
  ```
  3. Finally update GRUB's configuration file
  ```
  sudo update-grub
  ```


* **Vivado Suite**. If you need to rebuild the project, a valid license for the *7 Series Integrated Block for PCI Express (PCIe)* core IP of Xilinx is required. If this is your case you will also need to add *vivado* executable to your *PATH*. It is basically done with the following command:
  ```
  source /opt/Xilinx/Vivado/2014.4/settings64.sh
  ```
  where */opt/Xilinx/Vivado/2014.4* is the installation directory of the Xilinx packages.


## Hierarchy of the project

Two folders can be observed under the root of the git project:

* FPGA: All the related resources to the hardware design are available at this point.
  *  **FPGA/wizard.sh**: Assistant that lets the user generate the reference project automatically.
  *  FPGA/scripts: Scripts used by the wizard.sh script. They should not be of interest.
  *  FPGA/source: Constraints and sources for the project. Feel free to explore.

* HOST: Driver, middleware and user program. Each layer is contained under the path with the same name. That is to say: HOST/driver, HOST/middleware, HOST/user.
  * Additional documentation (doxygen-style) for the source files at software level is located under HOST/doc.
  * **HOST/Makefile**: The main makefile of the software sources. It will invoke inner makefiles.


## <a name="section_hw"></a>Building the hardware project

If your environment has been previously configured, you just need to clone the repo, "cd" to that path and follow the next steps:

```
cd FPGA
sh wizard.sh #Select your option (v for VC709, s for SUME). HUMAN ACTION is required for pushing the letter
#...
#Take a coffee
#...
sh wizard.sh # (w for generating the bitstream). HUMAN ACTION is required 
sh wizard.sh # (p for programming the board). HUMAN ACTION is required 
#Reboot your PC
```

--------

After this point, the bitstream should be available under 
```
FPGA/project/dmagen3/dmagen3.runs/impl_1
```
with the name of *pcie_benchmark.bit*.


**Note 1**: The wizard will ask for confirmation (options v,s) if it detects that a path actually exists. That is to say, imagine that you want create a project but the assistant detects that the paths *FPGA/project*, */tmp/pcie3_7x_0_example* or */tmp/tmp_project* are not empty. In that case the user will have to confirm that he/she wants to delete the correspondent folder.

**Note 2**: Confirmation will also be asked by the time that the user wants to **synthesize, implement and generate a new bitstream**. Notice that **any previous bitstream will be erased**.  

**Note 3**: PCIe devices are enumerated when the kernel boots. To the best of our knowledge, the unique way of **programming the FPGA** and detecting it as a new device is rebooting the PC after the FPGA is programmed. Do *not* shutdown the PC and start it again or the FPGA will loose the loaded bitstream, just a **reboot is required**.

### Subprojects

* */tmp/pcie3_7x_0_example* and */tmp/tmp_project*  are used with the finality of getting some sources from the **IP example design of Xilinx PCIe IP core**. If the path *FPGA/source/hdl/pcie_support/* counts with two files you can ommit the generation of this project whilst generating the IP cores (and Xilinx project) for your board (options v/s of wizard.sh).



### Disclaimer

This project was initially created for the suite *Vivado 2014.4* and it might not be compatible with other releases of the tool.

The possible inconveniences might be related to the dependencies of the project (3rd party core IPs). The developed HDL code should be flexible enough to be ported to other versions of the Xilinx tool without any further problems.


### Known issues while working with Vivado (distinct version of Vivado 2014.4)


* PCIe 7 Series FPGAs Integrated Block for PCI Express was updated in the newest versions of the tool.
  * For instance TREADY signals for RQ and CQ axi bus interfaces are now just 1 bit instead of the 22-bit initial width.
  * This limitation is bypassed by commenting the line 29 in pcie_ep_wrapper.sv
  ```
  `define VERSION_VIVADO_2014_4
  ```


## <a name="section_sw"></a>Software
###Compiling the software

It should be a straightforward activity, after cloning the repository you just need to execute the following commands:

  ```
  cd HOST
  make
  ```

###Output products

After compiling the software project,  the folder *HOST/bin* (automatically generated) will contain three files: 

1. *nfp_driver.ko*. The driver that communicates with the hardware
2. *rwBar*. A simple utility that lets the user to read/write to a specific region in any BAR of the FPGA. It requires a good knowledge of the design so do not use it unless you know what you are doing.
3. *benchmark* application. 

If you forget at any moment what are the arguments to any program, you can execute them without arguments in order to display the help.

####rwBar

Read/Write a 32b value to a specific position
```
▶ ./rwBar
You can use this program in the following ways:
· Indicating ONE read/write operation

Example of operation

· R 0 0x9000        -> It is translated into read a 32 bit word from the offset 0x9000 in the BAR0
· W 1 0x9000 0xFE0  -> It is translated into write the 32 bit word (0xFEO) to the offset 0x9000 in the BAR0
```

####benchmark

Basic tool to perform the benchmark. Under valid arguments, the program prints to the standard output the different fields under inspection separated by commas (so it is completely feasible to dump it directly to a .csv file ;-) ).

*Refer to the metodologhy of the PCIe benchmark in order to get some references for evaluating the performance.*

```
▶ ./benchmark
This program has several modes of usage:
· $benchmark -d <DIR> -p <PATTERN> [properties] -n <BYTES> -w <WINDOW_SIZE> -c <CACHE_OPTIONS> -l <NITERS>
  Where 
     <DIR> can be R/W/RW: 
      R represents memory write requests from the FPGA 
      W represents memory read requests from the FPGA 
      RW represents a memory write request from the FPGA follow by a memory read request
     <PATTERN> can be FIX/SEQ/OFF/RAN for same address,sequential, fixed offset and random tests 
      - FIX <offset> 
      - OFF <offset> <unit size>  
      - RAN <offset> <window size (multiple of system PAGE_SIZE)>  
     <BYTES> is a value greater than 0 (necessarily a multiple of 4). Number of bytes per descriptor
     <WINDOW_SIZE> total tags that can be asked simultaneously in memory reads. Min 1, Max 32 
     <CACHE_OPTIONS> are: 
      - ignore: Do nothing  
      - discard: Access in a random way before using the buffer  
      - warm: Preload in the cache the buffer before accessing to it 
     <NITERS> is the number of iterations of the experiment
```

It is recommendable that you restart the design prior to any measurement. It means, that the recommended way of executing the program is:

```
cd HOST
sh restart.sh; sh bin/benchmark [OPTIONS]
```

Some examples:
* Test PCIe 1. Transfer 512 MiB to the FPGA from the HOST
  ```
  sh restart.sh; sh bin/benchmark -d W -p FIX 0 -n 512m -l 1
  ```
* Test PCIe 2. Transfer 512 MiB to the FPGA from the HOST: repeat it 1000 times:
  ```
  sh restart.sh; sh bin/benchmark -d W -p FIX 0 -n 512m -l 1000
  ```
* Test PCIe 3. Transfer 512 MiB from the FPGA to the HOST. Then read back from the HOST to the FPGA: repeat it 1000 times:
  ```
  sh restart.sh; sh bin/benchmark -d RW -p FIX 0 -n 512m -l 1000
  ```
* Test PCIe 4. Transfer 8B from the FPGA to the HOST to random positions inside a buffer of 512MiB
  ```
  sh restart.sh; sh bin/benchmark -d RW -p RAN 0 512m -n 8 -l 1
  ```
* Test PCIe 5. Transfer 8B from the FPGA to the HOST to random positions inside a buffer of 512MiB (which is unaligned by 28 bytes)
  ```
  sh restart.sh; sh bin/benchmark -d RW -p RAN 28 512m -n 8 -l 1
  ```
Feel free to explore other options! 
