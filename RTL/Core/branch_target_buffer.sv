timeunit 1ns;
timeprecision 1ps;

import riscv_defines::*;

module branch_target_buffer (
    input   logic                   clk,

    // Predict
    input   logic [31:0]            pc_f,
    output  logic                   btb_hit,
    output  logic [31:0]            pred_target,
    
    // Update
    input   logic [31:0]            pc_m,
    input   logic                   cflow_valid,
    input   logic                   cflow_taken,
    input   logic [31:0]            cflow_target
    
);

    (* ram_style="distributed" *) btb_entry_t btb_mem [TABLE_ENTRIES-1:0];
    
    initial begin
        foreach (btb_mem[i]) begin
            btb_mem[i] <= '0;
        end
    end
    
    logic                           pred_valid;
    logic [TAG_WIDTH-1:0]           pred_tag;
    logic [31:0]                    pred_tgt;
        
    // Predict Logic
    logic [INDEX_WIDTH-1:0]         predict_index;
    assign                          predict_index   = pc_f[2 +: INDEX_WIDTH];
    
    always_comb begin
        {pred_valid, pred_tag, pred_tgt} = btb_mem[predict_index];
        btb_hit     = pred_valid && (pred_tag == pc_f[31 -: TAG_WIDTH]);
        pred_target = pred_tgt;
    end
    
    // Update Logic
    logic [INDEX_WIDTH-1:0]         update_index;
    assign                          update_index    = pc_m[2 +: INDEX_WIDTH];
    
    btb_entry_t                     update_entry;
    always_comb begin
        update_entry.valid  = 1'b1;
        update_entry.tag    = pc_m[31 -: TAG_WIDTH];
        update_entry.target = cflow_target;
    end
    
    always_ff@(posedge clk) begin
        if (cflow_valid && cflow_taken) begin
            btb_mem[update_index]   <= update_entry;
        end
    end

endmodule