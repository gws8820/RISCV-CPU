#include <stdint.h>
#include <stddef.h>

extern int printf(const char *fmt, ...);

typedef uint32_t (*muldiv_op_fn)(uint32_t a, uint32_t b);

typedef struct {
    const char   *name;
    muldiv_op_fn fn;
    uint32_t      a;
    uint32_t      b;
    uint32_t      expect;
} muldiv_case_t;

static uint32_t op_mul(uint32_t a, uint32_t b)
{
    uint32_t r;
    __asm__ volatile ("mul %0, %1, %2" : "=r"(r) : "r"(a), "r"(b));
    return r;
}

static uint32_t op_mulh(uint32_t a, uint32_t b)
{
    uint32_t r;
    __asm__ volatile ("mulh %0, %1, %2" : "=r"(r) : "r"(a), "r"(b));
    return r;
}

static uint32_t op_mulhsu(uint32_t a, uint32_t b)
{
    uint32_t r;
    __asm__ volatile ("mulhsu %0, %1, %2" : "=r"(r) : "r"(a), "r"(b));
    return r;
}

static uint32_t op_mulhu(uint32_t a, uint32_t b)
{
    uint32_t r;
    __asm__ volatile ("mulhu %0, %1, %2" : "=r"(r) : "r"(a), "r"(b));
    return r;
}

static uint32_t op_div(uint32_t a, uint32_t b)
{
    uint32_t r;
    __asm__ volatile ("div %0, %1, %2" : "=r"(r) : "r"(a), "r"(b));
    return r;
}

static uint32_t op_divu(uint32_t a, uint32_t b)
{
    uint32_t r;
    __asm__ volatile ("divu %0, %1, %2" : "=r"(r) : "r"(a), "r"(b));
    return r;
}

static uint32_t op_rem(uint32_t a, uint32_t b)
{
    uint32_t r;
    __asm__ volatile ("rem %0, %1, %2" : "=r"(r) : "r"(a), "r"(b));
    return r;
}

static uint32_t op_remu(uint32_t a, uint32_t b)
{
    uint32_t r;
    __asm__ volatile ("remu %0, %1, %2" : "=r"(r) : "r"(a), "r"(b));
    return r;
}

static int check_case(const muldiv_case_t *tc, int idx)
{
    uint32_t got = tc->fn(tc->a, tc->b);

    if (got != tc->expect) {
        printf("FAIL %s[%d]: a=0x%08x b=0x%08x got=0x%08x expect=0x%08x\n",
               tc->name, idx, tc->a, tc->b, got, tc->expect);
        return 1;
    }

    return 0;
}

static int check_back_to_back(void)
{
    uint32_t r0, r1, r2, r3;

    __asm__ volatile (
        "mul   %[r0], %[a0], %[b0]\n\t"
        "div   %[r1], %[a1], %[b1]\n\t"
        "mulhu %[r2], %[a2], %[b2]\n\t"
        "rem   %[r3], %[a3], %[b3]"
        : [r0] "=&r" (r0),
          [r1] "=&r" (r1),
          [r2] "=&r" (r2),
          [r3] "=&r" (r3)
        : [a0] "r" (0x12345678u), [b0] "r" (0x9abcdef0u),
          [a1] "r" (0xfffffff6u), [b1] "r" (0x00000003u),
          [a2] "r" (0xffffffffu), [b2] "r" (0xffffffffu),
          [a3] "r" (0xfffffff6u), [b3] "r" (0x00000003u)
    );

    if (r0 != 0x242d2080u || r1 != 0xfffffffdu ||
        r2 != 0xfffffffeu || r3 != 0xffffffffu) {
        printf("FAIL back-to-back: %08x %08x %08x %08x\n", r0, r1, r2, r3);
        return 1;
    }

    return 0;
}

int main(void)
{
    static const muldiv_case_t cases[] = {
        {"mul",    op_mul,    0x00000000u, 0x12345678u, 0x00000000u},
        {"mul",    op_mul,    0x00000003u, 0x00000007u, 0x00000015u},
        {"mul",    op_mul,    0xfffffff9u, 0x00000006u, 0xffffffd6u},
        {"mul",    op_mul,    0x12345678u, 0x9abcdef0u, 0x242d2080u},

        {"mulh",   op_mulh,   0xffffffffu, 0x00000002u, 0xffffffffu},
        {"mulh",   op_mulh,   0x80000000u, 0x00000002u, 0xffffffffu},
        {"mulh",   op_mulh,   0x80000000u, 0x80000000u, 0x40000000u},
        {"mulh",   op_mulh,   0x12345678u, 0x9abcdef0u, 0xf8cc93d6u},

        {"mulhsu", op_mulhsu, 0xffffffffu, 0xffffffffu, 0xffffffffu},
        {"mulhsu", op_mulhsu, 0x80000000u, 0x00000002u, 0xffffffffu},
        {"mulhsu", op_mulhsu, 0x80000000u, 0x80000000u, 0xc0000000u},
        {"mulhsu", op_mulhsu, 0x7fffffffu, 0xffffffffu, 0x7ffffffeu},

        {"mulhu",  op_mulhu,  0xffffffffu, 0xffffffffu, 0xfffffffeu},
        {"mulhu",  op_mulhu,  0x80000000u, 0x00000002u, 0x00000001u},
        {"mulhu",  op_mulhu,  0x80000000u, 0x80000000u, 0x40000000u},
        {"mulhu",  op_mulhu,  0x12345678u, 0x9abcdef0u, 0x0b00ea4eu},

        {"div",    op_div,    0x0000000au, 0x00000003u, 0x00000003u},
        {"div",    op_div,    0xfffffff6u, 0x00000003u, 0xfffffffdu},
        {"div",    op_div,    0x0000000au, 0xfffffffdu, 0xfffffffdu},
        {"div",    op_div,    0x80000000u, 0xffffffffu, 0x80000000u},
        {"div",    op_div,    0x12345678u, 0x00000000u, 0xffffffffu},

        {"divu",   op_divu,   0x0000000au, 0x00000003u, 0x00000003u},
        {"divu",   op_divu,   0xffffffffu, 0x00000002u, 0x7fffffffu},
        {"divu",   op_divu,   0x80000000u, 0x00000002u, 0x40000000u},
        {"divu",   op_divu,   0x12345678u, 0x00000000u, 0xffffffffu},

        {"rem",    op_rem,    0x0000000au, 0x00000003u, 0x00000001u},
        {"rem",    op_rem,    0xfffffff6u, 0x00000003u, 0xffffffffu},
        {"rem",    op_rem,    0x0000000au, 0xfffffffdu, 0x00000001u},
        {"rem",    op_rem,    0x80000000u, 0xffffffffu, 0x00000000u},
        {"rem",    op_rem,    0x12345678u, 0x00000000u, 0x12345678u},

        {"remu",   op_remu,   0x0000000au, 0x00000003u, 0x00000001u},
        {"remu",   op_remu,   0xffffffffu, 0x00000002u, 0x00000001u},
        {"remu",   op_remu,   0x80000000u, 0x00000002u, 0x00000000u},
        {"remu",   op_remu,   0x12345678u, 0x00000000u, 0x12345678u},
    };

    int failures = 0;
    int count = (int)(sizeof(cases) / sizeof(cases[0]));

    printf("muldiv self-test start\n");

    for (int i = 0; i < count; i++) {
        failures += check_case(&cases[i], i);
    }

    failures += check_back_to_back();

    if (failures) {
        printf("muldiv self-test failed: %d\n", failures);
        return failures;
    }

    printf("muldiv self-test passed: %d cases\n", count + 1);
    return 0;
}
