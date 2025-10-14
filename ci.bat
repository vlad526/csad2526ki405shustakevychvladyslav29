@echo off
REM Windows CI script: build and test with error checking

REM Create build directory
if not exist build (
  mkdir build
  if errorlevel 1 exit /b 1
)

REM Enter build directory
cd build
if errorlevel 1 exit /b 1

REM Configure project
cmake ..
if errorlevel 1 exit /b 1

REM Build project
cmake --build .
if errorlevel 1 exit /b 1

REM Run tests
ctest --output-on-failure
if errorlevel 1 exit /b 1
