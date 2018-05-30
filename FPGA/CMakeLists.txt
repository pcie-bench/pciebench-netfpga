if(${vivado_installed_version} STREQUAL "2017.4")
    adjust_command_verbosity(bash -c "bash scripts/create_pcie_ref_project_2017_4.sh")
elseif(${vivado_installed_version} STREQUAL "2014.4")
    adjust_command_verbosity(bash -c "bash scripts/create_pcie_ref_project_2014_4.sh")
else()
    adjust_command_verbosity(false)
endif()
add_custom_command(
        OUTPUT ${CMAKE_CURRENT_SOURCE_DIR}/source/hdl/pcie_support/xilinx_pcie_3_0_7vx_ep.v
        COMMAND ${conditional_command}
        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
        COMMENT "Generating Xilinx files (Vivado ${vivado_installed_version})"    
)
add_custom_target (xlnx_files DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/source/hdl/pcie_support/xilinx_pcie_3_0_7vx_ep.v)



if(${fpga} STREQUAL "netfpga")
    adjust_command_verbosity(bash -c "bash scripts/build_project_sume.sh; bash clean.sh")
elseif(${fpga} STREQUAL "vc709")
    adjust_command_verbosity(bash -c "bash scripts/build_project_vc709.sh; bash clean.sh")
else()
    adjust_command_verbosity(false)
endif()
add_custom_command(
    OUTPUT  ${CMAKE_CURRENT_SOURCE_DIR}/project/.cmake_${fpga}
    COMMAND ${conditional_command}
    COMMAND bash -c "touch ${CMAKE_CURRENT_SOURCE_DIR}/project/.cmake_${fpga}"
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    DEPENDS xlnx_files
    COMMENT "Generating IP core files and project for ${fpga}"    
)
add_custom_target (project ALL DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/project/.cmake_${fpga})


if(${vivado_installed_version} STREQUAL "2017.4")
    adjust_command_verbosity(bash -c "bash scripts/configure_vivado_2017_4.sh ${CMAKE_CURRENT_SOURCE_DIR}/source/hdl/pcie_ep_wrapper.sv")
elseif(${vivado_installed_version} STREQUAL "2014.4")
    adjust_command_verbosity(bash -c "bash scripts/configure_vivado_2014_4.sh ${CMAKE_CURRENT_SOURCE_DIR}/source/hdl/pcie_ep_wrapper.sv")
endif()
add_custom_target (vivado_version_adaptation
    ALL 
    COMMAND ${conditional_command}
    DEPENDS project
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    COMMENT "Customizing source files to Vivado ${vivado_installed_version}"    
)



adjust_command_verbosity(bash -c "bash scripts/implement_design.sh; bash clean.sh")
add_custom_command(
    OUTPUT  ${CMAKE_CURRENT_SOURCE_DIR}/project/dmagen3/dmagen3.runs/impl_1/pcie_benchmark.bit
    COMMAND ${conditional_command}
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    DEPENDS vivado_version_adaptation
    COMMENT "Generating bitstream for ${fpga}"    
)
add_custom_target (implement ALL DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/project/dmagen3/dmagen3.runs/impl_1/pcie_benchmark.bit)

adjust_command_verbosity(bash -c "bash scripts/program_fpga.sh; bash clean.sh")
add_custom_target (
    program 
    DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/project/dmagen3/dmagen3.runs/impl_1/pcie_benchmark.bit
    COMMAND ${conditional_command}
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
)


add_custom_target (fpga DEPENDS implement)