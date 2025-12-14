#include "cpu_programmer.h"
#include "serial_port.h"

static int send_byte(uint8_t data, int current_checksum) {
    if (current_checksum == -1)         return -1;
    if (serial_write_byte(data) != 0)   return -1;
    
    return (current_checksum + data) & 0xFF;
}

int read_program (program_data_t *prog) {
    FILE *fp = fopen("../program.hex", "r");

    uint8_t     index   = 0;
    uint32_t    line    = 0;

    if (fp == NULL) {
        printf("Failed to Read Program.\n");
        return -1;
    }
    else {
        while (index < 64 && (fscanf(fp, "%x", &line) == 1)) {
            prog->data[index] = line;
            index++;
        }

        prog->len     = 4 + index * 4;
        fclose(fp);
    }

    return 0;
}

int send_program (program_data_t *program) {
    int             checksum = 0;
    uint8_t         index = 0;

    checksum = send_byte(program->len, checksum);           // LEN
    
    uint32_t addr   = BASE_ADDR;
    uint8_t *addr_p = (uint8_t *) &addr;
    for (int i=0; i<4; i++) {
        checksum = send_byte(addr_p[i], checksum);          // ADDR
    }

    while (index < (program->len - 4)/4) {
        uint8_t *data_p = (uint8_t *)&program->data[index];
        for (int i=0; i<4; i++) {
            checksum = send_byte(data_p[i], checksum);      // DATA
        }
        index++;
    }

    return checksum;
}

int send_command (cmd_t cmd) {
    int checksum = 0;

    checksum = send_byte(START_FLAG, checksum);             // START
    
    checksum = send_byte((uint8_t)cmd, checksum);           // CMD

    if (cmd == CMD_WRITE) {
        program_data_t      prog = {0};
        if (read_program(&prog) == -1)  return -1;
        
        int prog_checksum   = send_program(&prog);
        if (prog_checksum == -1)        return -1;
        checksum            = (checksum + prog_checksum) & 0xFF;
    }
    else {  // CMD_RESET or CMD_RUN
        checksum = send_byte(0, checksum);                  // LEN
    }

    if (checksum == -1)                             return -1;
    if (serial_write_byte((uint8_t)checksum) != 0)  return -1;

    if (check_ack() == -1) {
        printf("Command Send FAIL.\n");
    }
    else {
        printf("Command Send OK.\n");
    }
    
    if (cmd == CMD_RUN) {
        print_log();
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
        printf("2. WRITE\tWrite System with program.hex\n");
        printf("3. RUN\t\tRun System & Print Log\n");
        printf("4. EXIT\t\tEnd Program\n");
        printf("\n");
        printf("Mode (1-4):\t");
        
        if (scanf("%d", &cmd_input) != 1) {
            while(getchar() != '\n');
            continue;
        }
        printf("\n");
        printf("----------------------------------------------\n");
        printf("\n");

        cmd = (cmd_t)cmd_input;

        if (cmd == CMD_EXIT) {
            serial_close();
            printf("Goodbye.\n");
            return 0;
        }
        else if (cmd == CMD_RESET || cmd == CMD_WRITE || cmd == CMD_RUN) {
            send_command(cmd);
        }
        else {
            printf("Invalid Mode.\n");
        }
    }

    serial_close();
    return 0;
}