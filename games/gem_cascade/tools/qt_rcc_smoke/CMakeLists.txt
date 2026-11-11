cmake_minimum_required(VERSION 3.21)
project(GemCascadeRccSmoke LANGUAGES CXX)

find_package(Qt6 6.8 REQUIRED COMPONENTS Core Gui Qml Quick Multimedia)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

add_executable(gem_cascade_rcc_smoke rcc_smoke.cpp)
target_link_libraries(gem_cascade_rcc_smoke PRIVATE
    Qt6::Core Qt6::Gui Qt6::Qml Qt6::Quick Qt6::Multimedia
)
