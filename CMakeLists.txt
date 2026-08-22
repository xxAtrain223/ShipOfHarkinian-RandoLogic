cmake_minimum_required(VERSION 3.26 FATAL_ERROR)

project(
    ShipOfHarkinianRandoLogic
    VERSION 1.0.0
    LANGUAGES NONE
)

set(
    RLS_LOGIC_OUTPUT_DIR
    "${CMAKE_CURRENT_SOURCE_DIR}/generated/soh"
    CACHE PATH
    "Directory where RLS writes Shipwright C++ sources"
)

include("${CMAKE_CURRENT_SOURCE_DIR}/cmake/RandoLogic.cmake")

rls_add_logic_generation(
    LOGIC_DIR
        "${CMAKE_CURRENT_SOURCE_DIR}"

    COMPILER_DIR
        "${CMAKE_CURRENT_SOURCE_DIR}/RandoLogicScript"

    OUTPUT_DIR
        "${RLS_LOGIC_OUTPUT_DIR}"

    TRANSPILER
        "soh"

    TARGET_PREFIX
        "soh-rls"
)

# Make generation part of a normal standalone build.
add_custom_target(
    generate-rando-logic ALL
    DEPENDS "${RLS_GENERATION_TARGET}"
)

message(STATUS "RLS compiler source: ${CMAKE_CURRENT_SOURCE_DIR}/RandoLogicScript")
message(STATUS "RLS logic project:  ${CMAKE_CURRENT_SOURCE_DIR}")
message(STATUS "RLS generated code: ${RLS_GENERATED_DIR}")