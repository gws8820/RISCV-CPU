#include "programmer.h"
#include "serial_port.h"
#include <ctype.h>

static int send_byte(uint8_t data, int current_checksum) {
    if (current_checksum == -1)         return -1;
    if (serial_write_byte(data) != 0)   return -1;
    
    return (current_checksum + data) & 0xFF;
}

static int select_program(char *program_path, size_t program_path_size, char *build_cmd, size_t build_cmd_size) {
    int app_input;

    while (1) {
        printf("Select Program Image\n");
        printf("\n");
        printf("1. Custom Firmware\n");
        printf("2. CoreMark Benchmark\n");
        printf("3. Dhrystone Benchmark\n");
        printf("4. RISC-V Test\n");
        printf("5. Back\n");
        printf("\n");
        printf("Mode (1-5):\t");

        if (scanf("%d", &app_input) != 1) {
            while (getchar() != '\n');
        }

        if (app_input == 1) {
            snprintf(program_path, program_path_size, "../build/firmware/firmware.hex");
            if (build_cmd != NULL && build_cmd_size > 0) {
                snprintf(build_cmd, build_cmd_size, "cd /d ..\\apps\\firmware && make -B");
            }
            return 0;
        }
        if (app_input == 2) {
            snprintf(program_path, program_path_size, "../build/coremark/coremark.hex");
            if (build_cmd != NULL && build_cmd_size > 0) {
                snprintf(build_cmd, build_cmd_size, "cd /d ..\\apps\\coremark && make -B");
            }
            return 0;
        }
        if (app_input == 3) {
            snprintf(program_path, program_path_size, "../build/dhrystone/dhrystone.hex");
            if (build_cmd != NULL && build_cmd_size > 0) {
                snprintf(build_cmd, build_cmd_size, "cd /d ..\\apps\\dhrystone && make -B");
            }
            return 0;
        }
        if (app_input == 4) {
            char test_name[128];

            printf("Enter riscv-test name (e.g. add, lw, mul):\t");
            if (scanf("%127s", test_name) != 1) {
                while (getchar() != '\n');
                continue;
            }

            snprintf(program_path, program_path_size, "../build/riscv-tests/%s.hex", test_name);
            if (build_cmd != NULL && build_cmd_size > 0) {
                snprintf(build_cmd, build_cmd_size, "cd /d ..\\apps\\riscv-tests && make -B TEST=%s run", test_name);
            }
            return 0;
        }

        if (app_input == 5) {
            return -1;
        }

        printf("Invalid Mode.\n");
        printf("\n");
        printf("----------------------------------------------\n");
        printf("\n");
    }
}

static int send_chunk(uint32_t addr, uint32_t *data, uint8_t len) {
    int checksum = 0;

    // Header
    checksum = send_byte(START_FLAG, checksum);         // START
    checksum = send_byte((uint8_t)CMD_WRITE, checksum); // CMD
    
    // LEN (Address + Data_Len * 4)
    uint8_t packet_len = 4 + len * 4;
    checksum = send_byte(packet_len, checksum);
    
    // ADDR
    uint8_t *addr_p = (uint8_t *) &addr;
    for (int i=0; i<4; i++) {
        checksum = send_byte(addr_p[i], checksum);
    }

    // DATA
    for (int i=0; i<len; i++) {
        uint8_t *data_p = (uint8_t *)&data[i];
        for (int j=0; j<4; j++) {
            checksum = send_byte(data_p[j], checksum);
        }
    }

    if (checksum == -1)                             return -1;
    if (serial_write_byte((uint8_t)checksum) != 0)  return -1;

    return check_ack();
}

static int flush_chunk (uint32_t chunk_base, uint32_t *chunk_data, uint32_t chunk_len, uint32_t *total_sent) {
    if (chunk_len == 0) return 0;

    uint32_t byte_addr =  chunk_base * 4;
    if (send_chunk(byte_addr, chunk_data, (uint8_t)chunk_len) == -1) {
        printf("Write Failed at 0x%08X.\n", byte_addr);
        return -1;
    }

    *total_sent += chunk_len;
    printf("Writing Program.. %d words.\r", *total_sent);
    return 0;
}

static int write_program(const char *program_path) {
    FILE        *fp;
    char        line[256];
    uint32_t    chunk_data[CHUNK_SIZE];
    uint32_t    chunk_base  = 0;
    uint32_t    chunk_len   = 0;
    uint32_t    cur_addr    = 0;
    uint32_t    total_sent  = 0;

    fp = fopen(program_path, "r");
    if (fp == NULL) {
        printf("Failed to Read Program: %s\n", program_path);
        return -1;
    }

    while (fgets(line, sizeof(line), fp)) {
        if (line[0] == '@') {
            if (flush_chunk(chunk_base, chunk_data, chunk_len, &total_sent) == -1) {
                fclose(fp);
                return -1;
            }
            sscanf(line + 1, "%x", &cur_addr);
            chunk_base  = cur_addr;
            chunk_len   = 0;
        } else {
            char *p = line;
            while (*p) {
                while (*p && isspace((unsigned char)*p)) p++;
                if (*p == '\0') break;

                char *endptr;
                unsigned long word = strtoul(p, &endptr, 16);
                if (endptr == p) break;

                chunk_data[chunk_len++] = (uint32_t)word;
                cur_addr++;

                if (chunk_len == CHUNK_SIZE) {
                    if (flush_chunk(chunk_base, chunk_data, chunk_len, &total_sent) == -1) {
                        fclose(fp);
                        return -1;
                    }
                    chunk_base  = cur_addr;
                    chunk_len   = 0;
                }

                p = endptr;
            }
        }
    }

    if (flush_chunk(chunk_base, chunk_data, chunk_len, &total_sent) == -1) {
        fclose(fp);
        return -1;
    }

    fclose(fp);
    printf("\nProgram Write Complete: %s\n", program_path);
    return 0;
}

static int build_program(void) {
    char program_path[260];
    char build_cmd[512];
    char write_now;
    int status;

    if (select_program(program_path, sizeof(program_path), build_cmd, sizeof(build_cmd)) != 0) {
        return -1;
    }

    printf("\n");
    printf("Building Program Image...\n");
    status = system(build_cmd);
    if (status != 0) {
        printf("Build Failed.\n");
        return -1;
    }

    printf("Build Complete: %s\n", program_path);
    printf("\n");
    printf("Write Program Now? (Y/N): ");
    if (scanf(" %c", &write_now) != 1) {
        while (getchar() != '\n');
        return 0;
    }
    if (write_now == 'y' || write_now == 'Y') {
        return write_program(program_path);
    }

    printf("Aborted.\n");
    return 0;
}

static int send_command (cmd_t cmd) {
    if (cmd == CMD_WRITE) {
        char program_path[260];
        if (select_program(program_path, sizeof(program_path), NULL, 0) != 0) {
            return -1;
        }
        return write_program(program_path);
    }
    else {
        int checksum = 0;
        checksum = send_byte(START_FLAG, checksum);     // START
        checksum = send_byte((uint8_t)cmd, checksum);   // CMD
        checksum = send_byte(0, checksum);              // LEN

        if (checksum == -1)                             return -1;
        if (serial_write_byte((uint8_t)checksum) != 0)  return -1;

        if (check_ack() == -1) {
            printf("Command Send Failed.\n");
        }
        else {
            printf("Command Send OK.\n");
        }
    }
    
    if (cmd == CMD_RUN) {
        cpu_console();
    }
    
    return 0;
}

int main () {
    int     com_input;
    char    com_port [20];

    printf("----------------------------------------------\n");
    printf("             RISC-V CPU Programmer\n");
    printf("----------------------------------------------\n");

    while (1) {
        printf("\n");
        printf("Enter COM PORT Number: \t");

        if (scanf("%d", &com_input) != 1) {
            while(getchar() != '\n');
            continue;
        }

        snprintf(com_port, sizeof(com_port), "\\\\.\\COM%d", com_input);

        if (serial_open(com_port) == 0) {
            break;
        }
    }

    int cmd_input;
    cmd_t cmd;

    while (1) {
        printf("\n");
        printf("----------------------------------------------\n");
        printf("\n");
        printf("Program Mode\n");
        printf("\n");
        printf("1. RESET\tReset System\n");
        printf("2. BUILD\tBuild Program Image\n");
        printf("3. WRITE\tWrite Program Image\n");
        printf("4. RUN\t\tRun Program\n");
        printf("5. EXIT\t\tEnd Program\n");
        printf("\n");
        printf("Mode (1-5):\t");
        
        if (scanf("%d", &cmd_input) != 1) {
            while(getchar() != '\n');
            continue;
        }
        printf("\n");
        printf("----------------------------------------------\n");
        printf("\n");

        if (cmd_input == 1) {
            cmd = CMD_RESET;
            send_command(cmd);
        }
        else if (cmd_input == 2) {
            build_program();
        }
        else if (cmd_input == 3) {
            cmd = CMD_WRITE;
            send_command(cmd);
        }
        else if (cmd_input == 4) {
            cmd = CMD_RUN;
            send_command(cmd);
        }
        else if (cmd_input == 5) {
            serial_close();
            printf("Goodbye.\n");
            return 0;
        }
        else {
            printf("Invalid Mode.\n");
        }
    }

    serial_close();
    return 0;
}