#ifndef CPU_PROGRAMMER_H
#define CPU_PROGRAMMER_H

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

// Parameter
#define BASE_ADDR       0x00
#define START_FLAG      0xA5
#define MAX_PROG_SIZE   4096    // 16KB IMEM
#define CHUNK_SIZE      62      // Max words per packet

// CMD
typedef enum {
    CMD_RESET       = 0x01,
    CMD_WRITE       = 0x02,
    CMD_RUN         = 0x03,
    CMD_EXIT        = 0x04
} cmd_t;

int     read_program (uint32_t *data, uint32_t *len);
int     send_chunk (uint32_t addr, uint32_t *data, uint8_t len);
int     send_command (cmd_t cmd);

#endif // CPU_PROGRAMMER_H