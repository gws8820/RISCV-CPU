#ifndef PROGRAMMER_H
#define PROGRAMMER_H

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

// Parameter
#define CHUNK_SIZE  62      // Max words per packet

// CMD
typedef enum {
    CMD_RESET       = 0x01,
    CMD_WRITE       = 0x02,
    CMD_RUN         = 0x03,
    CMD_INPUT       = 0x04
} cmd_t;

#endif // PROGRAMMER_H