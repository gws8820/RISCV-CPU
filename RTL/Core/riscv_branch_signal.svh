localparam TABLE_ENTRIES    = 128;
localparam INDEX_WIDTH      = $clog2(TABLE_ENTRIES);
localparam TAG_WIDTH        = 32 - (INDEX_WIDTH + 2); // Byte Aligned
localparam BTB_ENTRY_WIDTH  = 1 + 2 + TAG_WIDTH + 32;

localparam RAS_SIZE         = 32;
localparam RAS_PTR_BITS     = $clog2(RAS_SIZE);

typedef enum logic [1:0] {
    STRONGLY_NOT_TAKEN      = 2'b00,
    WEAKLY_NOT_TAKEN        = 2'b01,
    WEAKLY_TAKEN            = 2'b10,
    STRONGLY_TAKEN          = 2'b11
} bht_state_t;

typedef enum logic [1:0] {
    ENRTY_INVALID,
    ENRTY_BRANCH,
    ENRTY_JUMP,
    ENRTY_RET
} entry_type_t;

typedef struct packed {
    logic                   valid;
    entry_type_t            etype;
    logic [TAG_WIDTH-1:0]   tag;
    logic [31:0]            target;
} btb_entry_t;