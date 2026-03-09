#include <stdint.h>
#include <stddef.h>

extern int      printf(const char *fmt, ...);
extern int      sprintf(char *str, const char *fmt, ...);
extern int      scanf(const char *fmt, ...);
extern int      getchar(void);
extern int      putchar(int c);
extern void    *memcpy(void *dest, const void *src, size_t len);
extern void    *memset(void *dest, int byte, size_t len);
extern size_t   strlen(const char *s);
extern int      strcmp(const char *s1, const char *s2);
extern char    *strcpy(char *dest, const char *src);
extern uint64_t get_cycle(void);
extern uint32_t time_us(void);
extern uint32_t time_ms(void);

int main(void) {
    printf("Firmware start\n");

    // getchar / putchar
    printf("Type one char: ");
    int c = getchar();
    printf("\nYou typed: %c\n", c);

    // scanf
    char name[32]; int si = 0; unsigned uu = 0; unsigned hx = 0; char ch = 0;
    printf("Enter: <name> <int> <uint> <hex> <char>\n> ");
    scanf("%31s %d %u %x %c", name, &si, &uu, &hx, &ch);
    printf("name=%s len=%u, int=%d, uint=%u, hex=0x%x, ch=%c\n",
           name, (unsigned)strlen(name), si, uu, hx, ch);

    // strcmp / strcpy
    char copy[32];
    strcpy(copy, name);
    printf("strcmp=%d\n", strcmp(name, copy));

    return 0;
}
