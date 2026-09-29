# berry_mcu
The Berry language for STM32F103.

## Build

1. Install the [GNU Arm Embedded Toolchain](https://developer.arm.com/open-source/gnu-toolchain/gnu-rm) and Python 3.
2. Connect to the MCU using ST Link V2.
3. Enter the following commands:
   ``` bash
   git clone --recursive https://github.com/gztss/berry_mcu.git
   cd berry_mcu
   make
   make download # download to MCU
   ```

## NUCLEO-G474RE

The G474 target uses the onboard ST-LINK over SWD and STM32CubeProgrammer CLI.
On Windows, the Makefile uses the standard STM32CubeProgrammer installation path below by default. Override `STM32_PROGRAMMER_CLI` if your installation is elsewhere, then run:

```bash
make MCU=g474
make MCU=g474 download
```

The target uses the internal 16 MHz HSI clock. The serial console is USART2 on PA2/PA3 at 115200 baud, and the onboard LD2 LED is on PA5.
