include_guard(GLOBAL)

include(ExternalProject)
include(CMakeParseArguments)

# Creates:
#
#   <TARGET_PREFIX>-compiler
#       Builds the nested RandoLogicScript compiler.
#
#   <TARGET_PREFIX>-generate
#       Generates the requested transpiler output.
#
# The following variables are exported to the caller:
#
#   RLS_GENERATION_TARGET
#   RLS_COMPILER_TARGET
#   RLS_GENERATED_DIR
#   RLS_GENERATED_SOURCES
#   RLS_GENERATED_HEADERS
#   RLS_GENERATED_FILES
#
# Example:
#
#   rls_add_logic_generation(
#       LOGIC_DIR      "${CMAKE_CURRENT_SOURCE_DIR}"
#       COMPILER_DIR   "${CMAKE_CURRENT_SOURCE_DIR}/RandoLogicScript"
#       OUTPUT_DIR     "${CMAKE_CURRENT_SOURCE_DIR}/generated/soh"
#       TRANSPILER     "soh"
#       TARGET_PREFIX  "soh-rls"
#   )
#
function(rls_add_logic_generation)
    set(options)
    set(one_value_args
        LOGIC_DIR
        COMPILER_DIR
        OUTPUT_DIR
        TRANSPILER
        TARGET_PREFIX
    )
    set(multi_value_args)

    cmake_parse_arguments(
        RLS
        "${options}"
        "${one_value_args}"
        "${multi_value_args}"
        ${ARGN}
    )

    if(NOT RLS_LOGIC_DIR)
        message(FATAL_ERROR
            "rls_add_logic_generation requires LOGIC_DIR"
        )
    endif()

    if(NOT RLS_COMPILER_DIR)
        message(FATAL_ERROR
            "rls_add_logic_generation requires COMPILER_DIR"
        )
    endif()

    if(NOT RLS_OUTPUT_DIR)
        message(FATAL_ERROR
            "rls_add_logic_generation requires OUTPUT_DIR"
        )
    endif()

    if(NOT RLS_TRANSPILER)
        set(RLS_TRANSPILER "soh")
    endif()

    if(NOT RLS_TARGET_PREFIX)
        set(RLS_TARGET_PREFIX "rls")
    endif()

    get_filename_component(
        RLS_LOGIC_DIR
        "${RLS_LOGIC_DIR}"
        ABSOLUTE
    )

    get_filename_component(
        RLS_COMPILER_DIR
        "${RLS_COMPILER_DIR}"
        ABSOLUTE
    )

    get_filename_component(
        RLS_OUTPUT_DIR
        "${RLS_OUTPUT_DIR}"
        ABSOLUTE
    )

    set(RLS_MANIFEST "${RLS_LOGIC_DIR}/rls.json")

    if(NOT EXISTS "${RLS_MANIFEST}")
        message(FATAL_ERROR
            "RLS manifest was not found:\n"
            "  ${RLS_MANIFEST}\n"
            "\n"
            "If this is a Shipwright checkout, initialize its submodules with:\n"
            "  git submodule update --init --recursive"
        )
    endif()

    if(NOT EXISTS "${RLS_COMPILER_DIR}/CMakeLists.txt")
        message(FATAL_ERROR
            "The RandoLogicScript compiler submodule was not found:\n"
            "  ${RLS_COMPILER_DIR}\n"
            "\n"
            "Initialize nested submodules with:\n"
            "  git submodule update --init --recursive"
        )
    endif()

    set(
        RLS_COMPILER_TARGET
        "${RLS_TARGET_PREFIX}-compiler"
    )

    set(
        RLS_GENERATION_TARGET
        "${RLS_TARGET_PREFIX}-generate"
    )

    # Keep the compiler build isolated from the Shipwright target graph.
    # RLS currently defines generic target names such as "soh", so including
    # it with add_subdirectory() would conflict with Shipwright's executable.
    set(
        RLS_COMPILER_BUILD_DIR
        "${CMAKE_BINARY_DIR}/${RLS_TARGET_PREFIX}-compiler"
    )

    # Build the compiler in Release regardless of Shipwright's current
    # configuration. The compiler is a build-time host tool, not part of the
    # shipped application.
    ExternalProject_Add(
        "${RLS_COMPILER_TARGET}"

        SOURCE_DIR
            "${RLS_COMPILER_DIR}"

        BINARY_DIR
            "${RLS_COMPILER_BUILD_DIR}"

        CMAKE_ARGS
            "-DBUILD_TESTING=OFF"
            "-DRLS_STATIC_MSVC_RUNTIME=ON"
            "-DCMAKE_BUILD_TYPE=Release"

        BUILD_COMMAND
            "${CMAKE_COMMAND}"
            --build <BINARY_DIR>
            --config Release
            --target RandoLogicScript

        INSTALL_COMMAND
            ""

        # Invoke the native build tool whenever the compiler target is needed.
        # The native build system remains incremental, so unchanged RLS
        # compiler sources are not recompiled.
        BUILD_ALWAYS
            TRUE

        CONFIGURE_HANDLED_BY_BUILD
            TRUE

        EXCLUDE_FROM_ALL
            TRUE

        USES_TERMINAL_CONFIGURE
            TRUE

        USES_TERMINAL_BUILD
            TRUE
    )

    # RLS places the executable under console/. Multi-configuration
    # generators add the selected configuration as another directory.
    if(CMAKE_CONFIGURATION_TYPES)
        set(
            RLS_COMPILER_EXECUTABLE
            "${RLS_COMPILER_BUILD_DIR}/console/Release/RandoLogicScript${CMAKE_EXECUTABLE_SUFFIX}"
        )
    else()
        set(
            RLS_COMPILER_EXECUTABLE
            "${RLS_COMPILER_BUILD_DIR}/console/RandoLogicScript${CMAKE_EXECUTABLE_SUFFIX}"
        )
    endif()

    # CONFIGURE_DEPENDS makes CMake reconfigure if a new logic file is added.
    file(
        GLOB_RECURSE
        RLS_LOGIC_INPUTS
        CONFIGURE_DEPENDS
        LIST_DIRECTORIES FALSE

        "${RLS_LOGIC_DIR}/src/*.rls"
        "${RLS_LOGIC_DIR}/stdlib/*.rls"
        "${RLS_LOGIC_DIR}/*.rls"
    )

    list(APPEND RLS_LOGIC_INPUTS "${RLS_MANIFEST}")

    # Track compiler implementation changes. Existing files become normal
    # build dependencies, and CONFIGURE_DEPENDS detects newly added files.
    file(
        GLOB_RECURSE
        RLS_COMPILER_INPUTS
        CONFIGURE_DEPENDS
        LIST_DIRECTORIES FALSE

        "${RLS_COMPILER_DIR}/CMakeLists.txt"
        "${RLS_COMPILER_DIR}/*.cmake"
        "${RLS_COMPILER_DIR}/*.cpp"
        "${RLS_COMPILER_DIR}/*.cc"
        "${RLS_COMPILER_DIR}/*.c"
        "${RLS_COMPILER_DIR}/*.h"
        "${RLS_COMPILER_DIR}/*.hpp"
        "${RLS_COMPILER_DIR}/*.in"
        "${RLS_COMPILER_DIR}/*.json"
    )

    if(RLS_TRANSPILER STREQUAL "soh")
        set(
            RLS_GENERATED_HEADERS
            "${RLS_OUTPUT_DIR}/rls_match.h"
            "${RLS_OUTPUT_DIR}/functions.gen.h"
            "${RLS_OUTPUT_DIR}/regions.gen.h"
        )

        set(
            RLS_GENERATED_SOURCES
            "${RLS_OUTPUT_DIR}/functions.gen.cpp"
            "${RLS_OUTPUT_DIR}/regions.gen.cpp"
        )
    else()
        message(FATAL_ERROR
            "RandoLogic.cmake does not yet have a declared output list for "
            "the '${RLS_TRANSPILER}' transpiler."
        )
    endif()

    set(
        RLS_GENERATED_FILES
        ${RLS_GENERATED_HEADERS}
        ${RLS_GENERATED_SOURCES}
    )

    add_custom_command(
        OUTPUT
            ${RLS_GENERATED_FILES}

        COMMAND
            "${CMAKE_COMMAND}" -E make_directory "${RLS_OUTPUT_DIR}"

        COMMAND
            "${RLS_COMPILER_EXECUTABLE}"
            --project "${RLS_MANIFEST}"
            --transpiler "${RLS_TRANSPILER}"
            --output "${RLS_OUTPUT_DIR}"

        DEPENDS
            "${RLS_COMPILER_TARGET}"
            ${RLS_LOGIC_INPUTS}
            ${RLS_COMPILER_INPUTS}

        WORKING_DIRECTORY
            "${RLS_LOGIC_DIR}"

        COMMENT
            "Generating ${RLS_TRANSPILER} randomizer logic with RandoLogicScript"

        COMMAND_EXPAND_LISTS
        VERBATIM
    )

    add_custom_target(
        "${RLS_GENERATION_TARGET}"
        DEPENDS ${RLS_GENERATED_FILES}
    )

    set_source_files_properties(
        ${RLS_GENERATED_FILES}
        PROPERTIES GENERATED TRUE
    )

    source_group(
        "Generated Files\\RandoLogicScript"
        FILES ${RLS_GENERATED_FILES}
    )

    set(
        RLS_GENERATION_TARGET
        "${RLS_GENERATION_TARGET}"
        PARENT_SCOPE
    )

    set(
        RLS_COMPILER_TARGET
        "${RLS_COMPILER_TARGET}"
        PARENT_SCOPE
    )

    set(
        RLS_COMPILER_EXECUTABLE
        "${RLS_COMPILER_EXECUTABLE}"
        PARENT_SCOPE
    )

    set(
        RLS_GENERATED_DIR
        "${RLS_OUTPUT_DIR}"
        PARENT_SCOPE
    )

    set(
        RLS_GENERATED_SOURCES
        "${RLS_GENERATED_SOURCES}"
        PARENT_SCOPE
    )

    set(
        RLS_GENERATED_HEADERS
        "${RLS_GENERATED_HEADERS}"
        PARENT_SCOPE
    )

    set(
        RLS_GENERATED_FILES
        "${RLS_GENERATED_FILES}"
        PARENT_SCOPE
    )
endfunction()