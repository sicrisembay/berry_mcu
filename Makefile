MCU	 ?= f103
CC	 = arm-none-eabi-gcc
OBJCOPY	 = arm-none-eabi-objcopy
SIZE	 = arm-none-eabi-size
MKDIR	 = mkdir
STM32_PROGRAMMER_CLI ?= "C:/Program Files/STMicroelectronics/STM32Cube/STM32CubeProgrammer/bin/STM32_Programmer_CLI.exe"

BERRY_PATH = middleware/berry
GENERATE   = generate
COC_BUILD  = $(BERRY_PATH)/tools/coc/coc
PYTHON     = python
BERRY_USER_PATH = ./user

DEBUG	 = -DDEBUG

ifeq ($(MCU),f103)
SRCS    += ./middleware/berry/default/be_port.c
CFLAGS	 = -g -Wall -Wextra -Os
CFLAGS	+= -DSTM32F10X_HD -DUSE_STDPERIPH_DRIVER
CFLAGS	+= -ffunction-sections -Wl,-gc-sections -mcpu=cortex-m3 -mthumb
CFLAGS  += -specs=nosys.specs -specs=nano.specs -u _printf_float
CFLAGS	+= -T"./toolcfg/stm32f10x_flash.ld" -lm
LDFLAGS	 = $(CFLAGS)
DOWNCFG	 = ./toolcfg/stm32f10x_download.cfg
OUTDIR	 = output
TARGET	 = $(OUTDIR)/app

INCPATH	 = ./core				\
	   ./hardware				\
	   ./std_lib/inc			\
	   ./middleware/berry/src		\
	   ./user
SRCPATH	 = ./core 				\
	   ./hardware 				\
	   ./std_lib/src 			\
	   ./middleware/berry/src		\
	   ./user
START 	 = ./core/startup/gcc/startup_stm32f10x_hd.s

SRCS	+= $(foreach dir, $(SRCPATH), $(wildcard $(dir)/*.c))
OBJS	 = $(patsubst %.c, %.o, $(SRCS))
DEPS	 = $(patsubst %.c, %.d, $(SRCS))
CFLAGS	+= $(foreach dir, $(INCPATH), -I"$(dir)")
else ifeq ($(MCU),g474)
OUTDIR	 = output/g474
TARGET	 = $(OUTDIR)/app
BERRY_USER_PATH = ./user/g474
START	 = ./drivers/cmsis-device-g4/Source/Templates/gcc/startup_stm32g474xx.s
SRCS	 = ./user/g474/main_g474.c \
	   ./user/g474/boardlib_g474.c \
	   ./user/be_modtab.c \
	   ./user/shell.c \
	   ./middleware/berry/default/be_port.c \
	   $(wildcard ./middleware/berry/src/*.c) \
	   ./drivers/cmsis-device-g4/Source/Templates/system_stm32g4xx.c \
	   ./drivers/STM32G4xx_HAL_Driver/Src/stm32g4xx_hal_cortex.c \
	   ./drivers/STM32G4xx_HAL_Driver/Src/stm32g4xx_hal.c \
	   ./drivers/STM32G4xx_HAL_Driver/Src/stm32g4xx_hal_rcc.c \
	   ./drivers/STM32G4xx_HAL_Driver/Src/stm32g4xx_hal_gpio.c \
	   ./drivers/STM32G4xx_HAL_Driver/Src/stm32g4xx_hal_uart.c \
	   ./drivers/STM32G4xx_HAL_Driver/Src/stm32g4xx_hal_uart_ex.c \
	   ./drivers/STM32G4xx_HAL_Driver/Src/stm32g4xx_hal_dma.c \
	   ./drivers/STM32G4xx_HAL_Driver/Src/stm32g4xx_hal_dac.c \
	   ./drivers/STM32G4xx_HAL_Driver/Src/stm32g4xx_hal_dac_ex.c \
	   ./drivers/STM32G4xx_HAL_Driver/Src/stm32g4xx_hal_tim.c \
	   ./drivers/STM32G4xx_HAL_Driver/Src/stm32g4xx_hal_tim_ex.c
OBJS	 = $(addprefix $(OUTDIR)/,$(notdir $(SRCS:.c=.o)))
DEPS	 = $(OBJS:.o=.d)
CFLAGS	 = -g -Wall -Wextra -Os
CFLAGS	+= -ffunction-sections -fdata-sections -mcpu=cortex-m4 -mthumb
CFLAGS	+= -mfpu=fpv4-sp-d16 -mfloat-abi=hard
CFLAGS	+= -DSTM32G474xx -DUSE_HAL_DRIVER
CFLAGS	+= -Idrivers/cmsis-device-g4/Include
CFLAGS	+= -Idrivers/CMSIS_5/CMSIS/Core/Include
CFLAGS	+= -Idrivers/STM32G4xx_HAL_Driver/Inc -Imiddleware/berry/src -Igenerate -Iuser/g474 -Iuser
LDFLAGS	 = $(CFLAGS) -specs=nosys.specs -specs=nano.specs
LDFLAGS	+= -Wl,--gc-sections -Wl,-Map=$(TARGET).map
LDFLAGS	+= -T./toolcfg/stm32g474_flash.ld -lm
else
$(error Unsupported MCU '$(MCU)'; use MCU=f103 or MCU=g474)
endif

ifeq ($(debug), 1)
    CFLAGS += $(DEBUG)
endif

ifeq ($(OS), Windows_NT) # Windows
    MAP_BUILD := $(MAP_BUILD).exe
    STR_BUILD := $(STR_BUILD).exe
endif

all: $(TARGET).elf

$(TARGET).elf: $(OBJS) $(START) $(OUTDIR)
	@ echo [Linking...]
	@ $(CC) $(OBJS) $(LDFLAGS) $(START) -o $@
	@ echo Creating Hex file...
	@ $(OBJCOPY) -O ihex -S $(TARGET).elf $(TARGET).hex
	@ $(OBJCOPY) -O binary -S $(TARGET).elf $(TARGET).bin
	@ echo Build info:
	@ $(SIZE) $(TARGET).elf
	@ echo done

ifeq ($(MCU),f103)
$(OBJS): %.o: %.c
	@ echo [Compile] $<
	@ $(CC) -MM $(CFLAGS) -MT"$*.d" -MT"$(<:.c=.o)" $< > $*.d
	@ $(CC) $(CFLAGS) -c $< -o $@

$(OBJS): | prebuild
else
$(OBJS): | prebuild

$(OUTDIR)/main_g474.o: ./user/g474/main_g474.c | $(OUTDIR)
	@ echo [Compile] $<
	@ $(CC) -MM $(CFLAGS) -MT"$(@:.o=.d)" -MT"$@" $< > $(@:.o=.d)
	@ $(CC) $(CFLAGS) -c $< -o $@

$(OUTDIR)/boardlib_g474.o: ./user/g474/boardlib_g474.c | $(OUTDIR)
	@ echo [Compile] $<
	@ $(CC) -MM $(CFLAGS) -MT"$(@:.o=.d)" -MT"$@" $< > $(@:.o=.d)
	@ $(CC) $(CFLAGS) -c $< -o $@

$(OUTDIR)/be_modtab.o: ./user/be_modtab.c | $(OUTDIR)
	@ echo [Compile] $<
	@ $(CC) -MM $(CFLAGS) -MT"$(@:.o=.d)" -MT"$@" $< > $(@:.o=.d)
	@ $(CC) $(CFLAGS) -c $< -o $@

$(OUTDIR)/shell.o: ./user/shell.c | $(OUTDIR)
	@ echo [Compile] $<
	@ $(CC) -MM $(CFLAGS) -MT"$(@:.o=.d)" -MT"$@" $< > $(@:.o=.d)
	@ $(CC) $(CFLAGS) -c $< -o $@

$(OUTDIR)/be_port.o: ./middleware/berry/default/be_port.c | $(OUTDIR)
	@ echo [Compile] $<
	@ $(CC) -MM $(CFLAGS) -MT"$(@:.o=.d)" -MT"$@" $< > $(@:.o=.d)
	@ $(CC) $(CFLAGS) -c $< -o $@

$(OUTDIR)/%.o: ./middleware/berry/src/%.c | $(OUTDIR)
	@ echo [Compile] $<
	@ $(CC) -MM $(CFLAGS) -MT"$(@:.o=.d)" -MT"$@" $< > $(@:.o=.d)
	@ $(CC) $(CFLAGS) -c $< -o $@

$(OUTDIR)/system_stm32g4xx.o: ./drivers/cmsis-device-g4/Source/Templates/system_stm32g4xx.c | $(OUTDIR)
	@ echo [Compile] $<
	@ $(CC) -MM $(CFLAGS) -MT"$(@:.o=.d)" -MT"$@" $< > $(@:.o=.d)
	@ $(CC) $(CFLAGS) -c $< -o $@

$(OUTDIR)/stm32g4xx_hal.o: ./drivers/STM32G4xx_HAL_Driver/Src/stm32g4xx_hal.c | $(OUTDIR)
	@ echo [Compile] $<
	@ $(CC) -MM $(CFLAGS) -MT"$(@:.o=.d)" -MT"$@" $< > $(@:.o=.d)
	@ $(CC) $(CFLAGS) -c $< -o $@

$(OUTDIR)/stm32g4xx_hal_cortex.o: ./drivers/STM32G4xx_HAL_Driver/Src/stm32g4xx_hal_cortex.c | $(OUTDIR)
	@ echo [Compile] $<
	@ $(CC) -MM $(CFLAGS) -MT"$(@:.o=.d)" -MT"$@" $< > $(@:.o=.d)
	@ $(CC) $(CFLAGS) -c $< -o $@

$(OUTDIR)/stm32g4xx_hal_rcc.o: ./drivers/STM32G4xx_HAL_Driver/Src/stm32g4xx_hal_rcc.c | $(OUTDIR)
	@ echo [Compile] $<
	@ $(CC) -MM $(CFLAGS) -MT"$(@:.o=.d)" -MT"$@" $< > $(@:.o=.d)
	@ $(CC) $(CFLAGS) -c $< -o $@

$(OUTDIR)/stm32g4xx_hal_gpio.o: ./drivers/STM32G4xx_HAL_Driver/Src/stm32g4xx_hal_gpio.c | $(OUTDIR)
	@ echo [Compile] $<
	@ $(CC) -MM $(CFLAGS) -MT"$(@:.o=.d)" -MT"$@" $< > $(@:.o=.d)
	@ $(CC) $(CFLAGS) -c $< -o $@

$(OUTDIR)/stm32g4xx_hal_uart.o: ./drivers/STM32G4xx_HAL_Driver/Src/stm32g4xx_hal_uart.c | $(OUTDIR)
	@ echo [Compile] $<
	@ $(CC) -MM $(CFLAGS) -MT"$(@:.o=.d)" -MT"$@" $< > $(@:.o=.d)
	@ $(CC) $(CFLAGS) -c $< -o $@

$(OUTDIR)/stm32g4xx_hal_uart_ex.o: ./drivers/STM32G4xx_HAL_Driver/Src/stm32g4xx_hal_uart_ex.c | $(OUTDIR)
	@ echo [Compile] $<
	@ $(CC) -MM $(CFLAGS) -MT"$(@:.o=.d)" -MT"$@" $< > $(@:.o=.d)
	@ $(CC) $(CFLAGS) -c $< -o $@

$(OUTDIR)/stm32g4xx_hal_dma.o: ./drivers/STM32G4xx_HAL_Driver/Src/stm32g4xx_hal_dma.c | $(OUTDIR)
	@ echo [Compile] $<
	@ $(CC) -MM $(CFLAGS) -MT"$(@:.o=.d)" -MT"$@" $< > $(@:.o=.d)
	@ $(CC) $(CFLAGS) -c $< -o $@

$(OUTDIR)/stm32g4xx_hal_dac.o: ./drivers/STM32G4xx_HAL_Driver/Src/stm32g4xx_hal_dac.c | $(OUTDIR)
	@ echo [Compile] $<
	@ $(CC) -MM $(CFLAGS) -MT"$(@:.o=.d)" -MT"$@" $< > $(@:.o=.d)
	@ $(CC) $(CFLAGS) -c $< -o $@

$(OUTDIR)/stm32g4xx_hal_dac_ex.o: ./drivers/STM32G4xx_HAL_Driver/Src/stm32g4xx_hal_dac_ex.c | $(OUTDIR)
	@ echo [Compile] $<
	@ $(CC) -MM $(CFLAGS) -MT"$(@:.o=.d)" -MT"$@" $< > $(@:.o=.d)
	@ $(CC) $(CFLAGS) -c $< -o $@

$(OUTDIR)/stm32g4xx_hal_tim.o: ./drivers/STM32G4xx_HAL_Driver/Src/stm32g4xx_hal_tim.c | $(OUTDIR)
	@ echo [Compile] $<
	@ $(CC) -MM $(CFLAGS) -MT"$(@:.o=.d)" -MT"$@" $< > $(@:.o=.d)
	@ $(CC) $(CFLAGS) -c $< -o $@

$(OUTDIR)/stm32g4xx_hal_tim_ex.o: ./drivers/STM32G4xx_HAL_Driver/Src/stm32g4xx_hal_tim_ex.c | $(OUTDIR)
	@ echo [Compile] $<
	@ $(CC) -MM $(CFLAGS) -MT"$(@:.o=.d)" -MT"$@" $< > $(@:.o=.d)
	@ $(CC) $(CFLAGS) -c $< -o $@
endif

sinclude $(DEPS)

$(OUTDIR):
	@ $(MKDIR) -p $(OUTDIR)

$(GENERATE):
	@ $(MKDIR) $(GENERATE)

prebuild: $(GENERATE)
	@ echo [Prebuild] generate resources
	@ $(PYTHON) $(COC_BUILD) ./middleware/berry/src $(BERRY_USER_PATH) -o $(GENERATE) -c ./user/berry_conf.h
	@ echo done

clean:
	@ echo [Clean...]
	@ $(RM) $(OBJS) $(DEPS)
	@ echo done

ifeq ($(MCU),g474)
download:
	@ $(STM32_PROGRAMMER_CLI) -c port=SWD -w $(TARGET).bin 0x08000000 -v -rst
else
download:
	@ openocd -f $(DOWNCFG)
endif
