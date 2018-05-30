cmake_minimum_required (VERSION 2.8.11)
project (pciebenchmark)

option(VERBOSE_APP "Show the output of the Vivado commands that are executed by the Makefile" off)
set(fpga  "netfpga") # netfpga / vcu709

INCLUDE(constants.cmake)

set(CMAKE_HOST_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/HOST)

check_for_program(vivado)
check_vivado_version("2014.4 2017.4")


add_subdirectory (FPGA)

add_custom_command(
    OUTPUT ${CMAKE_HOST_DIRECTORY}/bin/nfp_driver
    COMMAND make driver
    WORKING_DIRECTORY ${CMAKE_HOST_DIRECTORY}
    COMMENT "Compiling the driver"    
)
add_custom_command(
    OUTPUT  ${CMAKE_HOST_DIRECTORY}/bin/benchmark
    COMMAND make benchmark
    WORKING_DIRECTORY ${CMAKE_HOST_DIRECTORY}
    COMMENT "Compiling the SW: benchmarking utility"    
)
add_custom_command(
    OUTPUT  ${CMAKE_HOST_DIRECTORY}/bin/rwBar
    COMMAND make rwBar
    WORKING_DIRECTORY ${CMAKE_HOST_DIRECTORY}
    COMMENT "Compiling the SW: R/W register utility"    
)
add_custom_target (driver DEPENDS ${CMAKE_HOST_DIRECTORY}/bin/nfp_driver)
add_custom_target (benchmark DEPENDS ${CMAKE_HOST_DIRECTORY}/bin/rwBar ${CMAKE_HOST_DIRECTORY}/bin/benchmark)
add_custom_target (sw ALL DEPENDS driver benchmark)

