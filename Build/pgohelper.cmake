#!/usr/bin/cmake -P
# cmake -P Build/pgohelper.cmake $PWD/Build $PWD/objective-2-fast::$PWD/objective-1-fast $PWD/Bin/Release/SvtAv1EncApp

# The positional arguments are read relative to the "-P" marker on the command
# line so that extra options passed before "-P" (e.g. -DTCPU=...) do not shift
# their indexes.
set(PGO_P_INDEX -1)
foreach(i RANGE 0 ${CMAKE_ARGC})
    set(PGO_ARG "CMAKE_ARGV${i}")
    if(DEFINED ${PGO_ARG} AND "${${PGO_ARG}}" STREQUAL "-P")
        set(PGO_P_INDEX ${i})
    endif()
endforeach()

math(EXPR PGO_BUILD_INDEX "${PGO_P_INDEX} + 2")
math(EXPR PGO_VIDEO_INDEX "${PGO_P_INDEX} + 3")
math(EXPR PGO_APP_INDEX "${PGO_P_INDEX} + 4")

if(NOT PGO_P_INDEX GREATER -1 OR NOT CMAKE_ARGC GREATER PGO_APP_INDEX)
    message(
        FATAL_ERROR
            "Usage: cmake [options] -P pgohelper.cmake build_dir /path/to/videofiles::additional_paths /path/to/SvtAv1EncApp"
    )
endif()

set(BUILD_DIRECTORY "${CMAKE_ARGV${PGO_BUILD_INDEX}}")
set(VIDEO_DIRECTORY "${CMAKE_ARGV${PGO_VIDEO_INDEX}}")
set(SvtAv1EncApp "${CMAKE_ARGV${PGO_APP_INDEX}}")

if(NOT EXISTS ${SvtAv1EncApp})
    message(
        FATAL_ERROR
            "Can't run pgo if the binaries don't exist. Looked at ${SvtAv1EncApp}"
    )
endif()

# Delete any existing Clang profiling data.

file(GLOB OLD_FILES
    "${BUILD_DIRECTORY}/*.profraw"
    "${BUILD_DIRECTORY}/*.profdata"
)
if(OLD_FILES)
    file(REMOVE ${OLD_FILES})
endif()

unset(videofiles)
string(REPLACE "::" ";" VIDEO_DIRECTORY "${VIDEO_DIRECTORY}")

foreach(dir IN LISTS VIDEO_DIRECTORY)
    file(GLOB videofile ${dir}/*.y4m)
    list(APPEND videofiles ${videofile})
endforeach()

if(NOT videofiles)
    message(
        FATAL_ERROR
            "No y4m videos found in ${VIDEO_DIRECTORY}. Cannot generate a PGO profile."
    )
endif()

set(CPUARG)
if(TCPU MATCHES X86)
set(CPUARG "--asm" "9")
endif()
if(TCPU MATCHES ARM)
set(CPUARG "--asm" "3")
endif()

foreach(video IN LISTS videofiles)
    get_filename_component(videoname "${video}" NAME_WE)

    SET(ENCODING_COMMAND ${SvtAv1EncApp} ${CPUARG} -i ${video} -b "${BUILD_DIRECTORY}/${videoname}.ivf" --preset 2 --film-grain 8 --tune 0 --variance-boost-strength 3 --variance-octile 3 --luminance-qp-bias 12 --complex-hvs 1 --ac-bias 1.2 --tx-bias 1 --enable-tf 2 --noise-norm-strength 2 --enable-dlf 2 --qp-scale-compress-strength 1.5 --enable-overlays 1 --qm-min 7 --qm-max 12 --tile-rows 1 --tile-columns 1)
    list(JOIN ENCODING_COMMAND " " ENCODING_COMMAND_STR)
    message(
        STATUS
            "Running ${ENCODING_COMMAND_STR}"
    )
    execute_process(
        COMMAND ${ENCODING_COMMAND}
        RESULT_VARIABLE ENCODE_RESULT
    )
    if(NOT ENCODE_RESULT EQUAL 0)
        message(
            FATAL_ERROR
                "PGO encoding failed for ${video} with exit code ${ENCODE_RESULT}"
        )
    endif()
endforeach()
