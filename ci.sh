#!/usr/bin/env bash
set -e

# Remove existing build directory
rm -rf build

# Create and enter build directory
mkdir build
cd build

# Configure project
cmake ..

# Build project
cmake --build .

# Run tests
ctest --output-on-failure
