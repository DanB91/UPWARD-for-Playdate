# UPWARD for Playdate
## Overview
This repository contains the full source code and assets for the port of Matthias Falk's PICO-8 game, UPWARD, to Playdate.  

Both this [Playdate verion](https://danb91.itch.io/upward-for-playdate) and the original [PICO-8 version](https://pocketfruit.itch.io/upward) of UPWARD are available to play for free!

The code is released under GPLv3, but if you wish to write your own proprietary Playdate game in Zig, feel free to use my [Zig-Playdate template](https://github.com/DanB91/Zig-Playdate-Template), which is released to the public domain.

##  <a name="Compilation Requirements"></a>Compilation Requirements
- Either macOS, Windows, or Linux.
- Zig compiler that supports the "stage 2" self-hosted compiler.  Tested on 0.11.0, but in theory should support 0.10.0.
- [Playdate SDK](https://play.date/dev/) installed.
- Binutils:
    - GNU `objcopy` is required to be in your `PATH` on macOS, while `arm-none-eabi-objcopy` is required for Linux and Windows.
    - For macOS, install `binutils` via homebrew with `brew install binutils`.
    - For Linux, install `gcc-arm-none-eabi` in accordance with your distribution/package manager. For Ubuntu, install with `sudo apt install gcc-arm-none-eabi`.
    - For Windows, follow paragraph `3.1` in the [Playdate SDK documentation](https://sdk.play.date/1.12.3/Inside%20Playdate%20with%20C.html#_install_development_tools).
    
## Compiling
1. Make sure the Playdate SDK is installed, Zig is installed and in your PATH, and all other [requirements](#Requirements) are met.
1. Run `zig build -Drelease-fast=true` which will compile the release version of the game.
    - If there any errors, double check `PLAYDATE_SDK_PATH` is correctly set and either binutils or the ARM Toolchain (depending on your OS) is properly installed and set in your `PATH`.
1. The `upward.pdx` executable should be produced in the newly created `zig-out` folder.  
    - Keep in mind, this executable will only run on the platform you compiled on, plus Playdate hardware. If you want your `updward.pdx` to be "universal", you will need to compile this codebase on macOS, Windows, and Linux, and have an `upward.pdx` that contains `pdex.dylib`, `pdex.dll`, and `pdex.so`.   

## Running on the Playdate Simulator
1. Make sure the Playdate Simulator is closed.
1. Run `zig build -Drelease-fast=true run`.
    - If there any errors, double check `PLAYDATE_SDK_PATH` is correctly set and either binutils or the ARM Toolchain (depending on your OS) is properly installed and set in your `PATH`.
1. Optionally, connect your Playdate to the comupter and upload to the device by going to `Device` -> `Upload Game to Device..` in the Playdate Simulator.

## Profiler
While working on this project, I wrote a performance profiler to help me keep track of how fast each frame was and performance of certain complex code.  

It is disabled in the final release, but, if you're curious to take a look at these metrics, you can renable the profiler by setting `ENABLE_PROFILING` to `true` in `profiler.zig`.  Then, while running the game, you can toggle the profiler buy holding the `A`, `B`, and `Up` buttons.

## Credits
- Daniel Bokser - Ported UPWARD to Playdate.
- Matthias Falk - Creator of the original UPWARD game on PICO-8 and contributed some UX ideas to the port.
