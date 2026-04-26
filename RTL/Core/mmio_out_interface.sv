timeunit 1ns;
timeprecision 1ps;

interface mmio_out_interface ();
    logic           boot_valid;
    logic           exit_valid;
    logic [7:0]     exit_code;
    logic           print_valid;
    logic [31:0]    print_data;

    modport source (
        output boot_valid,
        output exit_valid,
        output exit_code,
        output print_valid,
        output print_data
    );

    modport sink (
        input  boot_valid,
        input  exit_valid,
        input  exit_code,
        input  print_valid,
        input  print_data
    );

endinterface
