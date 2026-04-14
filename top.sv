import cpu_pkg::*;

module top;
    cpu_bfm  bfm();

    cpu DUT(
        .clk   (bfm.clk),
        .reset (bfm.reset),
        .s     (bfm.s),
        .load  (bfm.load),
        .in    (bfm.in),
        .out   (bfm.out),
        .N     (bfm.N),
        .V     (bfm.V),
        .Z     (bfm.Z),
        .w     (bfm.w)
    );

    testbench testbench_h;

    initial begin
        testbench_h = new(bfm);
        testbench_h.execute();
    end

endmodule : top