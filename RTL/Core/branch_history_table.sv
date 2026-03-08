timeunit 1ns;
timeprecision 1ps;

import riscv_defines::*;

module branch_history_table (
    input   logic           start,
    input   logic           clk,

    // Predict
    input   logic [31:0]    pc_f,
    output  logic           bht_taken,

    // Update
    input   logic [31:0]    pc_e,
    input   logic           is_branch,
    input   logic           cflow_taken
);

    // Enum arrays cannot be inferred as Distributed RAM by Vivado
    (* ram_style="distributed" *) logic [$bits(bht_state_t)-1:0] bht_mem [0:TABLE_ENTRIES-1];
    initial foreach (bht_mem[i]) bht_mem[i] = $bits(bht_state_t)'(WEAKLY_NOT_TAKEN);

    logic [INDEX_WIDTH-1:0] init_cnt;
    logic                   init_done;

    // Predict Logic
    logic [INDEX_WIDTH-1:0] predict_index;
    assign predict_index = pc_f[2 +: INDEX_WIDTH];
    assign bht_taken = init_done && bht_mem[predict_index][1];

    // Update Logic
    logic [INDEX_WIDTH-1:0] update_index;
    assign update_index = pc_e[2 +: INDEX_WIDTH];

    always_ff@(posedge clk) begin
        if (!start) begin
            init_cnt                <= '0;
            init_done               <= 0;
        end
        else if (!init_done) begin
            bht_mem[init_cnt]       <= $bits(bht_state_t)'(WEAKLY_NOT_TAKEN);
            if (init_cnt == (TABLE_ENTRIES - 1))
                init_done           <= 1;
            else
                init_cnt            <= init_cnt + 1;
        end
        else if (is_branch) begin
            case (bht_state_t'(bht_mem[update_index]))
                STRONGLY_NOT_TAKEN: bht_mem[update_index] <= $bits(bht_state_t)'(cflow_taken ? WEAKLY_NOT_TAKEN : STRONGLY_NOT_TAKEN);
                WEAKLY_NOT_TAKEN:   bht_mem[update_index] <= $bits(bht_state_t)'(cflow_taken ? WEAKLY_TAKEN     : STRONGLY_NOT_TAKEN);
                WEAKLY_TAKEN:       bht_mem[update_index] <= $bits(bht_state_t)'(cflow_taken ? STRONGLY_TAKEN   : WEAKLY_NOT_TAKEN);
                STRONGLY_TAKEN:     bht_mem[update_index] <= $bits(bht_state_t)'(cflow_taken ? STRONGLY_TAKEN   : WEAKLY_TAKEN);
            endcase
        end
    end
    
endmodule