SRCS    += ./middleware/berry/default/be_port.c
CFLAGS	 = -g -Wall -Wextra -Os
CFLAGS	+= -DSTM32F10X_HD -DUSE_STDPERIPH_DRIVER
CFLAGS	+= -ffunction-sections -Wl,-gc-sections -mcpu=cortex-m3 -mthumb 
CFLAGS  += -specs=nosys.specs -specs=nano.specs -u _printf_float
CFLAGS	+= -T"./toolcfg/stm32f10x_flash.ld"
CFLAGS	+= -lm
DOWNCFG	+= "./toolcfg/stm32f10x_download.cfg"
DEBUG	 = -DDEBUG
OUTDIR	 = output
TARGET	 = $(OUTDIR)/app
CC	 = arm-none-eabi-gcc
OBJCOPY	 = arm-none-eabi-objcopy
SIZE	 = arm-none-eabi-size
MKDIR	 = mkdir

BERRY_PATH = middleware/berry
GENERATE   = generate
COC_BUILD  = $(BERRY_PATH)/tools/coc/coc
PYTHON     = python

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
	@ $(CC) $(OBJS) $(CFLAGS) $(START) -o $@
	@ echo Creating Hex file...
	@ $(OBJCOPY) -O ihex -S $(TARGET).elf $(TARGET).hex
	@ $(OBJCOPY) -O binary -S $(TARGET).elf $(TARGET).bin
	@ echo Build info:
	@ $(SIZE) $(TARGET).elf
	@ echo done

$(OBJS): %.o: %.c
	@ echo [Compile] $<
	@ $(CC) -MM $(CFLAGS) -MT"$*.d" -MT"$(<:.c=.o)" $< > $*.d
	@ $(CC) $(CFLAGS) -c $< -o $@

sinclude $(DEPS)
$(OBJS): | prebuild

$(OUTDIR):
	@ $(MKDIR) $(OUTDIR)

$(GENERATE):
	@ $(MKDIR) $(GENERATE)

prebuild: $(GENERATE)
	@ echo [Prebuild] generate resources
	@ $(PYTHON) $(COC_BUILD) ./middleware/berry/src ./user -o $(GENERATE) -c ./user/berry_conf.h
	@ echo done

clean:
	@ echo [Clean...]
	@ $(RM) $(OBJS) $(DEPS)
	@ echo done

download:
	@ openocd -f $(DOWNCFG)
