interface cpu_bfm;
    bit   clk;
    bit   reset;
    bit   s;
    bit   load;
    logic [15:0] in;     // FIX 2: was wire — must be logic for procedural assignment
    logic [15:0] out;    // FIX 2: was wire — must be logic for procedural assignment
    bit   N, V, Z, w;

    initial begin
        clk = 0;
        forever begin
            #10;
            clk = ~clk;
        end
    end

    task reset_cpu();
        reset = 1'b1;
        @(negedge clk);
        @(negedge clk);
        reset = 1'b0;
        s     = 1'b0;
    endtask : reset_cpu

    task send_cmd(
        input  bit        s2,
        input  bit        load2,
        input  bit [15:0] in2,
        output bit [15:0] out2
    );
        @(negedge clk);
        load = load2;
        s    = s2;
        in   = in2;
        @(posedge clk);
        wait (w);
        out2 = out;
    endtask : send_cmd

endinterface : cpu_bfm