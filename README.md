# csad2526ki405shustakevychvladyslav29

Simple Hello World C++ program with math operations and unit tests.

## Building with CMake (Recommended)

### Prerequisites
- CMake 3.14 or higher (для підтримки FetchContent з GoogleTest)
- C++17 compatible compiler (g++, clang++, or MSVC)
- Git (для завантаження GoogleTest)

### Build Steps
Windows (PowerShell):
```powershell
mkdir build
cd build
cmake ..
cmake --build .
```

The executable will be in the `build/Release/HelloWorld.exe`.

### Building and Running Tests

1. Configure project with tests (Windows PowerShell):
```powershell
mkdir build
cd build
cmake .. -G "Visual Studio 17 2022"  # or your preferred generator
```

2. Build main program and tests:
```powershell
cmake --build . --config Release
```

3. Run all tests with detailed output:
```powershell
ctest -C Release -V
```

4. Run specific tests directly:
```powershell
# Run all tests with colored output
.\Release\unit_tests.exe --gtest_color=yes

# Run only Addition tests
.\Release\unit_tests.exe --gtest_filter=AdditionTests.*

# Run one specific test
.\Release\unit_tests.exe --gtest_filter=AdditionTests.PositiveNumbers
```

## Notes

- To install CMake:
  - Windows: Download from [cmake.org](https://cmake.org/download/) or use `winget install Kitware.CMake`
  - For Windows, you can also use Visual Studio's developer command prompt with CMake support

## Troubleshooting Tests

1. Якщо CMake не може знайти компілятор:
   - Переконайтеся, що Visual Studio встановлена з інструментами C++
   - Спробуйте запустити з Developer Command Prompt for VS 2022

2. Якщо GoogleTest не завантажується:
   - Перевірте підключення до інтернету
   - Спробуйте запустити CMake з правами адміністратора
   - При проблемах, можна вручну склонувати GoogleTest в `build/_deps/googletest-src`

3. Якщо тести не знаходяться:
   - Перевірте, що збірка пройшла успішно (`cmake --build . --config Release`)
   - Перевірте, що файл `unit_tests.exe` існує в `build/Release/`
   - Спробуйте запустити тести напряму: `.\Release\unit_tests.exe`

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