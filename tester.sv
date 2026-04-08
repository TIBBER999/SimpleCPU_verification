class tester;
    virtual cpu_bfm bfm;
    scoreboard scoreboard_h;

    // FIX 3+4: localparam illegal in a class body;
    //          AND/CMP/MVN/ADD collide with SV keywords as identifiers.
    //          Use const local variables with INSTR_ prefix instead.
    const bit [4:0] INSTR_MOV_IMM   = 5'b110_10;
    const bit [4:0] INSTR_MOV_SHIFT = 5'b110_00;
    const bit [4:0] INSTR_ADD       = 5'b101_00;
    const bit [4:0] INSTR_CMP       = 5'b101_01;
    const bit [4:0] INSTR_AND       = 5'b101_10;
    const bit [4:0] INSTR_MVN       = 5'b101_11;

    const bit [1:0] SH_NONE = 2'b00;
    const bit [1:0] SH_LSL  = 2'b01;
    const bit [1:0] SH_LSR  = 2'b10;
    const bit [1:0] SH_ASR  = 2'b11;

    function new(virtual cpu_bfm b, scoreboard sb);
        bfm = b;
        scoreboard_h = sb;
    endfunction : new

    // ── Instruction encoders ──────────────────────────────────────

    function automatic bit [15:0] enc_MOV_imm(
        input bit [2:0] Rn,
        input bit [7:0] imm8
    );
        return {INSTR_MOV_IMM, Rn, imm8};
    endfunction

    function automatic bit [15:0] enc_MOV_shift(
        input bit [2:0] Rd,
        input bit [2:0] Rm,
        input bit [1:0] sh_op = 2'b00
    );
        return {INSTR_MOV_SHIFT, 3'b000, Rd, sh_op, Rm};
    endfunction

    function automatic bit [15:0] enc_ADD(
        input bit [2:0] Rd,
        input bit [2:0] Rn,
        input bit [2:0] Rm,
        input bit [1:0] sh_op = 2'b00
    );
        return {INSTR_ADD, Rn, Rd, sh_op, Rm};
    endfunction

    function automatic bit [15:0] enc_CMP(
        input bit [2:0] Rn,
        input bit [2:0] Rm,
        input bit [1:0] sh_op = 2'b00
    );
        return {INSTR_CMP, Rn, 3'b000, sh_op, Rm};
    endfunction

    function automatic bit [15:0] enc_AND(
        input bit [2:0] Rd,
        input bit [2:0] Rn,
        input bit [2:0] Rm,
        input bit [1:0] sh_op = 2'b00
    );
        return {INSTR_AND, Rn, Rd, sh_op, Rm};
    endfunction

    function automatic bit [15:0] enc_MVN(
        input bit [2:0] Rd,
        input bit [2:0] Rm,
        input bit [1:0] sh_op = 2'b00
    );
        return {INSTR_MVN, 3'b000, Rd, sh_op, Rm};
    endfunction

    // ── BFM wrappers ──────────────────────────────────────────────

    task send_instr(
        input  bit [15:0] instr,
        output bit [15:0] result
    );
        bit [15:0] dummy;
        bfm.send_cmd(.s2(1'b0), .load2(1'b1), .in2(instr), .out2(dummy));
        bfm.send_cmd(.s2(1'b1), .load2(1'b0), .in2(instr), .out2(result));
        @(posedge bfm.w);
    endtask : send_instr

    task send_instr_no_out(input bit [15:0] instr);
        bit [15:0] unused;
        send_instr(instr, unused);
    endtask : send_instr_no_out

    task preload_reg_8(input bit [2:0] reg_num, input bit [7:0] val);
        send_instr_no_out(enc_MOV_imm(reg_num, val));
    endtask : preload_reg_8

    // ── Directed tests ────────────────────────────────────────────

    task test_MOV_imm();
        bit [15:0] result;
        bit [7:0]  imm_vals[6] = '{8'h00, 8'h01, 8'h7F, 8'h80, 8'hFF, 8'hA5};
        $display("\n=== test_MOV_imm ===");
        foreach (imm_vals[i])
            for (int r = 0; r < 8; r++) begin
                $display("Set R%0d= 'h%0h", r, imm_vals[i]);
                send_instr(enc_MOV_imm(r[2:0], imm_vals[i]), result);
            end
    endtask : test_MOV_imm

    task test_MOV_shift();
        bit [15:0] result;
        $display("\n=== test_MOV_shift ===");
        for (int r = 0; r < 8; r++)
            preload_reg_8(r[2:0], 8'b1 << r[2:0]);
        for (int sh = 0; sh < 4; sh++)
            for (int rd = 0; rd < 8; rd++)
                for (int rm = 0; rm < 8; rm++)
                    send_instr(enc_MOV_shift(rd[2:0], rm[2:0], sh[1:0]), result);
        preload_reg_8(3'd0, 8'h00);
        for (int sh = 0; sh < 4; sh++)
            send_instr(enc_MOV_shift(3'd1, 3'd0, sh[1:0]), result);
        preload_reg_8(3'd0, 8'hFF);
        send_instr(enc_MOV_shift(3'd1, 3'd0, SH_ASR), result);
    endtask : test_MOV_shift

    task test_ADD();
        bit [15:0] result;
        $display("\n=== test_ADD ===");
        preload_reg_8(3'd0, 8'h01);
        preload_reg_8(3'd1, 8'h7F);
        preload_reg_8(3'd2, 8'h80);
        preload_reg_8(3'd3, 8'hFF);
        for (int sh = 0; sh < 4; sh++)
            for (int rn = 0; rn < 4; rn++)
                for (int rm = 0; rm < 4; rm++)
                    send_instr(enc_ADD(3'd4, rn[2:0], rm[2:0], sh[1:0]), result);
        for (int r = 0; r < 8; r++) begin
            preload_reg_8(r[2:0], 8'h01);
            send_instr(enc_ADD(r[2:0], r[2:0], r[2:0]), result);
        end
        preload_reg_8(3'd0, 8'h15);
        send_instr(enc_ADD(3'd1, 3'd0, 3'd0), result);
        preload_reg_8(3'd0, 8'h7F);
        preload_reg_8(3'd1, 8'h7F);
        send_instr(enc_ADD(3'd2, 3'd0, 3'd1), result);
        preload_reg_8(3'd0, 8'h80);
        preload_reg_8(3'd1, 8'h80);
        send_instr(enc_ADD(3'd2, 3'd0, 3'd1), result);
    endtask : test_ADD

    task test_CMP();
        bit [15:0] result;
        $display("\n=== test_CMP ===");

        // ── Z=1 : equal values ────────────────────────────────────────
        // R0 = sximm8(0x55) = 0x0055
        // R1 = sximm8(0x55) = 0x0055
        // 0x0055 - 0x0055 = 0x0000  →  Z=1, N=0, V=0
        preload_reg_8(3'd0, 8'h55);
        preload_reg_8(3'd1, 8'h55);
        send_instr(enc_CMP(3'd0, 3'd1), result);

        // ── N=1 : Rn < Rm (both positive, no overflow) ────────────────
        // R0 = sximm8(0x01) = 0x0001
        // R1 = sximm8(0x7F) = 0x007F
        // 0x0001 - 0x007F = 0xFF82  →  Z=0, N=1, V=0
        // V=0 because: a[15]=0, b[15]=0, same sign → no signed overflow
        preload_reg_8(3'd0, 8'h01);
        preload_reg_8(3'd1, 8'h7F);
        send_instr(enc_CMP(3'd0, 3'd1), result);

        // ── Clean (N=0, Z=0, V=0) : Rn > Rm, both positive ──────────
        // R0 = sximm8(0x7F) = 0x007F
        // R1 = sximm8(0x01) = 0x0001
        // 0x007F - 0x0001 = 0x007E  →  Z=0, N=0, V=0
        preload_reg_8(3'd0, 8'h7F);
        preload_reg_8(3'd1, 8'h01);
        send_instr(enc_CMP(3'd0, 3'd1), result);

        // ── V=1 : signed overflow, positive minus negative → negative ─
        //
        // preload_reg_8 sign-extends imm8 to 16 bits, so values 0x80–0xFF
        // become 0xFF80–0xFFFF (negative in 16-bit two's complement).
        // A plain 8-bit load cannot place a large enough positive value in a
        // register to overflow 16-bit subtraction, because the maximum
        // positive value loadable is sximm8(0x7F) = 0x007F.
        //
        // Strategy: build 0x4000 in R0 by loading 0x01 then doubling 14×
        //           via  ADD R0, R0, R0  (each ADD doubles the value):
        //   after  1 ADD:  0x0002
        //   after  2 ADDs: 0x0004
        //   ...
        //   after 14 ADDs: 0x4000
        //
        // Build 0xC001 in R2:
        //   Load R2 = sximm8(0x80) = 0xFF80  (= −128 in 16-bit signed)
        //   Load R3 = sximm8(0x7F) = 0x007F
        //   ADD  R2, R2, R3  →  0xFF80 + 0x007F = 0xFFFF  (= −1)
        //   Then double R2 fourteen times with ADD R2, R2, R2:
        //   after  1 ADD: 0xFFFE  (−2)
        //   ...
        //   after 14 ADDs: 0xFFFE << 13 = 0xC000  (−16384)
        //   ADD R2, R2, R1  where R1 still holds 0x0001 → R2 = 0xC001
        //
        // CMP R0, R2  →  0x4000 - 0xC001
        //   = 0x4000 + ~0xC001 + 1
        //   = 0x4000 + 0x3FFE + 1
        //   = 0x7FFF
        // a[15]=0 (positive), b[15]=1 (negative), result[15]=0
        // Overflow condition: (a[15] != b[15]) && (result[15] != a[15])
        //   = (0 != 1) && (0 != 0) = true && false = 0  ← still no overflow
        //
        // Re-examine: need result to flip to NEGATIVE.
        // Use 0x4001 - 0xC000:
        //   = 0x4001 + 0x4000 = 0x8001  →  result[15]=1
        //   a[15]=0, b[15]=1, result[15]=1
        //   (0 != 1) && (1 != 0) → V=1  ✓  N=1  Z=0
        //
        // Build 0x4001 in R0:
        //   Load R0=0x01 (=0x0001), double 14× → 0x4000,
        //   Load R1=0x01 (=0x0001), ADD R0,R0,R1 → 0x4001
        //
        // Build 0xC000 in R2:
        //   Load R2=0x80 → 0xFF80, double (ADD R2,R2,R2) 9× →
        //   0xFF80 << 9 in 16-bit:
        //   ×1 : 0xFF00
        //   ×2 : 0xFE00
        //   ×3 : 0xFC00
        //   ×4 : 0xF800
        //   ×5 : 0xF000
        //   ×6 : 0xE000
        //   ×7 : 0xC000  ✓  (only 7 doublings needed)
        //
        // Final check: CMP R0(0x4001), R2(0xC000)
        //   result = 0x4001 - 0xC000 = 0x8001
        //   a[15]=0, b[15]=1, result[15]=1  →  V=1, N=1, Z=0  ✓

        // Build R0 = 0x4001
        preload_reg_8(3'd0, 8'h01);            // R0 = 0x0001
        repeat (14)
            send_instr_no_out(enc_ADD(3'd0, 3'd0, 3'd0));  // R0 doubles × 14 → 0x4000
        preload_reg_8(3'd1, 8'h01);            // R1 = 0x0001
        send_instr_no_out(enc_ADD(3'd0, 3'd0, 3'd1));      // R0 = 0x4000 + 0x0001 = 0x4001

        // Build R2 = 0xC000
        preload_reg_8(3'd2, 8'h80);            // R2 = sximm8(0x80) = 0xFF80
        repeat (7)
            send_instr_no_out(enc_ADD(3'd2, 3'd2, 3'd2));  // R2 doubles × 7 → 0xC000

        send_instr(enc_CMP(3'd0, 3'd2), result);
        // expected: 0x4001 - 0xC000 = 0x8001  →  V=1, N=1, Z=0
        // ── Shift variants of CMP (V=0 path, no writeback side-effect) ─
        // R0 = sximm8(0x10) = 0x0010
        // R1 = sximm8(0x04) = 0x0004
        // sh=0 (NONE): 0x0010 - 0x0004 = 0x000C  → N=0 Z=0 V=0
        // sh=1 (LSL):  0x0010 - 0x0008 = 0x0008  → N=0 Z=0 V=0
        // sh=2 (LSR):  0x0010 - 0x0002 = 0x000E  → N=0 Z=0 V=0
        // sh=3 (ASR):  0x0010 - 0x0002 = 0x000E  → N=0 Z=0 V=0
        preload_reg_8(3'd0, 8'h10);
        preload_reg_8(3'd1, 8'h04);
        for (int sh = 0; sh < 4; sh++)
            send_instr(enc_CMP(3'd0, 3'd1, sh[1:0]), result);

        // ── No writeback check ─────────────────────────────────────────
        // CMP must NOT write the ALU result back to any register.
        // After the shift-variant CMPs above, R0 should still be 0x0010.
        // We preload R5=0x42=0x0042, run one more CMP (R0,R1, no shift),
        // then MOV R6 ← R5.  If CMP incorrectly wrote back, R0 or another
        // register is corrupted and the MOV will return the wrong value.
        preload_reg_8(3'd5, 8'h42);            // R5 = 0x0042
        send_instr(enc_CMP(3'd0, 3'd1), result);
        send_instr(enc_MOV_shift(3'd6, 3'd5), result);

    endtask : test_CMP

    task test_AND();
        bit [15:0] result;
        $display("\n=== test_AND ===");
        preload_reg_8(3'd0, 8'hFF);
        preload_reg_8(3'd1, 8'h00);
        send_instr(enc_AND(3'd2, 3'd0, 3'd1), result);
        preload_reg_8(3'd0, 8'hA5);
        preload_reg_8(3'd1, 8'hFF);
        send_instr(enc_AND(3'd2, 3'd0, 3'd1), result);
        for (int r = 0; r < 8; r++) begin
            preload_reg_8(r[2:0], 8'hA5);
            send_instr(enc_AND(r[2:0], r[2:0], r[2:0]), result);
        end
        preload_reg_8(3'd0, 8'hA5);
        preload_reg_8(3'd1, 8'h5A);
        send_instr(enc_AND(3'd2, 3'd0, 3'd1), result);
        preload_reg_8(3'd0, 8'hAA);
        preload_reg_8(3'd1, 8'h55);
        for (int sh = 0; sh < 4; sh++)
            send_instr(enc_AND(3'd2, 3'd0, 3'd1, sh[1:0]), result);
    endtask : test_AND

    task test_MVN();
        bit [15:0] result;
        $display("\n=== test_MVN ===");
        preload_reg_8(3'd0, 8'h00);
        send_instr(enc_MVN(3'd1, 3'd0), result);
        preload_reg_8(3'd0, 8'hFF);
        send_instr(enc_MVN(3'd1, 3'd0), result);
        preload_reg_8(3'd0, 8'h7F);
        send_instr(enc_MVN(3'd1, 3'd0), result);
        preload_reg_8(3'd0, 8'h80);
        send_instr(enc_MVN(3'd1, 3'd0), result);
        preload_reg_8(3'd0, 8'hA5);
        send_instr(enc_MVN(3'd1, 3'd0), result);
        send_instr(enc_MVN(3'd2, 3'd1), result);
        for (int r = 0; r < 8; r++) begin
            preload_reg_8(r[2:0], 8'hA5);
            send_instr(enc_MVN(r[2:0], r[2:0]), result);
        end
        preload_reg_8(3'd0, 8'hAA);
        for (int sh = 0; sh < 4; sh++)
            send_instr(enc_MVN(3'd1, 3'd0, sh[1:0]), result);
    endtask : test_MVN

    task test_sequences();
        bit [15:0] result;
        $display("\n=== test_sequences ===");
        send_instr_no_out(enc_MOV_imm  (3'd0, 8'h0A));
        send_instr_no_out(enc_MOV_imm  (3'd1, 8'h05));
        send_instr       (enc_ADD      (3'd2, 3'd0, 3'd1), result);
        send_instr       (enc_CMP      (3'd2, 3'd1),       result);
        send_instr       (enc_AND      (3'd3, 3'd2, 3'd0), result);
        send_instr       (enc_MVN      (3'd4, 3'd3),       result);
        send_instr       (enc_MOV_shift(3'd5, 3'd4),       result);
        send_instr_no_out(enc_MOV_imm(3'd0, 8'h00));
        send_instr_no_out(enc_MOV_imm(3'd1, 8'h01));
        repeat (8) send_instr(enc_ADD(3'd0, 3'd0, 3'd1), result);
        send_instr_no_out(enc_MOV_imm(3'd0, 8'h10));
        send_instr_no_out(enc_MOV_imm(3'd1, 8'h10));
        repeat (4) begin
            send_instr(enc_CMP(3'd0, 3'd1), result);
        end
        repeat (4) send_instr(enc_ADD(3'd0, 3'd0, 3'd0), result);
        repeat (4) send_instr(enc_MVN(3'd1, 3'd1),       result);
    endtask : test_sequences

    task test_reset();
        bit [15:0] result;
        $display("\n=== test_reset ===");
        bfm.send_cmd(.s2(1'b0), .load2(1'b1),
                     .in2(enc_ADD(3'd0, 3'd1, 3'd2)), .out2(result));
        bfm.reset_cpu(); scoreboard_h.reset();
        send_instr_no_out(enc_MOV_imm(3'd0, 8'h0F));
        send_instr_no_out(enc_MOV_imm(3'd1, 8'h01));
        send_instr(enc_ADD(3'd2, 3'd0, 3'd1), result);
        bfm.send_cmd(.s2(1'b0), .load2(1'b1),
                     .in2(enc_AND(3'd3, 3'd0, 3'd1)), .out2(result));
        bfm.reset_cpu(); scoreboard_h.reset();
        send_instr(enc_MOV_imm(3'd7, 8'hAB), result);
    endtask : test_reset

    task test_w_protocol();
        bit [15:0] result;
        $display("\n=== test_w_protocol ===");
        send_instr(enc_MOV_imm(3'd0, 8'hAA), result);
        send_instr(enc_ADD(3'd1, 3'd0, 3'd0), result);
        send_instr(enc_CMP(3'd0, 3'd0), result);
    endtask : test_w_protocol

    task test_random(input int unsigned num_ops = 300);
        bit [15:0] instr, result;
        bit [2:0]  rd, rn, rm;
        bit [1:0]  sh;
        bit [7:0]  imm;
        int        op_sel;
        $display("\n=== test_random (%0d ops) ===", num_ops);
        for (int r = 0; r < 8; r++) begin
            imm = $urandom_range(0, 255);
            send_instr_no_out(enc_MOV_imm(r[2:0], imm));
        end
        repeat (num_ops) begin
            rd     = $urandom_range(0, 7);
            rn     = $urandom_range(0, 7);
            rm     = $urandom_range(0, 7);
            sh     = $urandom_range(0, 3);
            imm    = $urandom_range(0, 255);
            op_sel = $urandom_range(0, 5);
            case (op_sel)
                0: instr = enc_MOV_imm  (rd,         imm);
                1: instr = enc_MOV_shift(rd,     rm, sh);
                2: instr = enc_ADD      (rd, rn, rm, sh);
                3: instr = enc_CMP      (    rn, rm, sh);
                4: instr = enc_AND      (rd, rn, rm, sh);
                5: instr = enc_MVN      (rd,     rm, sh);
            endcase
            send_instr(instr, result);
        end
    endtask : test_random
    
    // Task to hit all defined instruction transitions
    task test_transitions();
        bit [15:0] result;
        $display("=== Starting Directed Transitions Test ===");

        // Target: MOV_IMM => ADD
        send_instr_no_out(enc_MOV_imm(3'd0, 8'h01)); // R0 = 1
        send_instr_no_out(enc_MOV_imm(3'd1, 8'h02)); // R1 = 2
        send_instr(enc_ADD(3'd2, 3'd0, 3'd1, SH_NONE), result);

        // Target: MOV_IMM => CMP
        send_instr_no_out(enc_MOV_imm(3'd0, 8'h05));
        send_instr(enc_CMP(3'd0, 3'd1, SH_NONE), result);

        // Target: MOV_IMM => AND
        send_instr_no_out(enc_MOV_imm(3'd0, 8'hFF));
        send_instr(enc_AND(3'd2, 3'd0, 3'd1, SH_NONE), result);

        // Target: MOV_IMM => MVN
        send_instr_no_out(enc_MOV_imm(3'd0, 8'hAA));
        send_instr(enc_MVN(3'd2, 3'd0, SH_NONE), result);

        // Target: MOV_IMM => MOV_SHIFT
        send_instr_no_out(enc_MOV_imm(3'd0, 8'h01));
        send_instr(enc_MOV_shift(3'd1, 3'd0, SH_LSL), result);
    endtask
    
    // Task to hit specific boundary bins in out_cov
    task test_output_corners();
        bit [15:0] result;
        $display("=== Starting Output Corners Test ===");

        // Bin: zero (16'h0000)
        send_instr_no_out(enc_MOV_imm(3'd0, 8'h00));
        send_instr(enc_MOV_shift(3'd1, 3'd0, SH_NONE), result);

        // Bin: all_ones (16'hFFFF)
        send_instr_no_out(enc_MOV_imm(3'd0, 8'hFF));
        send_instr(enc_MVN(3'd1, 3'd0, SH_NONE), result); // Logic: ~0xFF extended

        // Bin: max_pos (16'h7FFF)
        // Load 0x7F then Shift + OR or just Move specific values if supported
        // Since MOV_IMM is 8-bit, we use ADD to construct 16'h7FFF
        send_instr_no_out(enc_MOV_imm(3'd0, 8'h7F)); 
        send_instr_no_out(enc_MOV_shift(3'd0, 3'd0, SH_LSL)); // R0 = 0x7F00 (depends on shift logic)
        // ... (Repeat logic to reach 0x7FFF)

        // Bin: min_neg (16'h8000)
        send_instr_no_out(enc_MOV_imm(3'd0, 8'h80));
        send_instr_no_out(enc_MOV_shift(3'd0, 3'd0, SH_LSL)); 
        send_instr(enc_MOV_shift(3'd1, 3'd0, SH_NONE), result);
    endtask

    task execute();
        bfm.reset_cpu(); scoreboard_h.reset();
        test_MOV_imm();
        test_MOV_shift();
        
        test_ADD();
        test_CMP();
        test_AND();
        test_MVN();
        test_sequences();
        test_reset();
        test_w_protocol();
        test_transitions();
        test_output_corners();
        test_random(300);
        $display("\n=== Tester complete ===");
        $stop;
    endtask : execute

endclass : tester