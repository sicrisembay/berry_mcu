# STM32G474RE Port Plan

## Goal

Port this firmware from its STM32F103RCT6-oriented setup to the STM32G474RET6 on the NUCLEO-G474RE, retaining the Berry interpreter, generated resources, REPL, and existing board-level features where practical.

Track implementation status and validation in each phase below. Keep the F103 target buildable while bringing up G474 support so the existing target remains a regression reference.

## Current Baseline

- `Makefile` selects Cortex-M3, `STM32F10X_HD`, the F103 high-density startup file, and F103 linker/download configurations.
- `core/` and `std_lib/` contain the STM32F10x CMSIS/device definitions and Standard Peripheral Library. These are not portable to STM32G4.
- `core/system_stm32f10x.c` configures a 72 MHz F1 clock; the board has a different clock tree and can run up to 170 MHz.
- `hardware/usart1.c` and `user/main.c` use USART1, with the startup banner hard-coded to STM32F103RCT6.
- `user/boardlib.c` exposes LED and DAC commands to Berry, including two DAC channels and TIM2/DMA waveform playback. It uses F1 GPIO/DAC/TIM/DMA APIs and assumes a 72 MHz timer clock.
- The linker script describes 256 KiB flash and 48 KiB RAM, not the G474RE memory map.
- The legacy F103 download path uses OpenOCD. The G474 path uses STM32CubeProgrammer CLI with the NUCLEO onboard ST-LINK and virtual COM port.

## Recommended Port Shape

Introduce a G474-specific target configuration and hardware support layer instead of trying to adapt the F1 Standard Peripheral Library. Use the STM32CubeG4 HAL for clock, GPIO, UART, DAC, timer, and DMA. Keep the Berry interpreter and its resource-generation step shared between targets. Avoid a broad rewrite of Berry-facing function names unless a hardware feature cannot be preserved.

## Phases

### 1. Confirm target and pin requirements

- Target: STM32G474RET6 on NUCLEO-G474RE.
- Clock: use the internal HSI directly as the initial SYSCLK source; do not require an external clock source. Revisit PLL use only if performance needs justify it.
- Debug: use SWD through the onboard ST-LINK and leave the SWD pins dedicated to debugging.
- Console: use USART2, PA2 (TX) and PA3 (RX), at 115200 baud for the onboard ST-LINK virtual COM connection.
- LED: use onboard LD2 on PA5.
- DAC pin conflict: PA5 is also DAC1 channel 2 output, so reserve PA5 for LD2 and do not plan to use DAC channel 2 on that pin at the same time. Decide in Phase 4 whether DAC channel 2 is unnecessary or needs an alternate external output arrangement.
- Confirm whether both DAC channels and DMA-driven waveform playback are required. Verify the G474 DAC trigger and DMA request mapping from the reference manual rather than carrying over F1 channel numbers.

**Exit check:** complete for the requested clock, debug, console, and LED assignments. DAC channel 2 usage and any external wiring remain a Phase 4 decision.

### 2. Add a distinct G474 build target

- Add target-specific source/include lists and flags without changing the F103 defaults. Select Cortex-M4 and a consistent floating-point ABI across compile and link steps; verify the toolchain's C libraries match that ABI. **Implemented:** `MCU=f103` remains the default; `MCU=g474` uses Cortex-M4F hard-float flags and separate output/objects under `output/g474`.
- Add the G474 CMSIS/device startup and system initialization from the chosen STM32CubeG4 version. **Implemented:** use CMSIS Core 5.6.0, STM32G4 CMSIS Device 1.2.6, and the existing STM32G4 HAL 1.2.7 submodule; the G474 startup/system files select 16 MHz HSI by default.
- Add a G474 linker script using the exact G474RE flash and SRAM regions from the datasheet/reference manual. Revisit heap and stack sizes against Berry's runtime memory use; enable link-time overflow checks. **Implemented:** G474RE 512 KiB flash and 128 KiB SRAM regions, with reserved heap/stack and a map file.
- Replace the F1 OpenOCD target with the STM32G4 target and configure flashing through the NUCLEO onboard ST-LINK. Keep the F103 flash recipe intact. **Implemented:** the G474 `download` target uses `STM32_Programmer_CLI.exe` with `port=SWD`; the Makefile defaults to the standard Windows installation path and supports overriding `STM32_PROGRAMMER_CLI`.
- Make output names or directories target-specific to prevent one target's objects and generated binaries from being reused accidentally by the other. **Implemented:** target artifacts are isolated under `output/` and `output/g474/`.
- Add a minimal G474 HAL initialization image to prove the startup/linker/toolchain path before porting the Berry application. **Implemented:** `user/g474/main_g474.c` calls `HAL_Init()` and idles; this is a bring-up scaffold, not yet the Berry REPL.

**Exit check:** passed. A clean `make MCU=g474` builds ELF/HEX/BIN and reports memory usage; default `make` and `make MCU=f103` also build. The G474 ELF was checked for RX flash, RW RAM, and hard-float ABI. Hardware flash/debug remains unverified until STM32CubeProgrammer is installed and the NUCLEO is connected.

### 3. Bring up clock, reset, and console

- Configure clocks using the board's actual clock source and G474 clock tree. Define/update `SystemCoreClock` (or the equivalent HAL clock state) consistently. **Implemented:** the CMSIS system startup uses the 16 MHz HSI directly, and HAL initializes its SysTick time base from that clock.
- Port `hardware/delay.c` or replace it with a clock-aware HAL/LL delay. Remove hard-coded 72 MHz assumptions from any timing calculations. **Implemented:** the G474 bring-up uses `HAL_Delay()` and no F103 72 MHz timing constants.
- Move the console to the selected UART pins/peripheral. Preserve `printf` output and the interrupt-driven shell input behavior. **Implemented:** USART2 uses PA2/PA3 at 115200 baud; `_write()` retargets `printf`, and RX uses `HAL_UART_Receive_IT()` with interrupt echo.
- Update the startup banner to identify the G474 target and report the configured core clock if useful. **Implemented:** the banner identifies STM32G474RE, HSI frequency, UART settings, and LED pin.
- Configure the onboard LED for a basic execution indicator. **Implemented:** PA5 is configured as a push-pull output and toggles every 500 ms.

**Exit check:** complete. The Phase 3 image builds, programs, verifies, and resets successfully through the connected NUCLEO-G474RE ST-LINK. Tera Term on COM5 at 115200 8-N-1 displayed the startup banner and successfully echoed `hello world`; LD2 was configured for the execution indicator.

### 4. Port board functions and waveform output

- Reimplement LED control using the agreed board pin and polarity. **Implemented:** the `board.setled(bool)` command drives onboard LD2 on PA5.
- Reimplement the Berry `setdac` function for the selected DAC channel(s), including valid value bounds and pin configuration. **Implemented:** `board.setdac(1, value)` drives DAC1 channel 1 on PA4 for values 0 through 4095. DAC channel 2 is intentionally unavailable because PA5 is reserved for LD2.
- Port timer-triggered DMA waveform generation only after confirming the selected DAC channel's legal trigger, DMA request, and memory route on G474. Recalculate timer divisors from the configured timer clock, not the core clock by assumption. **Implemented:** DAC1 channel 1 uses TIM6 TRGO and DMA1 channel 1 with the G4 DAC1 channel 1 DMAMUX request; the timer period is calculated from PCLK1.
- Preserve `play_sin`, `play_rect`, `play_tri`, `play_stop`, and `reboot` semantics where feasible. If the PA5 conflict means functionality must differ, document that explicitly and provide an external-pin option. **Implemented:** all five commands are available through the G474 `board` module; waveform output is on PA4.
- Exercise the generated Berry module/resource path to ensure hardware changes do not alter the interpreter build. **Implemented:** the G474 target generates resources, links the Berry VM, and flashes successfully.

**Exit check:** the complete Phase 4 Berry image builds, programs, verifies, and resets successfully. Remaining hardware validation on the connected board: run the commands below over COM5 at 115200 baud, verify LD2, measure PA4 DAC levels, and measure waveform frequency/amplitude.

```berry
import board
board.setled(true)
board.setdac(1, 2048)
board.play_sin(1000, 0.5)
board.play_stop()
board.reboot()
```

### 5. Validate, document, and make the target selectable

- Run a clean build for both targets; inspect the G474 map file and verify vector table, flash/RAM bounds, stack/heap budget, and floating-point linkage.
- Program and debug with the onboard ST-LINK. Verify cold boot, reset, console input under sustained traffic, and operation at the selected clock.
- Measure DAC DC output and waveform frequency/amplitude with a meter or oscilloscope; test boundary values and repeated start/stop cycles.
- Update the project README with target prerequisites, build/flash commands, serial-console settings, selected pin map, and any external wiring.
- Document the chosen STM32CubeG4 version and whether the firmware uses HAL, LL, or direct CMSIS drivers.

**Completion criteria:** both target builds remain reproducible; G474 flashes and debugs through the NUCLEO; UART REPL and required board commands pass their checks; memory usage fits with an explicit reserve; documentation matches the actual pin map and setup.

## Main Risks and Decisions

| Risk or decision | Why it matters | Resolution |
| --- | --- | --- |
| F1 Standard Peripheral Library cannot serve G474 | Device registers and peripheral APIs differ | Add CubeG4 support or a deliberate CMSIS-based replacement; do not mix F1 headers/drivers into the G474 target |
| LED/DAC pin collision | LD2 and DAC1 channel 2 use PA5 | Reserve PA5 for onboard LD2; decide in Phase 4 whether to omit DAC2 or route it to an external output |
| DMA and timer routing differs | F1 DMA channel assignments and timer assumptions are not portable | Check G474 request mapping and supported DAC trigger sources in RM0440 |
| Clock assumptions affect timing | Existing code assumes 72 MHz for delays and waveform rate | Centralize clock configuration and calculate from actual timer clock |
| FPU ABI mismatch | Cortex-M4F compiler flags affect object/library compatibility | Apply one ABI consistently and clean-rebuild all objects and libraries |
| RAM headroom | Berry VM, buffers, heap, and stack share SRAM | Review linker map and stress-test scripts/REPL before choosing heap and stack reservations |

## Reference Material

- [NUCLEO-G474RE product page](https://www.st.com/en/evaluation-tools/nucleo-g474re.html)
- [STM32G474RE datasheet](https://www.st.com/resource/en/datasheet/stm32g474re.pdf)
- [STM32G4 reference manual RM0440](https://www.st.com/resource/en/reference_manual/rm0440-stm32g4-series-advanced-armbased-32bit-mcus-stmicroelectronics.pdf)
- [STM32G4 Nucleo-64 board user manual UM2505](https://www.st.com/resource/en/user_manual/um2505-stm32g4-nucleo64-boards-mb1367-stmicroelectronics.pdf)
- [STM32CubeProgrammer](https://www.st.com/en/development-tools/stm32cubeprog.html)