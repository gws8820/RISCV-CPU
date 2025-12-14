#ifndef SERIAL_PORT_H
#define SERIAL_PORT_H

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <windows.h>
#include <conio.h>

// Parameter
#define START_FLAG      0xA5
#define TIMEOUT_MS      20000
#define BOOT_MSG        0xABCD1234

// RES
typedef enum {
    RES_ACK             = 0x06,
    RES_NAK             = 0x15,
    RES_PRINT           = 0x80
} res_t;

int     check_ack ();
int     print_log ();

int     serial_open (char *com_port);
void    serial_close ();

int     serial_write_byte (uint8_t data);
int     serial_read_byte (uint8_t *data);

#endif // SERIAL_PORT_H