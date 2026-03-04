TOOLCHAIN  = riscv-none-elf
CC         = $(TOOLCHAIN)-gcc
OBJCOPY    = $(TOOLCHAIN)-objcopy
OBJDUMP    = $(TOOLCHAIN)-objdump

ARCH       = rv32im_zicsr
ABI        = ilp32

FIRMWARE   = $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
OUTPUT     = $(FIRMWARE)../../program.hex

CFLAGS     = -march=$(ARCH) -mabi=$(ABI) -O2 -nostdlib -nostartfiles -ffreestanding
LDFLAGS    = -T $(FIRMWARE)linker.ld

RUNTIME_SRCS = $(FIRMWARE)crt0.S $(FIRMWARE)syscall.c
RUNTIME_OBJS = $(RUNTIME_SRCS:.c=.o)
RUNTIME_OBJS := $(RUNTIME_OBJS:.S=.o)

SRCS  ?= main.c
OBJS   = $(SRCS:.c=.o)
TARGET ?= program

all: $(OUTPUT)

$(TARGET).elf: $(OBJS) $(RUNTIME_OBJS)
	$(CC) $(CFLAGS) $(LDFLAGS) $^ -o $@

$(OUTPUT): $(TARGET).elf
	$(OBJCOPY) -O verilog --verilog-data-width 4 $< $@
	@echo "Built: $@"

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

%.o: %.S
	$(CC) $(CFLAGS) -c $< -o $@

dump: $(TARGET).elf
	$(OBJDUMP) -d $<

clean:
	rm -f $(OBJS) $(RUNTIME_OBJS) $(TARGET).elf $(OUTPUT)
