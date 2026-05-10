#ifndef RISCV_RUNTIME_H
#define RISCV_RUNTIME_H

#include <stddef.h>
#include <stdint.h>

int printf(const char *fmt, ...);
int sprintf(char *str, const char *fmt, ...);
int scanf(const char *fmt, ...);
int getchar(void);
int putchar(int c);
void *memcpy(void *dest, const void *src, size_t len);
void *memset(void *dest, int byte, size_t len);
size_t strlen(const char *s);
int strcmp(const char *s1, const char *s2);
char *strcpy(char *dest, const char *src);
uint64_t get_cycle(void);
uint32_t time_us(void);
uint32_t time_ms(void);

#endif
