cmake_minimum_required(VERSION 3.12..3.20)

project(Obsidian)

include(cmake/CPM.cmake)

add_subdirectory(source_files/filename_formatter)
add_subdirectory(source_files/fmt)
add_subdirectory(source_files/lua)
add_subdirectory(source_files/miniz)
add_subdirectory(source_files/physfs)
add_subdirectory(source_files/qsavetex)
add_subdirectory(source_files/slump)
add_subdirectory(source_files/zdbsp)

find_package(Fontconfig)

project(
  obsidian
  LANGUAGES CXX
  VERSION 0.1.0
)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED True)
set(CMAKE_CXX_FLAGS "-O2 -Wall")
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
if(WIN32
   AND NOT MINGW
   AND NOT MSYS
)
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} /EHa")
  set(CMAKE_EXE_LINKER_FLAGS "/SUBSYSTEM:WINDOWS")
endif()
if(MSYS)
  set(CMAKE_EXE_LINKER_FLAGS "-static -mwindows")
endif()

if(CMAKE_BUILD_TYPE STREQUAL "Debug")
  set(CMAKE_CXX_CLANG_TIDY clang-tidy)
  file(GLOB ALL_SOURCES "source_files/obsidian_main/*.cc"
       "source_files/obsidian_main/*.h"
  )
  add_custom_target(
    clang-tidy COMMAND "${CMAKE_CXX_CLANG_TIDY}" -p "${CMAKE_BINARY_DIR}"
                       ${ALL_SOURCES}
  )
endif()

cpmaddpackage(
  NAME
  Format.cmake
  VERSION
  1.7.0
  GITHUB_REPOSITORY
  TheLartians/Format.cmake
  OPTIONS
  # set to "yes" to skip CMake formatting
  "FORMAT_SKIP_CMAKE NO"
  # path to exclude from formatting (optional + regex)
  "CMAKE_FORMAT_EXCLUDE cmake/CPM.cmake"
)

add_executable(
  obsidian
  cpp.hint
  source_files/obsidian_main/aj_local.h
  source_files/obsidian_main/aj_map.cc
  source_files/obsidian_main/aj_map.h
  source_files/obsidian_main/aj_poly.cc
  source_files/obsidian_main/aj_poly.h
  source_files/obsidian_main/aj_structs.h
  source_files/obsidian_main/aj_util.cc
  source_files/obsidian_main/aj_util.h
  source_files/obsidian_main/aj_wad.cc
  source_files/obsidian_main/aj_wad.h
  source_files/obsidian_main/csg_bsp.cc
  source_files/obsidian_main/csg_clip.cc
  source_files/obsidian_main/csg_doom.cc
  source_files/obsidian_main/csg_local.h
  source_files/obsidian_main/csg_main.cc
  source_files/obsidian_main/csg_main.h
  source_files/obsidian_main/csg_nukem.cc
  source_files/obsidian_main/csg_quake.cc
  source_files/obsidian_main/csg_quake.h
  source_files/obsidian_main/csg_shade.cc
  source_files/obsidian_main/csg_spots.cc
  source_files/obsidian_main/defines.h
  source_files/obsidian_main/dm_extra.cc
  source_files/obsidian_main/dm_extra.h
  source_files/obsidian_main/dm_prefab.cc
  source_files/obsidian_main/dm_prefab.h
  source_files/obsidian_main/g_doom.cc
  source_files/obsidian_main/g_doom.h
  source_files/obsidian_main/g_nukem.cc
  source_files/obsidian_main/g_nukem.h
  source_files/obsidian_main/g_quake.cc
  source_files/obsidian_main/g_quake2.cc
  source_files/obsidian_main/g_quake3.cc
  source_files/obsidian_main/hdr_fltk.h
  source_files/obsidian_main/hdr_lua.h
  source_files/obsidian_main/hdr_ui.h
  source_files/obsidian_main/headers.h
  source_files/obsidian_main/images.h
  source_files/obsidian_main/lib_argv.cc
  source_files/obsidian_main/lib_argv.h
  source_files/obsidian_main/lib_crc.cc
  source_files/obsidian_main/lib_crc.h
  source_files/obsidian_main/lib_file.cc
  source_files/obsidian_main/lib_file.h
  source_files/obsidian_main/lib_grp.cc
  source_files/obsidian_main/lib_grp.h
  source_files/obsidian_main/lib_pak.cc
  source_files/obsidian_main/lib_pak.h
  source_files/obsidian_main/lib_signal.cc
  source_files/obsidian_main/lib_signal.h
  source_files/obsidian_main/lib_tga.cc
  source_files/obsidian_main/lib_tga.h
  source_files/obsidian_main/lib_util.cc
  source_files/obsidian_main/lib_util.h
  source_files/obsidian_main/lib_wad.cc
  source_files/obsidian_main/lib_wad.h
  source_files/obsidian_main/lib_zip.cc
  source_files/obsidian_main/lib_zip.h
  source_files/obsidian_main/m_about.cc
  source_files/obsidian_main/m_addons.cc
  source_files/obsidian_main/m_addons.h
  source_files/obsidian_main/m_cookie.cc
  source_files/obsidian_main/m_cookie.h
  source_files/obsidian_main/m_dialog.cc
  source_files/obsidian_main/m_lua.cc
  source_files/obsidian_main/m_lua.h
  source_files/obsidian_main/m_manage.cc
  source_files/obsidian_main/m_options.cc
  source_files/obsidian_main/m_theme.cc
  source_files/obsidian_main/m_trans.cc
  source_files/obsidian_main/m_trans.h
  source_files/obsidian_main/main.cc
  source_files/obsidian_main/main.h
  source_files/obsidian_main/obsidian.rc
  source_files/obsidian_main/q1_structs.h
  source_files/obsidian_main/q2_structs.h
  source_files/obsidian_main/q3_structs.h
  source_files/obsidian_main/q_common.cc
  source_files/obsidian_main/q_common.h
  source_files/obsidian_main/q_light.cc
  source_files/obsidian_main/q_light.h
  source_files/obsidian_main/q_tjuncs.cc
  source_files/obsidian_main/q_vis.cc
  source_files/obsidian_main/q_vis.h
  source_files/obsidian_main/sys_assert.cc
  source_files/obsidian_main/sys_assert.h
  source_files/obsidian_main/sys_debug.cc
  source_files/obsidian_main/sys_debug.h
  source_files/obsidian_main/sys_endian.h
  source_files/obsidian_main/sys_macro.h
  source_files/obsidian_main/sys_type.h
  source_files/obsidian_main/sys_xoshiro.cc
  source_files/obsidian_main/sys_xoshiro.h
  source_files/obsidian_main/tx_forge.cc
  source_files/obsidian_main/tx_forge.h
  source_files/obsidian_main/tx_skies.cc
  source_files/obsidian_main/tx_skies.h
  source_files/obsidian_main/ui_boxes.cc
  source_files/obsidian_main/ui_boxes.h
  source_files/obsidian_main/ui_build.cc
  source_files/obsidian_main/ui_build.h
  source_files/obsidian_main/ui_game.cc
  source_files/obsidian_main/ui_game.h
  source_files/obsidian_main/ui_hyper.cc
  source_files/obsidian_main/ui_hyper.h
  source_files/obsidian_main/ui_map.cc
  source_files/obsidian_main/ui_map.h
  source_files/obsidian_main/ui_module.cc
  source_files/obsidian_main/ui_module.h
  source_files/obsidian_main/ui_widgets.cc
  source_files/obsidian_main/ui_widgets.h
  source_files/obsidian_main/ui_window.cc
  source_files/obsidian_main/ui_window.h
  source_files/obsidian_main/vis_buffer.cc
  source_files/obsidian_main/vis_buffer.h
  source_files/obsidian_main/vis_occlude.cc
  source_files/obsidian_main/vis_occlude.h
  source_files/obsidian_main/zf_menu.cc
  source_files/obsidian_main/zf_menu.h
)

target_include_directories(obsidian PRIVATE source_files/gif-h)
target_include_directories(obsidian PRIVATE source_files/lua)
target_include_directories(obsidian PRIVATE source_files/miniz)
target_include_directories(obsidian PRIVATE source_files/physfs)
target_include_directories(obsidian PRIVATE source_files/slump)
target_include_directories(obsidian PRIVATE source_files/zdbsp)

if(MINGW
   OR WIN32
   OR MSYS
)
  target_compile_definitions(obsidian PRIVATE WIN32)
else()
  target_compile_definitions(obsidian PRIVATE UNIX)
endif()

if(UNIX)
  find_package(FLTK 1.3)
endif()

if(FLTK_FOUND AND NOT MSYS)
  target_link_libraries(obsidian PRIVATE ${FLTK_LIBRARIES})
else()
  # use vendored version
  add_subdirectory(source_files/fltk)
  target_link_libraries(obsidian PRIVATE fltk fltk_images)
  target_include_directories(obsidian PRIVATE source_files/fltk)
endif()

if(WIN32 OR MSYS)
  add_subdirectory(source_files/wingetopt)
endif()

if(UNIX)
  find_package(X11 REQUIRED)
  target_link_libraries(obsidian PRIVATE X11::Xft)
endif()

target_link_libraries(obsidian PRIVATE fmt::fmt-header-only)

# Copies executables to local install directory after build
add_custom_command(
  TARGET obsidian
  POST_BUILD
  COMMAND "${CMAKE_COMMAND}" -E copy "$<TARGET_FILE:obsidian>"
          "${CMAKE_CURRENT_LIST_DIR}"
  COMMAND "${CMAKE_COMMAND}" -E copy "$<TARGET_FILE:filename_formatter>"
          "${CMAKE_CURRENT_LIST_DIR}/tools"
  COMMAND "${CMAKE_COMMAND}" -E copy "$<TARGET_FILE:qsavetex>"
          "${CMAKE_CURRENT_LIST_DIR}/tools"
)

add_dependencies(obsidian filename_formatter qsavetex)

if(UNIX)
  target_link_libraries(
    obsidian
    PRIVATE miniz
            obsidian_lua
            obsidian_physfs
            obsidian_zdbsp
            obsidian_slump
    PUBLIC  ${FONTCONFIG_LIBRARIES}
  )
else()
  target_link_libraries(
    obsidian PRIVATE miniz obsidian_lua obsidian_physfs obsidian_zdbsp obsidian_slump
  )
endif()
