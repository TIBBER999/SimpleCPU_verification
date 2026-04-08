class random_test extends uvm_test;
    `uvm_component_utils(random_test);
    
    virtual interface cpu_bfm bfm;
    
    function new (string name, uvm_component parent);
        super.new(name.parent);
        if (!uvm_config_db #(virtual interface cpu_bfm)::get(null, "*", "bfm", bfm);
            $fatal("Failed to get BFM");
    endfunction: new    
endclass