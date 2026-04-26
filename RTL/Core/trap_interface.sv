timeunit 1ns;
timeprecision 1ps;

import riscv_defines::*;

interface trap_interface ();
    trap_req_t req;
    trap_res_t res;
    
    modport source (
        input  res,
        output req
    );
    
    modport sink (
        input  req,
        output res
    );
    
endinterface
