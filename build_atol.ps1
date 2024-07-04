# Ensure the script is run from its own directory
Set-Location -Path $PSScriptRoot

# Check if a command exists by running it and checking for errors
function Check-Command ($command) {
    if (-not (Get-Command $command -ErrorAction SilentlyContinue)) {
        Write-Error "$command is required but not found."
        exit 1
    }
}

# Check if Python, CMake, Git, and Ninja are installed
Check-Command "python"
Check-Command "cmake"
Check-Command "git"
Check-Command "ninja"

# Set ARM_TOOLCHAIN_DIR environment variable
if ($args.Length -lt 1) {
    Write-Error "Please provide the path for ARM_TOOLCHAIN_DIR as the first argument."
    exit 1
}
$env:ARM_TOOLCHAIN_DIR = $args[0]

# Run git submodule update --init
git submodule update --init

# Run Python dependency script
python tools/get_deps.py stm32h7

# Run CMake configuration
cmake -DCMAKE_BUILD_TYPE:STRING=Release `
      -DCMAKE_TOOLCHAIN_FILE:FILEPATH=$PSScriptRoot/ports/stm32h7/arm-toolchain.cmake `
      -S $PSScriptRoot/ports/stm32h7 `
      -B $PSScriptRoot/ports/stm32h7/_build/atol_integration_stand `
      -G Ninja

# Build the project with CMake
cmake --build $PSScriptRoot/ports/stm32h7/_build/atol_integration_stand
