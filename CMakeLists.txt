cmake_minimum_required(VERSION 3.14)

# Set project name and language
project(HelloWorld CXX)

# Specify C++17 standard
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Add executable target
add_executable(${PROJECT_NAME} main.cpp)

# Library for math operations
add_library(math_operations STATIC math_operations.cpp math_operations.h)
target_include_directories(math_operations PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})
target_compile_features(math_operations PUBLIC cxx_std_17)
target_link_libraries(${PROJECT_NAME} PRIVATE math_operations)

# Try to find an installed GoogleTest first; if not available, fall back to FetchContent.
find_package(GTest CONFIG QUIET)
if (NOT TARGET GTest::gtest)
	include(FetchContent)
		FetchContent_Declare(
			googletest
			GIT_REPOSITORY https://github.com/google/googletest.git
			GIT_TAG v1.14.0
		)
	# For Windows: prevents overriding the parent project's compiler/linker settings
	set(gtest_force_shared_crt ON CACHE BOOL "" FORCE)
	FetchContent_MakeAvailable(googletest)
endif()

# Enable testing and add unit test executable
enable_testing()
add_executable(unit_tests tests/unit_tests.cpp)
target_link_libraries(unit_tests PRIVATE GTest::gtest_main math_operations)
include(GoogleTest)
# Increase discovery timeout to avoid CI test discovery timeouts on slow runners
gtest_discover_tests(unit_tests PROPERTIES DISCOVERY_TIMEOUT 60)
