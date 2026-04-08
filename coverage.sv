class coverage;
    virtual cpu_bfm bfm;

    bit [15:0] cmd_in;
    instr_t    instr_set;

    bit [2:0]  Rn, Rd, Rm;
    bit [1:0]  sh_op;
    bit [7:0]  imm8;

    // ── covergroup: instruction opcode ────────────────────────────
    covergroup op_cov;

        cp_instr: coverpoint instr_set {
            bins mov_imm_hit   = {INSTR_MOV_IMM};
            bins mov_shift_hit = {INSTR_MOV_SHIFT};
            bins add_hit       = {INSTR_ADD};
            bins cmp_hit       = {INSTR_CMP};
            bins and_hit       = {INSTR_AND};
            bins mvn_hit       = {INSTR_MVN};
        }

        cp_instr_transitions: coverpoint instr_set {
            bins seq_mov_imm_to_add       = (INSTR_MOV_IMM   => INSTR_ADD);
            bins seq_mov_imm_to_cmp       = (INSTR_MOV_IMM   => INSTR_CMP);
            bins seq_mov_imm_to_and       = (INSTR_MOV_IMM   => INSTR_AND);
            bins seq_mov_imm_to_mvn       = (INSTR_MOV_IMM   => INSTR_MVN);
            bins seq_mov_imm_to_mov_shift = (INSTR_MOV_IMM   => INSTR_MOV_SHIFT);
            bins seq_add_to_cmp           = (INSTR_ADD       => INSTR_CMP);
            bins seq_add_to_and           = (INSTR_ADD       => INSTR_AND);
            bins seq_add_to_mvn           = (INSTR_ADD       => INSTR_MVN);
            bins seq_cmp_to_add           = (INSTR_CMP       => INSTR_ADD);
            bins seq_cmp_to_and           = (INSTR_CMP       => INSTR_AND);
            bins seq_cmp_to_mvn           = (INSTR_CMP       => INSTR_MVN);
            bins seq_same_instr[]         = (INSTR_MOV_IMM   => INSTR_MOV_IMM),
                                           (INSTR_MOV_SHIFT  => INSTR_MOV_SHIFT),
                                           (INSTR_ADD        => INSTR_ADD),
                                           (INSTR_CMP        => INSTR_CMP),
                                           (INSTR_AND        => INSTR_AND),
                                           (INSTR_MVN        => INSTR_MVN);
        }

    endgroup : op_cov

    // ── covergroup: register file ─────────────────────────────────
    covergroup reg_cov;

        cp_Rd: coverpoint Rd { bins rd_regs[] = {[0:7]}; }
        cp_Rn: coverpoint Rn { bins rn_regs[] = {[0:7]}; }
        cp_Rm: coverpoint Rm { bins rm_regs[] = {[0:7]}; }

        cp_Rd_eq_Rn: coverpoint (Rd == Rn) {
            bins overlap    = {1'b1};
            bins no_overlap = {1'b0};
        }
        cp_Rd_eq_Rm: coverpoint (Rd == Rm) {
            bins overlap    = {1'b1};
            bins no_overlap = {1'b0};
        }
        cp_Rn_eq_Rm: coverpoint (Rn == Rm) {
            bins overlap    = {1'b1};
            bins no_overlap = {1'b0};
        }

    endgroup : reg_cov

    // ── covergroup: shift operations ──────────────────────────────
    // FIX 6: cross uses class-level instr_set which is visible here;
    //         shift_cov is a separate covergroup so instr_set is in scope
    covergroup shift_cov;

        cp_sh_op: coverpoint sh_op {
            bins no_shift = {2'b00};
            bins lsl      = {2'b01};
            bins lsr      = {2'b10};
            bins asr      = {2'b11};
        }

        cp_instr_for_shift: coverpoint instr_set {
            bins mov_shift_hit = {INSTR_MOV_SHIFT};
            bins add_hit       = {INSTR_ADD};
            bins cmp_hit       = {INSTR_CMP};
            bins and_hit       = {INSTR_AND};
            bins mvn_hit       = {INSTR_MVN};
            // MOV_imm excluded: bits[4:3] are part of imm8 there
            ignore_bins imm_no_shift = {INSTR_MOV_IMM};
        }

        cp_instr_x_shift: cross cp_instr_for_shift, cp_sh_op;

    endgroup : shift_cov

    // ── covergroup: imm8 value (MOV_imm only) ─────────────────────
    covergroup imm8_cov;

        cp_imm8: coverpoint imm8 {
            bins zero     = {8'h00};
            bins max_pos  = {8'h7F};
            bins min_neg  = {8'h80};
            bins all_ones = {8'hFF};
            bins low_vals = {[8'h01 : 8'h0F]};
            bins mid_vals = {[8'h10 : 8'h6F]};
            bins high_pos = {[8'h70 : 8'h7E]};
            bins neg_vals = {[8'h81 : 8'hFE]};
        }

        cp_imm8_sign: coverpoint imm8[7] {
            bins positive = {1'b0};
            bins negative = {1'b1};
        }

    endgroup : imm8_cov

    // ── covergroup: flags (CMP only) ──────────────────────────────
    covergroup flag_cov;
        // Define explicit coverpoints for the signals
        cp_V: coverpoint bfm.V {
            bins ovf_clear = {1'b0};
            bins ovf_set   = {1'b1};
        }
        cp_N: coverpoint bfm.N {
            bins neg_clear = {1'b0};
            bins neg_set   = {1'b1};
        }
        cp_Z: coverpoint bfm.Z {
            bins zero_clear = {1'b0};
            bins zero_set   = {1'b1};
        }

        // Cross the NAMED coverpoints, not the interface signals directly
        cp_flags_cross: cross cp_V, cp_N, cp_Z {
            ignore_bins impossible_v1_z1 = 
                binsof(cp_V) intersect {1'b1} && 
                binsof(cp_Z) intersect {1'b1};
        }
    endgroup : flag_cov

    // ── covergroup: output boundary values ────────────────────────
    covergroup out_cov;

        cp_out: coverpoint bfm.out {
            bins zero     = {16'h0000};
            bins all_ones = {16'hFFFF};
            bins max_pos  = {16'h7FFF};
            bins min_neg  = {16'h8000};
            bins low_pos  = {[16'h0001 : 16'h00FF]};
            bins mid_pos  = {[16'h0100 : 16'h7FFE]};
            bins neg_vals = {[16'h8001 : 16'hFFFE]};
        }

    endgroup : out_cov

    function new(virtual cpu_bfm b);
        bfm       = b;
        op_cov    = new();
        reg_cov   = new();
        shift_cov = new();
        imm8_cov  = new();
        flag_cov  = new();
        out_cov   = new();
    endfunction : new

    task execute();
        forever begin
            @(posedge bfm.clk);

            if (bfm.load) begin
                cmd_in    = bfm.in;
                instr_set = instr_t'(cmd_in[15:11]);
                Rn        = cmd_in[10:8];
                Rd        = cmd_in[7:5];
                Rm        = cmd_in[2:0];
                sh_op     = cmd_in[4:3];
                imm8      = cmd_in[7:0];

                op_cov.sample();
                reg_cov.sample();
                shift_cov.sample();

                if (instr_set == INSTR_MOV_IMM)
                    imm8_cov.sample();
            end

            if (bfm.w) begin
                out_cov.sample();
                if (instr_set == INSTR_CMP)
                    flag_cov.sample();
            end

        end
    endtask : execute

endclass : coverage
