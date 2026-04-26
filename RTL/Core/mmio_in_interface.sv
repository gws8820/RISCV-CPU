timeunit 1ns;
timeprecision 1ps;

interface mmio_in_interface ();
    logic           valid;
    logic [7:0]     data;
    logic           ready;

    modport source (
        output valid,
        output data,
        input  ready
    );

    modport sink (
        input  valid,
        input  data,
        output ready
    );

endinterface
