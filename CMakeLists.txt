cmake_minimum_required(VERSION 3.10)

# Set project name and language
project(HelloWorld CXX)

# Specify C++17 standard
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Add executable target
add_executable(${PROJECT_NAME} main.cpp)
