#include <stdint.h>

extern int printf(const char *fmt, ...);
extern void _exit(int code);

int main(void) {
    int a = 30;
    int b = 20;
    int c = a * b;
    printf("c = %d\n", c);
    _exit(0);

    return 0;
}
