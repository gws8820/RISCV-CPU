#include <stdint.h>
#include <stddef.h>

extern int      printf(const char *fmt, ...);
extern int      sprintf(char *str, const char *fmt, ...);
extern int      scanf(const char *fmt, ...);
extern int      getchar(void);
extern int      putchar(int c);
extern void     *memcpy(void *dest, const void *src, size_t len);
extern void     *memset(void *dest, int byte, size_t len);
extern size_t   strlen(const char *s);
extern int      strcmp(const char *s1, const char *s2);
extern char     *strcpy(char *dest, const char *src);
extern uint64_t get_cycle(void);
extern uint32_t time_us(void);
extern uint32_t time_ms(void);

void run_print(void) {
    printf("Hello, world! Cycle: %lu, Time: %u us\n", get_cycle(), time_us());
}

int main(void) {
    for (int i=0; i<10; i++) {
        run_print();
    }
    return 0;
}
