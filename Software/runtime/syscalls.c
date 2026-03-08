#include <stdint.h>
#include <stdarg.h>
#include <limits.h>

#define PRINT_ADDR ((volatile uint32_t*)0xFFFF0000)

/* ------------------------------------------------------------------ */
/* Basic I/O                                                           */
/* ------------------------------------------------------------------ */

#undef putchar
int putchar(int c)
{
    *PRINT_ADDR = (uint32_t)(unsigned char)c;
    return (unsigned char)c;
}

void print(const char *s)
{
    while (*s) putchar((unsigned char)*s++);
}

void _exit(int code)
{
    *PRINT_ADDR = (uint32_t)(0x100 | (code & 0xFF));
    while (1);
}

void exit(int code)
{
    _exit(code);
}

/* Benchmark timer hook: unused because timing is based on mcycle. */
void setStats(int enable)
{
    (void)enable;
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

    for (i = len; i < width; i++)
        putch(padc, putdat);

    while (len-- > 0)
        putch(buf[len], putdat);
}

static unsigned long getuint(va_list *ap, int lflag)
{
    return lflag ? va_arg(*ap, unsigned long) : va_arg(*ap, unsigned int);
}

static long getint(va_list *ap, int lflag)
{
    return lflag ? va_arg(*ap, long) : va_arg(*ap, int);
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
            for (i = slen; i < width; i++) putch(' ', putdat);
            while (*s) putch((unsigned char)*s++, putdat);
            break;
        }

        case 'd':
        case 'i':
            num = (unsigned long)getint(&ap, lflag);
            if ((long)num < 0) {
                putch('-', putdat);
                num = (unsigned long)(-(long)num);
                if (width > 0) width--;
            }
            base = 10;
            goto number;

        case 'u':
            num  = getuint(&ap, lflag);
            base = 10;
            goto number;

        case 'x':
        case 'p':
            num  = getuint(&ap, lflag);
            base = 16;
            goto number;

        case 'o':
            num  = getuint(&ap, lflag);
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
/* printf / vprintf                                                    */
/* ------------------------------------------------------------------ */

static void putch_stdout(int c, void **unused)
{
    (void)unused;
    *PRINT_ADDR = (uint32_t)(unsigned char)c;
}

int vprintf(const char *fmt, va_list ap)
{
    vprintfmt(putch_stdout, 0, fmt, ap);
    return 0;
}

int printf(const char *fmt, ...)
{
    va_list ap;
    va_start(ap, fmt);
    vprintfmt(putch_stdout, 0, fmt, ap);
    va_end(ap);
    return 0;
}

/* ------------------------------------------------------------------ */
/* sprintf / vsprintf                                                  */
/* ------------------------------------------------------------------ */

static void putch_str(int c, void **data)
{
    char **pstr = (char **)data;
    **pstr = (char)c;
    (*pstr)++;
}

int vsprintf(char *str, const char *fmt, va_list ap)
{
    char *str0 = str;
    vprintfmt(putch_str, (void **)&str, fmt, ap);
    *str = '\0';
    return (int)(str - str0);
}

int sprintf(char *str, const char *fmt, ...)
{
    va_list ap;
    va_start(ap, fmt);
    int len = vsprintf(str, fmt, ap);
    va_end(ap);
    return len;
}

/* ------------------------------------------------------------------ */
/* String and memory helpers used directly by Dhrystone.               */
/* ------------------------------------------------------------------ */

void *memcpy(void *dest, const void *src, size_t len)
{
    char       *d = (char *)dest;
    const char *s = (const char *)src;
    while (len--) *d++ = *s++;
    return dest;
}

void *memset(void *dest, int byte, size_t len)
{
    char *d = (char *)dest;
    while (len--) *d++ = (char)byte;
    return dest;
}

size_t strlen(const char *s)
{
    const char *p = s;
    while (*p) p++;
    return (size_t)(p - s);
}

size_t strnlen(const char *s, size_t n)
{
    const char *p = s;
    while (n-- && *p) p++;
    return (size_t)(p - s);
}

int strcmp(const char *s1, const char *s2)
{
    unsigned char c1, c2;
    do { c1 = (unsigned char)*s1++; c2 = (unsigned char)*s2++; } while (c1 && c1 == c2);
    return (int)c1 - (int)c2;
}

char *strcpy(char *dest, const char *src)
{
    char *d = dest;
    while ((*d++ = *src++));
    return dest;
}
