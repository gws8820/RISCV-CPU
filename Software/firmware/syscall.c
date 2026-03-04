#include <stdint.h>

#define PRINT_ADDR ((volatile uint32_t*)0xFFFF0000)

void putchar(int c) {
    *PRINT_ADDR = (uint32_t)c;
}

void print(const char* s) {
    while (*s)
        putchar(*s++);
}

void _exit(int code) {
    *PRINT_ADDR = (uint32_t)code;
    while (1);
}
