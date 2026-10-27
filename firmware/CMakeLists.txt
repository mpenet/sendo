# ABOUTME: ESP-IDF project for the sendo firmware on ESP32-S3.
# ABOUTME: Build with `idf.py build` after sourcing ESP-IDF's export script.

cmake_minimum_required(VERSION 3.22)

include($ENV{IDF_PATH}/tools/cmake/project.cmake)
# Only build components that main depends on.
idf_build_set_property(MINIMAL_BUILD ON)
project(sendo)
