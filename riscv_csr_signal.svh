localparam CSR_ADDR_MSTATUS     = 12'h300;
localparam CSR_ADDR_MIE         = 12'h304;
localparam CSR_ADDR_MTVEC       = 12'h305;
localparam CSR_ADDR_MSCRATCH    = 12'h340;
localparam CSR_ADDR_MEPC        = 12'h341;
localparam CSR_ADDR_MCAUSE      = 12'h342;
localparam CSR_ADDR_MTVAL       = 12'h343;
localparam CSR_ADDR_MIP         = 12'h344;
localparam CSR_ADDR_MHARTID     = 12'hF14;

localparam CSR_VALUE_MSTATUS    = 32'h0000_1800;
localparam CSR_VALUE_MTVEC      = 32'h0000_0040;
localparam CSR_VALUE_MHARTID    = 32'h0000_0000;

localparam CSR_MASK_MSTATUS     = 32'h0000_1888;
localparam CSR_MASK_MTVEC       = 32'hFFFF_FFFC;
localparam CSR_MASK_MIE         = 32'h0000_0888;
localparam CSR_MASK_MIP         = 32'h0000_0008;
localparam CSR_MASK_MEPC        = 32'hFFFF_FFFC;
localparam CSR_MASK_MCAUSE      = 32'hFFFF_FFFF;
localparam CSR_MASK_MTVAL       = 32'hFFFF_FFFF;
localparam CSR_MASK_MHARTID     = 32'h0000_0000;
localparam CSR_MASK_MSCRATCH    = 32'hFFFF_FFFF;

localparam MIE_BIT              = 3;
localparam MPIE_BIT             = 7;

typedef struct packed {
    logic [31:0]    mstatus;
    logic [31:0]    mtvec;
    logic [31:0]    mie;
    logic [31:0]    mip;
    logic [31:0]    mepc;
    logic [31:0]    mcause;
    logic [31:0]    mtval;
    logic [31:0]    mhartid;
    logic [31:0]    mscratch;
} csr_t;