timeunit 1ns;
timeprecision 1ps;

import riscv_defines::*;

interface csr_interface ();
    csr_pkt_t       pkt;
    logic [31:0]    wdata;
    trap_req_t      trap;
    
    logic [31:0]    rdata;
    
    modport requester (
        input  rdata,
        
        output pkt,
        output wdata,
        output trap
    );
    
    modport completer (
        input  pkt,
        input  wdata,
        input  trap,
        
        output rdata
    );
    
endinterface