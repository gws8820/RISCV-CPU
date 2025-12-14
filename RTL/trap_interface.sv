timeunit 1ns;
timeprecision 1ps;

import riscv_defines::*;

interface trap_interface ();
    trap_req_t req;
    trap_res_t res;
    
    modport requester (
        input  res,
        output req
    );
    
    modport completer (
        input  req,
        output res
    );
    
endinterface