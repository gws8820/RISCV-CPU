timeunit 1ns;
timeprecision 1ps;

import riscv_defines::*;

module branch_target_buffer (
    input   logic           clk,

    // Predict (IF)
    input   logic [31:0]    pc_f,
    output  logic           btb_hit,
    output  logic [31:0]    pred_target,
    
    // Update (ID)
    input   logic [31:0]    pc_d,
    input   logic           cflow_valid,
    input   logic           cflow_taken,
    input   logic [31:0]    cflow_target
    
);

    btb_entry_t btb_mem [TABLE_ENTRIES-1:0];
    
    initial begin
        foreach (btb_mem[i]) begin
            btb_mem[i] <= '0;
        end
    end
        
    // Predict Logic
    logic [INDEX_WIDTH-1:0] predict_index;
    assign                  predict_index   = pc_f[2 +: INDEX_WIDTH];
    
    always_comb begin
        btb_hit     = (btb_mem[predict_index].valid) && (btb_mem[predict_index].tag == pc_f[31 -: TAG_WIDTH]);
        pred_target = btb_mem[predict_index].target;
    end
    
    // Update Logic
    logic [INDEX_WIDTH-1:0] update_index;
    assign                  update_index    = pc_d[2 +: INDEX_WIDTH];
    
    always_ff@(posedge clk) begin
        if (cflow_valid && cflow_taken) begin
            btb_mem[update_index].valid     <= 1;
            btb_mem[update_index].tag       <= pc_d[31 -: TAG_WIDTH];
            btb_mem[update_index].target    <= cflow_target;
        end
    end

endmodule