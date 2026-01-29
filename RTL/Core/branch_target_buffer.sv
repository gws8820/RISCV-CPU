timeunit 1ns;
timeprecision 1ps;

import riscv_defines::*;

module branch_target_buffer (
    input   logic                   clk,

    // Predict
    input   logic [31:0]            pc_f,
    input   logic                   ras_empty,
    input   logic [31:0]            ras_pop_addr,
    output  entry_type_t            pred_type,
    output  logic                   btb_hit,
    output  logic [31:0]            pred_target,
    
    // Update
    input   logic [31:0]            pc_e,
    input   cflow_mode_t            cflow_mode,
    input   cflow_hint_t            cflow_hint,
    input   logic                   cflow_taken,
    input   logic [31:0]            cflow_target
);

    (* ram_style="distributed" *) btb_entry_t btb_mem [0:TABLE_ENTRIES-1];
    
    initial begin
        foreach (btb_mem[i]) begin
            btb_mem[i]  <= '0;
        end
    end
    
    logic                           pred_valid;
    logic [TAG_WIDTH-1:0]           pred_tag;
    logic [31:0]                    pred_tgt;
    
    // Predict Logic
    logic [INDEX_WIDTH-1:0]         predict_index;
    assign                          predict_index   = pc_f[2 +: INDEX_WIDTH];
    
    always_comb begin
        {pred_valid, pred_type, pred_tag, pred_tgt} = btb_mem[predict_index];
        btb_hit = pred_valid && (pred_tag == pc_f[31 -: TAG_WIDTH]);
        
        if (pred_type == ENRTY_RET) begin
            pred_target = ras_empty ? pred_tgt : ras_pop_addr;
        end
        else begin
            pred_target = pred_tgt;
        end
    end
    
    // Update Logic
    logic                           cflow_valid;
    assign                          cflow_valid = (cflow_mode inside {CFLOW_BRANCH, CFLOW_JAL, CFLOW_JALR});

    btb_entry_t                     update_entry;
    entry_type_t                    update_type;

    logic [INDEX_WIDTH-1:0]         update_index;
    assign                          update_index    = pc_e[2 +: INDEX_WIDTH];

    always_comb begin
        if (cflow_valid) begin
            if (cflow_mode == CFLOW_BRANCH) begin
                update_type         = ENRTY_BRANCH;
            end
            else begin
                if (cflow_hint == CFHINT_RET) begin
                    update_type     = ENRTY_RET;
                end
                else begin
                    update_type     = ENRTY_JUMP;
                end
            end
        end
        else begin
            update_type             = ENRTY_INVALID;
        end
    end

    always_comb begin
        update_entry.valid  = cflow_valid ? 1 : 0;
        update_entry.etype  = update_type;
        update_entry.tag    = pc_e[31 -: TAG_WIDTH];
        update_entry.target = cflow_target;
    end
    
    always_ff@(posedge clk) begin
        if (cflow_valid && cflow_taken) begin
            btb_mem[update_index]   <= update_entry;
        end
    end

endmodule