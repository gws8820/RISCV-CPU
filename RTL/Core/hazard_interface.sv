timeunit 1ns;
timeprecision 1ps;

import riscv_defines::*;

interface hazard_interface ();
    hazard_req_t req;
    hazard_res_t res;
    
    modport source (
        input  res,
        output req
    );
    
    modport sink (
        input  req,
        output res
    );
    
endinterface
