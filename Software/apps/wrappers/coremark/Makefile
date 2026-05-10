APP_DIR       := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
COREMARK_DIR  := $(APP_DIR)../../coremark/
RUNTIME_DIR   := $(APP_DIR)../../../runtime/
BUILD_DIR     := $(APP_DIR)../../../build/coremark

APP_NAME      := coremark
APP_SRCS      := core_main.c core_list_join.c core_matrix.c core_state.c core_util.c core_portme.c
APP_SRC_DIRS  := $(APP_DIR) $(COREMARK_DIR)
INCS          := -I$(APP_DIR) -I$(COREMARK_DIR) -I$(RUNTIME_DIR)
OPT           := -O2
EXTRA_CFLAGS  := -DPERFORMANCE_RUN=1 -DITERATIONS=3000
EXTRA_LDLIBS  := -lgcc

include ../../../runtime/common.mk
