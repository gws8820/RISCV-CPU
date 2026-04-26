timeunit 1ns;
timeprecision 1ps;

interface memory_init_interface ();
    logic           write_enable;
    logic [31:0]    write_addr;
    logic [31:0]    write_data;

    modport source (
        output write_enable,
        output write_addr,
        output write_data
    );

    modport sink (
        input  write_enable,
        input  write_addr,
        input  write_data
    );

endinterface
