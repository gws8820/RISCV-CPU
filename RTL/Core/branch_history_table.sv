timeunit 1ns;
timeprecision 1ps;

import riscv_defines::*;

module branch_history_table (
    input   logic           clk,
    
    // Predict
    input   logic [31:0]    pc_f,
    output  logic           bht_taken,
    
    // Update
    input   logic [31:0]    pc_m,
    input   logic           cflow_valid,
    input   logic           cflow_taken
    
);

    (* ram_style="distributed" *) bht_state_t bht_mem [TABLE_ENTRIES-1:0];
    
    initial begin
        foreach (bht_mem[i]) begin
            bht_mem[i] <= WEAKLY_NOT_TAKEN;
        end
    end
    
    // Predict Logic
    logic [INDEX_WIDTH-1:0] predict_index;
    assign predict_index = pc_f[2 +: INDEX_WIDTH];
    assign bht_taken = bht_mem[predict_index][1];
    
    // Update Logic
    logic [INDEX_WIDTH-1:0] update_index;
    assign update_index = pc_m[2 +: INDEX_WIDTH];
    
    always_ff@(posedge clk) begin
        if (cflow_valid) begin
            case (bht_mem[update_index])
                STRONGLY_NOT_TAKEN: bht_mem[update_index] <= cflow_taken ? WEAKLY_NOT_TAKEN : STRONGLY_NOT_TAKEN;
                WEAKLY_NOT_TAKEN:   bht_mem[update_index] <= cflow_taken ? WEAKLY_TAKEN     : STRONGLY_NOT_TAKEN;
                WEAKLY_TAKEN:       bht_mem[update_index] <= cflow_taken ? STRONGLY_TAKEN   : WEAKLY_NOT_TAKEN;
                STRONGLY_TAKEN:     bht_mem[update_index] <= cflow_taken ? STRONGLY_TAKEN   : WEAKLY_TAKEN;
            endcase
        end
    end
    
endmodule