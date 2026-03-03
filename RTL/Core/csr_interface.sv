timeunit 1ns;
timeprecision 1ps;

import riscv_defines::*;

interface csr_interface ();
    csr_req_t       req;
    logic [31:0]    wdata;

    logic [31:0]    rdata;

    modport requester (
        input  rdata,

        output req,
        output wdata
    );

    modport completer (
        input  req,
        input  wdata,

        output rdata
    );
    
endinterface