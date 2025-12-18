#include "cpu_programmer.h"
#include "serial_port.h"

static int send_byte(uint8_t data, int current_checksum) {
    if (current_checksum == -1)         return -1;
    if (serial_write_byte(data) != 0)   return -1;
    
    return (current_checksum + data) & 0xFF;
}

int read_program (uint32_t *data, uint32_t *len) {
    FILE *fp = fopen("../program.hex", "r");

    uint32_t    index   = 0;
    uint32_t    line    = 0;

    if (fp == NULL) {
        printf("Failed to Read Program.\n");
        return -1;
    }
    else {
        while (index < MAX_PROG_SIZE && (fscanf(fp, "%x", &line) == 1)) {
            data[index] = line;
            index++;
        }

        *len = index;
        fclose(fp);
    }

    return 0;
}

int send_chunk (uint32_t addr, uint32_t *data, uint8_t len) {
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

int send_command (cmd_t cmd) {
    if (cmd == CMD_WRITE) {
        uint32_t program_data[MAX_PROG_SIZE];
        uint32_t total_len = 0;
        
        if (read_program(program_data, &total_len) == -1) return -1;
        
        uint32_t sent_len = 0;
        while (sent_len < total_len) {
            uint32_t chunk_len      = min(CHUNK_SIZE, total_len - sent_len);
            uint32_t current_addr   = BASE_ADDR + (sent_len * 4);
            
            if (send_chunk(current_addr, &program_data[sent_len], (uint8_t)chunk_len) == -1) {
                printf("Write Failed at 0x%08X.\n", current_addr);
                return -1;
            }
            
            sent_len += chunk_len;
            printf("Writing Program.. %d/%d.\r", sent_len, total_len);
        }
        printf("\nProgram Write Complete.\n");
    }
    else {
        int checksum = 0;
        checksum = send_byte(START_FLAG, checksum);     // START
        checksum = send_byte((uint8_t)cmd, checksum);   // CMD
        checksum = send_byte(0, checksum);              // LEN

        if (checksum == -1)                             return -1;
        if (serial_write_byte((uint8_t)checksum) != 0)  return -1;

        if (check_ack() == -1) {
            printf("Command Send FAIL.\n");
        }
        else {
            printf("Command Send OK.\n");
        }
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