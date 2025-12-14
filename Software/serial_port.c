#include "serial_port.h"

static HANDLE hSerial = INVALID_HANDLE_VALUE;

static int recv_frame (res_t *res, uint8_t *len, uint8_t *data) {
    uint8_t byte       = 0;
    int     checksum   = 0;

    // Wait for Start Flag
    while (1) {
        if (_kbhit()) {
            int ch = _getch();
            if (ch == 'q' || ch == 'Q') {
                return -2;
            }
        }

        if (serial_read_byte(&byte) != 0) {
            Sleep(1);
            continue;
        }

        if (byte == START_FLAG) {
            checksum = byte;
            break;
        }
    }

    // RES
    {
        ULONGLONG start = GetTickCount64();
        while (serial_read_byte(&byte) != 0) {
            if (_kbhit()) {
                int ch = _getch();
                if (ch == 'q' || ch == 'Q') return -2;
            }
            if ((GetTickCount64() - start) >= (ULONGLONG)TIMEOUT_MS) return -1;
            Sleep(1);
        }
    }
    *res        = (res_t)byte;
    checksum    += byte;

    // LEN
    {
        ULONGLONG start = GetTickCount64();
        while (serial_read_byte(len) != 0) {
            if (_kbhit()) {
                int ch = _getch();
                if (ch == 'q' || ch == 'Q') return -2;
            }
            if ((GetTickCount64() - start) >= (ULONGLONG)TIMEOUT_MS) return -1;
            Sleep(1);
        }
    }
    checksum    += *len;

    // DATA
    for (int i = 0; i < *len; i++) {
        ULONGLONG start = GetTickCount64();
        while (serial_read_byte(&data[i]) != 0) {
            if (_kbhit()) {
                int ch = _getch();
                if (ch == 'q' || ch == 'Q') return -2;
            }
            if ((GetTickCount64() - start) >= (ULONGLONG)TIMEOUT_MS) return -1;
            Sleep(1);
        }
        checksum += data[i];
    }

    // CHECKSUM
    {
        ULONGLONG start = GetTickCount64();
        while (serial_read_byte(&byte) != 0) {
            if (_kbhit()) {
                int ch = _getch();
                if (ch == 'q' || ch == 'Q') return -2;
            }
            if ((GetTickCount64() - start) >= (ULONGLONG)TIMEOUT_MS) return -1;
            Sleep(1);
        }
    }
    if (((uint8_t)checksum) != byte)  return -1;

    return 0;
}

int check_ack () {
    res_t   res;
    uint8_t len     = 0;
    uint8_t data[256] = {0};

    if (recv_frame(&res, &len, data) != 0) {
        return -1;
    }

    return (res == RES_ACK) ? 0 : -1;
}

int print_log () {
    res_t   res;
    uint8_t len;
    uint8_t data[256];
    int     boot_flag = 0;

    printf("\n");
    printf("----------------------------------------------\n");
    printf("\n");
    printf("CPU Log Mode\n");
    printf("Press 'q' to Exit.\n");
    printf("\n");
    printf("----------------------------------------------\n");
    printf("\n");

    while (1) {
        int r = recv_frame(&res, &len, data);
        if (r == -2) {
            break;
        }

        if (r == 0) {
            if (res == RES_PRINT && len > 0) {
                if (!boot_flag && len == 4) {
                    uint32_t word =
                        ((uint32_t)data[0]) |
                        ((uint32_t)data[1] << 8) |
                        ((uint32_t)data[2] << 16) |
                        ((uint32_t)data[3] << 24);
                        
                    if (word == (uint32_t)BOOT_MSG) {
                        printf("CPU Startup Complete.\n");
                        printf("\n");
                        boot_flag = 1;
                        continue;
                    }
                }

                char buf[5] = {0,};

                for (int i = 0; i < len; i++) {
                    buf[i] = (char)data[i];
                }
                buf[len] = '\0';

                printf("%s\n", buf);
            }
        }
        else {
            Sleep(1);
        }
    }

    printf("\n");
    printf("Exit Logging.\n");
    return 0;
}

int serial_open (char *com_port) {
    if (hSerial != INVALID_HANDLE_VALUE) {
        serial_close();
    }

    // Open Port (CreateFileA)
    hSerial = CreateFileA(
        com_port,
        GENERIC_READ | GENERIC_WRITE,
        0,
        NULL,
        OPEN_EXISTING,
        0,
        NULL
    );

    if (hSerial == INVALID_HANDLE_VALUE) {
        printf("Fail To Open Serial Port.\n");
        return -1;
    }

    // DCB Settings (SetCommState)
    DCB dcbSerialParams = {0};
    dcbSerialParams.DCBlength = sizeof(dcbSerialParams);
    
    if (!GetCommState(hSerial, &dcbSerialParams)) {
        printf("Fail To Get Serial Port State.\n");
        CloseHandle(hSerial);
        hSerial = INVALID_HANDLE_VALUE;
        return -1;
    }
    
    dcbSerialParams.BaudRate = CBR_115200;
    dcbSerialParams.ByteSize = 8;
    dcbSerialParams.StopBits = ONESTOPBIT;
    dcbSerialParams.Parity   = NOPARITY;
    
    if (!SetCommState(hSerial, &dcbSerialParams)) {
        printf("Fail To Set Serial Port State.\n");
        CloseHandle(hSerial);
        hSerial = INVALID_HANDLE_VALUE;
        return -1;
    }

    // Timeout Settings (SetCommTimeouts)
    COMMTIMEOUTS timeouts = {0};

    // Read
    timeouts.ReadIntervalTimeout = 50;         // Max time between arrival of two bytes
    timeouts.ReadTotalTimeoutConstant = 50;    // Constant time added to the total timeout
    timeouts.ReadTotalTimeoutMultiplier = 10;  // Multiplier time added for each byte
    // => Total Read Timeout = 50ms + (Requested Bytes * 10ms)

    // Write
    timeouts.WriteTotalTimeoutConstant = 50;   // Constant time added to the total timeout
    timeouts.WriteTotalTimeoutMultiplier = 10; // Multiplier time added for each byte
    // => Total Write Timeout = 50ms + (Requested Bytes * 10ms)
    
    if (!SetCommTimeouts(hSerial, &timeouts)) {
        printf("Fail To Set Serial Port Timeouts.\n");
        CloseHandle(hSerial);
        hSerial = INVALID_HANDLE_VALUE;
        return -1;
    }

    printf("Serial Port Opened Successfully.\n");
    return 0;
}

void serial_close () {
    if (hSerial != INVALID_HANDLE_VALUE) {
        CloseHandle(hSerial);
        hSerial = INVALID_HANDLE_VALUE;
        printf("Serial Port Successfully Closed.\n");
    }
    else {
        printf("Serial Port Already Closed.\n");
    }
}

int serial_write_byte (uint8_t data) {
    DWORD bytes_written = 0;

    if (hSerial == INVALID_HANDLE_VALUE) {
        return -1;
    }

    if (!WriteFile(hSerial, &data, 1, &bytes_written, NULL)) {
        return -1;
    }
    
    return (bytes_written == 1) ? 0 : -1;
}

int serial_read_byte (uint8_t *data) {
    DWORD bytes_read = 0;

    if (hSerial == INVALID_HANDLE_VALUE) {
        return -1;
    }

    if (!ReadFile(hSerial, data, 1, &bytes_read, NULL)) {
        return -1;
    }

    return (bytes_read == 1) ? 0 : -1;
}