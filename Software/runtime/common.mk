TOOLCHAIN    = riscv-none-elf
CC           = $(TOOLCHAIN)-gcc
OBJCOPY      = $(TOOLCHAIN)-objcopy
OBJDUMP      = $(TOOLCHAIN)-objdump

ARCH         = rv32im_zicsr_zifencei
ABI          = ilp32

APP_NAME     ?= app
TARGET       ?= $(APP_NAME)
APP_SRCS     ?=
RUNTIME_SRCS ?= crt0.S syscalls.c
RUNTIME_DIR  ?= $(APP_DIR)../../runtime/
BUILD_DIR    ?= $(APP_DIR)../../build/$(APP_NAME)
INCS         ?= -I$(APP_DIR) -I$(RUNTIME_DIR)
OPT          ?= -O2
EXTRA_CFLAGS ?=
EXTRA_LDLIBS ?= -lgcc

CFLAGS       = -march=$(ARCH) -mabi=$(ABI) $(OPT) -nostdlib -nostartfiles -ffreestanding $(INCS) $(EXTRA_CFLAGS)
LDFLAGS      = -T $(RUNTIME_DIR)linker.ld

APP_OBJS     = $(addprefix $(BUILD_DIR)/,$(APP_SRCS:.c=.o))
APP_OBJS     := $(APP_OBJS:.S=.o)
RUNTIME_OBJS = $(addprefix $(BUILD_DIR)/,$(RUNTIME_SRCS:.c=.o))
RUNTIME_OBJS := $(RUNTIME_OBJS:.S=.o)
OBJS         = $(APP_OBJS) $(RUNTIME_OBJS)
ELF          = $(BUILD_DIR)/$(TARGET).elf
HEX          = $(BUILD_DIR)/$(TARGET).hex

vpath %.c $(APP_DIR) $(RUNTIME_DIR)
vpath %.S $(APP_DIR) $(RUNTIME_DIR)

.DEFAULT_GOAL := all

ifeq ($(OS),Windows_NT)
MKDIR = @if not exist "$(subst /,\,$(BUILD_DIR))" mkdir "$(subst /,\,$(BUILD_DIR))"
else
MKDIR = @mkdir -p $(BUILD_DIR)
endif

$(BUILD_DIR):
	$(MKDIR)

$(BUILD_DIR)/%.o: %.c | $(BUILD_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD_DIR)/%.o: %.S | $(BUILD_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

$(ELF): $(OBJS)
	$(CC) $(CFLAGS) $(LDFLAGS) $^ $(EXTRA_LDLIBS) -o $@

$(HEX): $(ELF)
	$(OBJCOPY) -O verilog --verilog-data-width 4 $< $@
	@echo "Built: $@"

all: $(HEX)

dump: $(ELF)
	$(OBJDUMP) -d $<

ifeq ($(OS),Windows_NT)
clean:
	-del /q $(subst /,\,$(OBJS) $(ELF) $(HEX))
else
clean:
	rm -f $(OBJS) $(ELF) $(HEX)
endif
