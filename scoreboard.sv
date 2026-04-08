class scoreboard;
    virtual cpu_bfm bfm;
    static bit [15:0] instr_reg[$];
    bit [15:0] register[8];             // R0–R7

    // Status flags
    bit flag_Z, flag_N, flag_V;

    function new(virtual cpu_bfm b);
        bfm = b;
    endfunction : new

    // Call whenever reset_cpu() is called in the tester.
    // Clears the software register model and flushes any partially-queued
    // instruction that was loaded before the reset fired.
    task reset();
        instr_reg.delete();
        for (int i = 0; i < 8; i++)
            register[i] = 16'h0000;
        flag_Z = 1'b0;
        flag_N = 1'b0;
        flag_V = 1'b0;
    endtask : reset

    typedef enum logic [4:0] {
        INSTR_MOV_IMM   = 5'b110_10,
        INSTR_MOV_SHIFT = 5'b110_00,
        INSTR_ADD       = 5'b101_00,
        INSTR_CMP       = 5'b101_01,
        INSTR_AND       = 5'b101_10,
        INSTR_MVN       = 5'b101_11
    } instr_t;

    // Barrel-shifter model — mirrors RTL shifter module exactly
    function automatic bit [15:0] do_shift(bit [15:0] val, bit [1:0] sh);
        case (sh)
            2'b00: return val;
            2'b01: return {val[14:0], 1'b0};
            2'b10: return {1'b0, val[15:1]};
            2'b11: return {val[15], val[15:1]};
            default: return val;
        endcase
    endfunction

    // Flag update model
    function automatic void update_flags(
        bit [15:0] a, bit [15:0] b, bit [15:0] result, bit is_sub
    );
        flag_Z = (result == 16'h0000);
        flag_N = result[15];
        if (is_sub)
            flag_V = (a[15] != b[15]) && (result[15] != a[15]);
        else
            flag_V = 0;
    endfunction

    task execute();
        bit [15:0] cmd_in;
        bit [15:0] predicted_out;
        bit [15:0] predicted_out_tmp[$];
        bit        check_out;
        bit        check_flags;

        bit [2:0]  Rn, Rd, Rm;
        bit [1:0]  sh_op;
        bit [15:0] shifted_Rm;
        bit [16:0] add_full;            // FIX 9: 17-bit to capture carry

        instr_t    decoded;             // FIX 5: explicit cast target

        forever begin : self_checker

            @(posedge bfm.clk);

            if (bfm.load)
                instr_reg.push_back(bfm.in);

            if (bfm.s && (instr_reg.size() > 0)) begin

                cmd_in      = instr_reg.pop_front();
                check_out   = 1'b0;
                check_flags = 1'b0;

                Rn    = cmd_in[10:8];
                Rd    = cmd_in[7:5];
                Rm    = cmd_in[2:0];
                sh_op = cmd_in[4:3];

                shifted_Rm = do_shift(register[Rm], sh_op);

                // FIX 5: cast the 5-bit slice to instr_t for the case selector
                decoded = instr_t'(cmd_in[15:11]);

                case (decoded)

                    INSTR_MOV_IMM: begin
                        register[Rn]  = {{8{cmd_in[7]}}, cmd_in[7:0]};
                        predicted_out = register[Rn];
                        @(posedge bfm.clk);
                        //check_out = 1'b1;
                    end

                    INSTR_MOV_SHIFT: begin
                        register[Rd]  = shifted_Rm;
                        predicted_out_tmp.push_back(register[Rd]);
                        @(posedge bfm.w);
                        predicted_out = predicted_out_tmp.pop_front();
                        check_out = 1'b1;
                    end

                    INSTR_ADD: begin
                        add_full      = {1'b0, register[Rn]} + {1'b0, shifted_Rm};
                        register[Rd]  = add_full[15:0];
                        predicted_out = register[Rd];
                        @(posedge bfm.w);
                        check_out = 1'b1;
                    end

                    INSTR_CMP: begin
                        begin
                            bit [15:0] diff;
                            diff = register[Rn] - shifted_Rm;
                            update_flags(register[Rn], shifted_Rm, diff, 1'b1);
                        end
                        @(posedge bfm.w);
                        check_flags = 1'b1;
                    end

                    INSTR_AND: begin
                        register[Rd]  = register[Rn] & shifted_Rm;
                        predicted_out = register[Rd];
                        @(posedge bfm.w);
                        check_out = 1'b1;
                    end

                    INSTR_MVN: begin
                        register[Rd]  = ~shifted_Rm;
                        predicted_out = register[Rd];
                        @(posedge bfm.w);
                        check_out = 1'b1;
                    end

                    default: begin
                        $warning("SCOREBOARD: Unknown instruction 5'b%05b — skipped",
                                 cmd_in[15:11]);
                    end

                endcase

                if (check_out) begin
                    if (bfm.out !== predicted_out)
                        $error("FAILED [%s]: Rd=%0d  predicted=0x%04h  DUT=0x%04h",
                               decoded.name(), Rd, predicted_out, bfm.out);
                    else
                        $display("%0t: PASSED [%s]: Rd=%0d  out=0x%04h",
                                 $time, decoded.name(), Rd, bfm.out);
                end

                if (check_flags) begin
                    if (bfm.Z !== flag_Z || bfm.N !== flag_N || bfm.V !== flag_V)
                        $error("FAILED [CMP]: Rn=%0d Rm=%0d  pred{V,N,Z}=%03b  DUT{V,N,Z}=%03b",
                               Rn, Rm,
                               {flag_V, flag_N, flag_Z},
                               {bfm.V,  bfm.N,  bfm.Z});
                    else
                        $display("%0t:PASSED [CMP]: Rn=%0d Rm=%0d  {V,N,Z}=%03b",
                                 $time, Rn, Rm, {bfm.V, bfm.N, bfm.Z});
                end

            end

        end : self_checker
    endtask : execute

endclass : scoreboard