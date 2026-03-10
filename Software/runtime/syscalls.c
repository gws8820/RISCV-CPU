#include <stdint.h>
#include <stdarg.h>
#include <limits.h>

#ifndef CPU_FREQ_HZ
#define CPU_FREQ_HZ 100000000u
#endif
#define CYCLES_PER_US (CPU_FREQ_HZ/1000000u)
#define CYCLES_PER_MS (CPU_FREQ_HZ/1000u)

#define PRINT_ADDR ((volatile uint32_t*)0xFFFF0000)
#define INPUT_ADDR ((volatile uint32_t*)0xFFFF0004)

/* ------------------------------------------------------------------ */
/* Basic I/O                                                           */
/* ------------------------------------------------------------------ */

static int _ungetch_buf = -1;

#undef getchar
int getchar(void)
{
    if (_ungetch_buf != -1) {
        int c = _ungetch_buf;
        _ungetch_buf = -1;
        return c;
    }
    uint32_t c;
    do { c = *INPUT_ADDR; } while (c == 0xFFFFFFFFU);
    return (int)(c & 0xFF);
}

static void ungetch(int c)
{
    _ungetch_buf = c;
}

#undef putchar
int putchar(int c)
{
    *PRINT_ADDR = (uint32_t)(unsigned char)c;
    return (unsigned char)c;
}

#undef _exit
void _exit(int code)
{
    *PRINT_ADDR = (uint32_t)(0x100 | (code & 0xFF));
    while (1);
}


/* Benchmark timer hook: unused because timing is based on mcycle. */
void setStats(int enable)
{
    (void)enable;
}

/* ------------------------------------------------------------------ */
/* Time functions (100MHz based)                                       */
/* ------------------------------------------------------------------ */

uint64_t get_cycle(void)
{
#if __riscv_xlen == 64
    uint64_t x;
    __asm__ volatile ("rdcycle %0" : "=r"(x));
    return x;
#else
    uint32_t hi, lo, hi2;
    __asm__ volatile ("rdcycleh %0" : "=r"(hi));
    __asm__ volatile ("rdcycle %0"  : "=r"(lo));
    __asm__ volatile ("rdcycleh %0" : "=r"(hi2));
    if (hi != hi2) {
        __asm__ volatile ("rdcycle %0"  : "=r"(lo));
        hi = hi2;
    }
    return ((uint64_t)hi << 32) | lo;
#endif
}

uint32_t time_us(void)
{
    uint32_t lo;
    __asm__ volatile ("rdcycle %0" : "=r"(lo));
    return lo / (uint32_t)CYCLES_PER_US;
}

uint32_t time_ms(void)
{
    uint32_t lo;
    __asm__ volatile ("rdcycle %0" : "=r"(lo));
    return lo / (uint32_t)CYCLES_PER_MS;
}

/* ------------------------------------------------------------------ */
/* scanf                                                               */
/* ------------------------------------------------------------------ */

#undef scanf
int scanf(const char *fmt, ...)
{
    va_list ap;
    va_start(ap, fmt);
    int matched = 0;

    while (*fmt) {
        if (*fmt != '%') {
            if (*fmt == ' ' || *fmt == '\t' || *fmt == '\n') {
                int c = getchar();
                while (c == ' ' || c == '\t' || c == '\n' || c == '\r') c = getchar();
                ungetch(c);
            } else {
                int c = getchar();
                if (c != *fmt) { ungetch(c); break; }
            }
            fmt++;
            continue;
        }
        fmt++;

        int width = 0;
        while (*fmt >= '0' && *fmt <= '9') width = width * 10 + (*fmt++ - '0');

        switch (*fmt++) {
        case 'd': case 'i': {
            int neg = 0, val = 0;
            int c = getchar();
            while (c == ' ' || c == '\t' || c == '\n' || c == '\r') c = getchar();
            if (c == '-') { neg = 1; c = getchar(); }
            while (c >= '0' && c <= '9') { val = val * 10 + (c - '0'); c = getchar(); }
            ungetch(c);
            *va_arg(ap, int*) = neg ? -val : val;
            matched++;
            break;
        }
        case 'u': {
            unsigned val = 0;
            int c = getchar();
            while (c == ' ' || c == '\t' || c == '\n' || c == '\r') c = getchar();
            while (c >= '0' && c <= '9') { val = val * 10 + (c - '0'); c = getchar(); }
            ungetch(c);
            *va_arg(ap, unsigned*) = val;
            matched++;
            break;
        }
        case 'x': {
            unsigned val = 0;
            int c = getchar();
            while (c == ' ' || c == '\t' || c == '\n' || c == '\r') c = getchar();
            while ((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F')) {
                val = val * 16 + (c >= 'a' ? c - 'a' + 10 : c >= 'A' ? c - 'A' + 10 : c - '0');
                c = getchar();
            }
            ungetch(c);
            *va_arg(ap, unsigned*) = val;
            matched++;
            break;
        }
        case 'c': {
            *va_arg(ap, char*) = (char)getchar();
            matched++;
            break;
        }
        case 's': {
            char *s = va_arg(ap, char*);
            int c = getchar();
            while (c == ' ' || c == '\t' || c == '\n' || c == '\r') c = getchar();
            int n = 0;
            while (c != ' ' && c != '\t' && c != '\n' && c != '\r' && c != '\0') {
                if (width == 0 || n < width) *s++ = (char)c;
                n++;
                c = getchar();
            }
            ungetch(c);
            *s = '\0';
            matched++;
            break;
        }
        default:
            break;
        }
    }

    va_end(ap);
    return matched;
}

/* ------------------------------------------------------------------ */
/* Shared formatter used by printf/sprintf via a putch callback.       */
/* ------------------------------------------------------------------ */

static void printnum(void (*putch)(int, void **), void **putdat,
                     unsigned long num, unsigned base,
                     int width, int padc)
{
    char buf[sizeof(unsigned long) * CHAR_BIT];
    int  len = 0;
    int  i;

    do {
        unsigned digit = (unsigned)(num % base);
        buf[len++] = (char)(digit < 10 ? '0' + digit : 'a' - 10 + digit);
        num /= base;
    } while (num);

    if (padc != '-') {
        for (i = len; i < width; i++)
            putch(padc, putdat);
    }
    for (i = len - 1; i >= 0; i--)
        putch(buf[i], putdat);
    if (padc == '-') {
        for (i = len; i < width; i++)
            putch(' ', putdat);
    }
}

static void vprintfmt(void (*putch)(int, void **), void **putdat,
                      const char *fmt, va_list ap)
{
    int           ch;
    unsigned long num;
    int           base, lflag, width;
    char          padc;

    while (1) {
        while ((ch = *(const unsigned char *)fmt) != '%') {
            if (ch == '\0') return;
            fmt++;
            putch(ch, putdat);
        }
        fmt++;

        padc  = ' ';
        width = -1;
        lflag = 0;

    reswitch:
        ch = *(const unsigned char *)fmt++;
        switch (ch) {

        case '-':
            padc = '-';
            goto reswitch;
        case '0':
            padc = '0';
            goto reswitch;

        case '1': case '2': case '3': case '4': case '5':
        case '6': case '7': case '8': case '9':
            width = 0;
            do {
                width = width * 10 + (ch - '0');
                ch = *(const unsigned char *)fmt++;
            } while (ch >= '0' && ch <= '9');
            fmt--;
            goto reswitch;

        case '*':
            width = va_arg(ap, int);
            goto reswitch;

        case 'l':
            lflag = 1;
            goto reswitch;

        case 'c':
            putch(va_arg(ap, int), putdat);
            break;

        case 's': {
            const char *s = va_arg(ap, const char *);
            const char *p;
            int slen = 0;
            int i;
            if (!s) s = "(null)";
            p = s;
            while (*p++) slen++;
            if (padc != '-') {
                for (i = slen; i < width; i++) putch(' ', putdat);
            }
            while (*s) putch((unsigned char)*s++, putdat);
            if (padc == '-') {
                for (i = slen; i < width; i++) putch(' ', putdat);
            }
            break;
        }

        case 'd':
        case 'i':
            num = (unsigned long)(lflag ? va_arg(ap, long) : va_arg(ap, int));
            if ((long)num < 0) {
                putch('-', putdat);
                num = (unsigned long)(-(long)num);
                if (width > 0) width--;
            }
            base = 10;
            goto number;

        case 'u':
            num  = lflag ? va_arg(ap, unsigned long) : va_arg(ap, unsigned int);
            base = 10;
            goto number;

        case 'x':
        case 'p':
            num  = lflag ? va_arg(ap, unsigned long) : va_arg(ap, unsigned int);
            base = 16;
            goto number;

        case 'f': {
            double dval = va_arg(ap, double);
            long ipart;
            unsigned long fpart;
            if (dval < 0.0) { putch('-', putdat); dval = -dval; }
            ipart = (long)dval;
            fpart = (unsigned long)((dval - (double)ipart) * 1000.0 + 0.5);
            if (fpart >= 1000) { ipart++; fpart -= 1000; }
            printnum(putch, putdat, (unsigned long)ipart, 10, width > 0 ? width : 1, padc);
            putch('.', putdat);
            printnum(putch, putdat, fpart, 10, 3, '0');
            break;
        }

        case 'o':
            num  = lflag ? va_arg(ap, unsigned long) : va_arg(ap, unsigned int);
            base = 8;
            goto number;

        number:
            printnum(putch, putdat, num, (unsigned)base, width, padc);
            break;

        case '%':
            putch('%', putdat);
            break;

        default:
            putch('%', putdat);
            putch(ch,  putdat);
            break;
        }
    }
}

/* ------------------------------------------------------------------ */
/* printf                                                              */
/* ------------------------------------------------------------------ */

static void putch_stdout(int c, void **unused)
{
    (void)unused;
    *PRINT_ADDR = (uint32_t)(unsigned char)c;
}

#undef printf
int printf(const char *fmt, ...)
{
    va_list ap;
    va_start(ap, fmt);
    vprintfmt(putch_stdout, 0, fmt, ap);
    va_end(ap);
    return 0;
}

#undef vprintf
int vprintf(const char *fmt, va_list ap)
{
    vprintfmt(putch_stdout, 0, fmt, ap);
    return 0;
}

/* ------------------------------------------------------------------ */
/* sprintf                                                             */
/* ------------------------------------------------------------------ */

static void putch_str(int c, void **data)
{
    char **pstr = (char **)data;
    **pstr = (char)c;
    (*pstr)++;
}

#undef sprintf
int sprintf(char *str, const char *fmt, ...)
{
    va_list ap;
    char *str0 = str;
    va_start(ap, fmt);
    vprintfmt(putch_str, (void **)&str, fmt, ap);
    va_end(ap);
    *str = '\0';
    return (int)(str - str0);
}

/* ------------------------------------------------------------------ */
/* String and memory helpers used directly by Dhrystone.               */
/* ------------------------------------------------------------------ */

#undef memcpy
void *memcpy(void *dest, const void *src, size_t len)
{
    char       *d = (char *)dest;
    const char *s = (const char *)src;
    while (len--) *d++ = *s++;
    return dest;
}

#undef memset
void *memset(void *dest, int byte, size_t len)
{
    char *d = (char *)dest;
    while (len--) *d++ = (char)byte;
    return dest;
}

#undef strlen
size_t strlen(const char *s)
{
    const char *p = s;
    while (*p) p++;
    return (size_t)(p - s);
}

#undef strcmp
int strcmp(const char *s1, const char *s2)
{
    unsigned char c1, c2;
    do { c1 = (unsigned char)*s1++; c2 = (unsigned char)*s2++; } while (c1 && c1 == c2);
    return (int)c1 - (int)c2;
}

#undef strcpy
char *strcpy(char *dest, const char *src)
{
    char *d = dest;
    while ((*d++ = *src++));
    return dest;
}
