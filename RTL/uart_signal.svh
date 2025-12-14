typedef enum logic [1:0] {
    RX_SYNC_IDLE,
    RX_SYNC_START,
    RX_SYNC_DATA,
    RX_SYNC_STOP
} uart_rx_sync_t;

typedef enum logic [1:0] {
    TX_SYNC_IDLE,
    TX_SYNC_DATA,
    TX_SYNC_STOP
} uart_tx_sync_t;

typedef enum logic [2:0] {
    RX_CTRL_IDLE,
    RX_CTRL_CMD,
    RX_CTRL_LEN,
    RX_CTRL_PAYLOAD,
    RX_CTRL_CHECKSUM,
    RX_CTRL_BUSY
} uart_rx_ctrl_t;

typedef enum logic [2:0] {
    TX_CTRL_IDLE,
    TX_CTRL_RES,
    TX_CTRL_LEN,
    TX_CTRL_PAYLOAD,
    TX_CTRL_CHECKSUM
} uart_tx_ctrl_t;

typedef enum logic [7:0] {
    CMD_RESET   = 8'h01,
    CMD_WRITE   = 8'h02,
    CMD_RUN     = 8'h03
} uart_cmd_t;

typedef enum logic [7:0] {
    RES_STBY    = 8'h00,
    RES_ACK     = 8'h06,
    RES_NAK     = 8'h15,
    RES_PRINT   = 8'h80
} uart_res_t;

typedef struct packed {
    uart_res_t      res;
    logic [2:0]     len;
    logic [31:0]    data; // 4Byte Max
} uart_tx_entry_t;
