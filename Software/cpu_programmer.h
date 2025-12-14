#ifndef CPU_PROGRAMMER_H
#define CPU_PROGRAMMER_H

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

// Parameter
#define BASE_ADDR   0x00
#define START_FLAG  0xA5

// CMD
typedef enum {
    CMD_RESET       = 0x01,
    CMD_WRITE       = 0x02,
    CMD_RUN         = 0x03,
    CMD_EXIT        = 0x04
} cmd_t;

typedef struct {
    uint8_t         len;
    uint32_t        data [64];
} program_data_t;

int     read_program (program_data_t *prog);
int     send_program (program_data_t *program);
int     send_command (cmd_t cmd);

#endif // CPU_PROGRAMMER_H