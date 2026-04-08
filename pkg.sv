package cpu_pkg;
      typedef enum logic [4:0] {
        INSTR_MOV_IMM   = 5'b110_10,
        INSTR_MOV_SHIFT = 5'b110_00,
        INSTR_ADD       = 5'b101_00,
        INSTR_CMP       = 5'b101_01,
        INSTR_AND       = 5'b101_10,
        INSTR_MVN       = 5'b101_11
    } instr_t;
`include "coverage.sv"
`include "scoreboard.sv"
`include "tester.sv"
`include "testbench.sv"
endpackage : cpu_pkg