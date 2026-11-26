# LeiaSR GDExtension (D-418). Built by scripts/build_leiasr.ps1; the DLL goes
# to native/bin/ and is loaded through native/leiasr.gdextension.
cmake_minimum_required(VERSION 3.17)
project(leiasr LANGUAGES CXX)

set(GODOTCPP_TARGET "template_release" CACHE STRING "" FORCE)
# The SR SDK passes C++ objects across its DLL boundary: share its C runtime (/MD).
set(GODOTCPP_USE_STATIC_CPP OFF CACHE BOOL "" FORCE)
set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreadedDLL")
add_subdirectory(${CMAKE_CURRENT_SOURCE_DIR}/../third_party/godot-cpp godot-cpp)

if(NOT DEFINED ENV{LEIASR_SDKROOT})
    set(LEIASR_SDK "C:/Users/Phoenixfox/Dev/LeiaSDK")
else()
    set(LEIASR_SDK "$ENV{LEIASR_SDKROOT}")
endif()

add_library(leiasr SHARED src/leia_sr.cpp src/register_types.cpp)
file(GLOB LEIASR_THIRD_PARTY_INC LIST_DIRECTORIES true "${LEIASR_SDK}/third_party/*/include")
target_include_directories(leiasr PRIVATE ${LEIASR_SDK}/include ${LEIASR_THIRD_PARTY_INC})
target_link_directories(leiasr PRIVATE ${LEIASR_SDK}/lib ${LEIASR_SDK}/third_party/OpenCV/lib/x64)
target_link_libraries(leiasr PRIVATE godot-cpp
    simulatedreality SimulatedRealityCore SimulatedRealityDisplays SimulatedRealityDirectX DimencoWeaving opencv_world343
    d3d12 delayimp)
# Delay-load the SR runtime so the extension loads on PCs without it.
target_link_options(leiasr PRIVATE
    /DELAYLOAD:simulatedreality.dll /DELAYLOAD:SimulatedRealityCore.dll
    /DELAYLOAD:SimulatedRealityDisplays.dll /DELAYLOAD:SimulatedRealityDirectX.dll
    /DELAYLOAD:DimencoWeaving.dll /DELAYLOAD:opencv_world343.dll)
target_compile_options(leiasr PRIVATE /EHsc /W3 /wd4244 /wd4267)
set_target_properties(leiasr PROPERTIES
    CXX_STANDARD 17
    MSVC_RUNTIME_LIBRARY "MultiThreadedDLL"
    OUTPUT_NAME "leiasr.windows.x86_64"
    RUNTIME_OUTPUT_DIRECTORY "$<1:${CMAKE_CURRENT_SOURCE_DIR}/../bin>"
    LIBRARY_OUTPUT_DIRECTORY "$<1:${CMAKE_CURRENT_SOURCE_DIR}/../bin>")
