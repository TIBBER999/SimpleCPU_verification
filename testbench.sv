class testbench;
    virtual cpu_bfm bfm;

   tester    tester_h;
   coverage  coverage_h;
   scoreboard scoreboard_h;
   
   function new (virtual cpu_bfm b);
       bfm = b;
   endfunction : new

   task execute();
      scoreboard_h = new(bfm);
      tester_h    = new(bfm, scoreboard_h);
      coverage_h   = new(bfm);

      fork
         tester_h.execute();
         coverage_h.execute();
         scoreboard_h.execute();
      join_none
   endtask : execute
endclass