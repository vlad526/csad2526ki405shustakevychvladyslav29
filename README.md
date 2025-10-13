# csad2526ki405shustakevychvladyslav29

Simple Hello World C++ program.

## Building with CMake (Recommended)

### Prerequisites
- CMake 3.10 or higher
- C++17 compatible compiler (g++, clang++, or MSVC)

### Build Steps
Windows (PowerShell):
```powershell
mkdir build
cd build
cmake ..
cmake --build .
```

Linux/macOS:
```bash
mkdir build
cd build
cmake ..
cmake --build .
```

The executable will be in the `build` directory (Windows: `build\Debug\HelloWorld.exe`, Unix: `build/HelloWorld`).

## Direct Compilation

Windows (PowerShell):
```powershell
g++ -std=c++17 -O2 -o main.exe .\main.cpp
.\main.exe
```

Linux/macOS:
```bash
g++ -std=c++17 -O2 -o main main.cpp
./main
```

## Notes

- To install CMake:
  - Windows: Download from [cmake.org](https://cmake.org/download/) or use `winget install Kitware.CMake`
  - Linux: `sudo apt install cmake` (Ubuntu/Debian) or `sudo dnf install cmake` (Fedora)
  - macOS: `brew install cmake`
- For Windows, you can also use Visual Studio's developer command prompt with CMake support