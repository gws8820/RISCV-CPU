APP_DIR      := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
APP_NAME     := dhrystone
APP_SRCS     := dhrystone.c dhrystone_main.c
OPT          := -O2
EXTRA_CFLAGS := -std=gnu89 -fwrapv -Wno-implicit-int -Wno-implicit-function-declaration
EXTRA_LDLIBS := -lgcc

ifneq ($(DHRY_DEBUG_EVERY),)
EXTRA_CFLAGS += -DDHRY_DEBUG_EVERY=$(DHRY_DEBUG_EVERY)
endif

include ../../runtime/common.mk
