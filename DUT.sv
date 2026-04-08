module cpu(clk,reset,s,load,in,out,N,V,Z,w);
	input clk, reset, s, load;
	input [15:0] in;
	output [15:0] out;
	output N, V, Z, w;

//wires for instruction decoder
	wire [15:0] instruc, sximm5, sximm8 ;
	wire [2:0] opcode, readnum, writenum ;
	wire [1:0] op, ALUop, shift ;
//

//wire for datapath
	wire [15:0] C ;
	wire [2:0] flag_out ;
	
	assign Z = flag_out[0] ;
	assign N = flag_out[1] ;
	assign V = flag_out[2] ;
	assign out = C  ;
//

//wire for FSM
	wire [3:0] vsel ;
	wire write, loada, loadb, asel, bsel, loadc, loads, w_out ;
	wire [2:0] nsel ;
	
	assign w = w_out ;
//

//instruction register block
	register_load Instruc_reg(in, load, clk, instruc);
	
//instruction Decoder
	instruction_decoder Instruc_dec(	//input 	
										.in			(instruc) 	, //16'b
										.nsel		(nsel)		, //3'b
											
										//outputs 	
											//output to controller FSM
										.op			(op)		, //2'b
										.opcode 	(opcode)	, //3'b
										
											// output to datapath 
										.ALUop		(ALUop) 	, //2'b
										.sximm5 	(sximm5)	, //16'b
										.sximm8 	(sximm8)	, //16'b
										.shift		(shift)		, //2'b
										.readnum	(readnum)	, //3'b
										.writenum 	(writenum) ); //3'b
										
//DATAPATH 		
	datapath DP(		.clk     		(clk)	  		, 			//top
					
						// vsel multiplexer 
						.mdata			(16'b0)	/*sub w 0*/		, 
						.sximm8			(sximm8)		,			//decode
						//fetched from decode
						.PC				(8'b0) /*sub w/ 0 */	,
						
						// register operand fetch stage
						.readnum     	(readnum)		,			//decode
						//fetched from decode
						.vsel        	(vsel)			,			//FSM
						.loada       	(loada)			,			//FSM
						.loadb       	(loadb)			,			//FSM
							
				
						// computation stage (sometimes called "execute")
						.shift      	(shift)			,			//decode
						//fetched from decode
						.asel       	(asel)			,			//FSM
						.bsel       	(bsel)			,			//FSM
						.ALUop      	(ALUop)			,			//decode
						//fetched from decode
						.loadc      	(loadc)			,			//FSM
						.loads      	(loads)			,			//FSM
						.sximm5			(sximm5)		,			//decode
						//fetched from decode
				
						// set when "writing back" to register file
						.writenum    	(writenum)		,			//decode
						.write       	(write)			,  			//FSM
				
						// outputs
						.flag_out		(flag_out)		,			//to top
						.datapath_out	(C)							//same as out
             );
	
//CPU FSM
	CPU_FSM 	FSM(//input
						//from top
						.reset			(reset)			,	//1'b		
						.clk			(clk)			,	//1'b		
						.s				(s)				,	//1'b	only leave wait state when 1'b1	
						//from decode 
						.opcode			(opcode)		,	//3'b
						.op				(op)			,	//2'b
					//output	
						// to datapath
						.vsel			(vsel)			,	//4'b One-Hot
						.write			(write)			,	//1'b
						.loada			(loada)			,	//1'b
						.loadb			(loadb)			,	//1'b
						.asel			(asel)			,	//1'b
						.bsel			(bsel)			,	//1'b 
						.loadc			(loadc)			,	//1'b datapath_out
						.loads			(loads)			,	//1'b status flags
						// to decoder
						.nsel			(nsel)			,	//3'b One-Hot 
						// to top
						.w				(w_out)				//1'b	1'b1 when waiting for instructions
				);		
endmodule 

// INSTRUCTION DECODER BLOCK AND ITS SUBSEQUENT MODULES 
module instruction_decoder( in, nsel, op, opcode, ALUop, sximm5, sximm8, shift, readnum, writenum) ;
	input [15:0] in ;
	input [2:0] nsel ;
	output [1:0] op, ALUop, shift ;
	output [2:0] opcode, readnum, writenum ;
	output [15:0] sximm5, sximm8 ;

	//output to controller FSM
	assign opcode = in[15:13] ;
	assign op = in[12:11] ;
	
	//three to one multiplexer with Rn, Rd, Rm, nsel and output writenum and readnum
	//Rn is 0, Rd is 1, Rm is 2
	three_in_one address_mult( in[10:8], in[7:5], in[2:0], nsel, readnum, writenum) ;
	
	//output directly to datapath
	assign shift = in[4:3] ;
	assign sximm8 = {{8{in[7]}}, in[7:0]} ;
	assign sximm5 = {{11{in[4]}}, in[4:0]} ;
	assign ALUop = in[12:11] ;
endmodule 

module three_in_one (r0, r1, r2, select, out1, out2) ;
	parameter k = 3 ;
	input [k-1:0] r0, r1, r2 ;
	input [2:0] select ;
	output wire [k-1:0] out1, out2 ;
//readnum and writenum is the same	
	assign out1 = ({k{select[0]}}&r0) |
				 ({k{select[1]}}&r1) |
				 ({k{select[2]}}&r2) ;
				 
	assign out2 = ({k{select[0]}}&r0) |
				 ({k{select[1]}}&r1) |
				 ({k{select[2]}}&r2) ;			 

endmodule 

`define S_WAIT 	 	4'b0000
`define S_MOVim8 	4'b0001
`define S_GETB 		4'b0011
`define S_GETA		4'b0100
`define S_GETC		4'b0101
`define S_MOVREG	4'b0110

//CPU FSM AND ITS SUBSEQUENT MODULES 
module CPU_FSM(reset, clk, s, opcode, op, w, nsel, vsel, asel, bsel, write, loada, loadb, loadc, loads) ;
	input reset, clk, s ;
	input [2:0] opcode ;
	input [1:0] op ;
	
	output reg [2:0] nsel ;
	output reg [3:0] vsel ;
	output reg w, write, asel, bsel, loada, loadb, loadc, loads ;
	
	reg [3:0] state, nxt_state ;
	
	always @(posedge clk) begin 
		if (reset)	
			state <= `S_WAIT	;
		else 
			state <= nxt_state ;
	end 

	always @(*) begin 
		case (state) 
			`S_WAIT : begin		
						if (s) begin 
							case({opcode , op})
								{3'b110, 2'b10} : nxt_state = `S_MOVim8 ;
								{3'b110, 2'b00} : nxt_state = `S_GETB ;
								{3'b101, 2'b00} : nxt_state = `S_GETA ;
								{3'b101, 2'b01} : nxt_state = `S_GETA ;
								{3'b101, 2'b10} : nxt_state = `S_GETA ;
								{3'b101, 2'b11} : nxt_state = `S_GETB ;
								default : nxt_state = `S_WAIT ;
							endcase 
						vsel		= 4'b0001	;
						write		= 1'b0		;
						loada		= 1'b0		;
						loadb		= 1'b0		;
						asel		= 1'b0		;
						bsel		= 1'b0		;
						loadc		= 1'b0		;
						loads		= 1'b0		;
						
						nsel		= 3'b001	; //problematic if not 3'b010 when executing the ADD operand
						
						w		= 1'b1		;
							end 
						
						else begin 
						nxt_state = `S_WAIT ;
						vsel		= 4'b0001	;
						write		= 1'b0		;
						loada		= 1'b0		;
						loadb		= 1'b0		;
						asel		= 1'b0		;
						bsel		= 1'b0		;
						loadc		= 1'b0		;
						loads		= 1'b0		;
						
						nsel		= 3'b001	;
						
						w		= 1'b1		;	
						end 	
					end 
	// supporting MOV RN, #<im8>				
			`S_MOVim8: begin 
						nxt_state = `S_WAIT ;
						
						vsel		= 4'b0100	;	//select sximm8
						write		= 1'b1		;	//writing Rn in reg
						loada		= 1'b0		;
						loadb		= 1'b0		;
						asel		= 1'b0		;
						bsel		= 1'b0		;
						loadc		= 1'b0		;
						loads		= 1'b0		;
						
						nsel		= 3'b001	;	//writenum readnum = Rn
						
						w			= 1'b0 ;
					end
	//
	// supporting MOV Rd, Rm, {,<sh_op>}
			`S_GETB : begin
						nxt_state 	= `S_GETC	;
						vsel		= 4'b0001	;	
						write		= 1'b0		;	
						loada		= 1'b0		;
						loadb		= 1'b1		;	//output Rm to FF B
						asel		= 1'b0		;
						bsel		= 1'b0		;
						loadc		= 1'b0		;
						loads		= 1'b0		;
						
						nsel		= 3'b100	;	//selcting Rm
						w			= 1'b0 		;	//starting operation 					
					end 
			`S_GETC : begin
				case ({opcode, op})
					//get C with asel = 1'b1
					{3'b110, 2'b00} : begin 
						nxt_state 		= `S_MOVREG	;
						vsel			= 4'b0001	;	
						write			= 1'b0		;	
						loada			= 1'b0		;
						loadb			= 1'b0		;
						asel			= 1'b1		;	//let the shifted B outaput reach FF C
						bsel			= 1'b0		;
						loadc			= 1'b1		;	//load shifted B to C
						loads			= 1'b0		;
							
						nsel			= 3'b010	;	 
						w				= 1'b0		;
										end 					

					// supporting CMP						
					{3'b101, 2'b01} : begin 
						nxt_state 		= `S_MOVREG	;
						vsel			= 4'b0001	;	
						write			= 1'b0		;	
						loada			= 1'b0		;
						loadb			= 1'b0		;
						asel			= 1'b0		;	//let the shifted B outaput reach FF C
						bsel			= 1'b0		;
						loadc			= 1'b1		;	//load shifted B to C
						loads			= 1'b1		;
							
						nsel			= 3'b010	;	 
						w				= 1'b0		;
										end 
					// supporting AND					
					// supporting MVN
					// supporting ADD
					default : begin 
						nxt_state 		= `S_MOVREG	;
						vsel			= 4'b0001	;	
						write			= 1'b0		;	
						loada			= 1'b0		;
						loadb			= 1'b0		;
						asel			= 1'b0		;	//let the shifted B outaput reach FF C
						bsel			= 1'b0		;
						loadc			= 1'b1		;	//load shifted B to C
						loads			= 1'b0		;
							
						nsel			= 3'b010	;	 
						w				= 1'b0		;
							end 
				endcase 		 
					end 	
			`S_MOVREG : begin 	
					nxt_state 		= `S_WAIT 	;
					vsel			= 4'b0001	;	//input C back to register file
					write           = ({opcode, op} == {3'b101, 2'b01}) ? 1'b0 : 1'b1;	//write to reg Rd but not for CMP
					loada			= 1'b0		;
					loadb			= 1'b0		;
					asel			= 1'b0		;
					bsel			= 1'b0		;
					loadc			= 1'b0		;
					loads			= 1'b0		;
						
					nsel			= 3'b010	;	//selecting Rd
						
					w				= 1'b0		;
					end 
	//
	
	// supporting ADD Rd, Rn, Rm{,<sh_op>}
			`S_GETA : begin
					nxt_state 		= `S_GETB 	;
					vsel			= 4'b0001	;	
					write			= 1'b0		;	
					loada			= 1'b1		;	// load Rn to FF A
					loadb			= 1'b0		;
					asel			= 1'b0		;
					bsel			= 1'b0		;
					loadc			= 1'b0		;
					loads			= 1'b0		;
						
					nsel			= 3'b001	;	//selecting Rd
						
					w				= 1'b0		;
					end 
	
			default : begin 
					nxt_state = `S_WAIT ;
					vsel		= 4'b0001	;
					write		= 1'b0		;
					loada		= 1'b0		;
					loadb		= 1'b0		;
					asel		= 1'b0		;
					bsel		= 1'b0		;
					loadc		= 1'b0		;
					loads		= 1'b0		;
					
					nsel		= 3'b001	;
					
					w		= 1'b1		;	
					end 
		endcase 
	end 
endmodule 

module regfile(data_in, writenum, write, readnum, clk, data_out) ;
	input [15:0] data_in ;
	input [2:0] writenum, readnum ;
	input write, clk ;
	wire [15:0] R0, R1, R2, R3, R4, R5, R6, R7 ;
	wire [7:0] dec_write_out, dec_read_out ;
	wire reg0_L, reg1_L, reg2_L, reg3_L, reg4_L, reg5_L, reg6_L, reg7_L ;
	output wire [15:0] data_out ;
	
	decoder write_reg( writenum, dec_write_out) ;
	decoder read_reg(  readnum, dec_read_out ) ;
	
	and DW0(reg0_L, dec_write_out[0], write);
	and DW1(reg1_L, dec_write_out[1], write);
	and DW2(reg2_L, dec_write_out[2], write);
	and DW3(reg3_L, dec_write_out[3], write);
	and DW4(reg4_L, dec_write_out[4], write);
	and DW5(reg5_L, dec_write_out[5], write);
	and DW6(reg6_L, dec_write_out[6], write);
	and DW7(reg7_L, dec_write_out[7], write);
	
	register_load r0( data_in, reg0_L , clk, R0 ) ;
	register_load r1( data_in, reg1_L , clk, R1 ) ;
	register_load r2( data_in, reg2_L , clk, R2 ) ;
	register_load r3( data_in, reg3_L , clk, R3 ) ;
	register_load r4( data_in, reg4_L , clk, R4 ) ;
	register_load r5( data_in, reg5_L , clk, R5 ) ;
	register_load r6( data_in, reg6_L , clk, R6 ) ;
	register_load r7( data_in, reg7_L , clk, R7 ) ;
	
	mutiplx_reg MR1( R0, R1, R2, R3, R4, R5, R6, R7, dec_read_out, data_out );
	
	
endmodule

module register_load (in, load, clk, out) ;
	parameter m = 16 ;

	input [m-1:0] in ;
	input clk, load ;
	reg [m-1:0] data, new_data ;
	output [m-1:0] out ;
	
	assign out = data ;

//sequential block for DFF	
	always @(posedge clk) begin
		data <= new_data ;
	end 

//combinational block for DFF	
	always @(*) begin
		if (load) 
			new_data = in ;
		
		else 
			new_data = data ;
	end
endmodule 

module decoder (in, out) ;
	input [2:0] in ;
	output reg [7:0] out ;
	
	always @(*) begin
//3:8 one-hot code decoder
		case (in)
			3'b000: out = 8'b00000001 ;
			3'b001: out = 8'b00000010 ;
			3'b010: out = 8'b00000100 ;
			3'b011: out = 8'b00001000 ;
			3'b100: out = 8'b00010000 ;
			3'b101: out = 8'b00100000 ;
			3'b110: out = 8'b01000000 ;
			3'b111: out = 8'b10000000 ;
		endcase
	end 
endmodule 

module mutiplx_reg (r0, r1, r2, r3, r4, r5, r6, r7, select, out) ;
	parameter k = 16 ;
	input [15:0] r0, r1, r2, r3, r4, r5, r6, r7 ;
	input [7:0] select ;
	output wire [15:0] out ;

//8 input multiplexer	
	assign out = ({k{select[0]}}&r0) |
				 ({k{select[1]}}&r1) |
				 ({k{select[2]}}&r2) |
				 ({k{select[3]}}&r3) |
				 ({k{select[4]}}&r4) |
				 ({k{select[5]}}&r5) |
				 ({k{select[6]}}&r6) |
				 ({k{select[7]}}&r7) ;
	
endmodule 


module datapath (clk        , 
				 mdata		,
				 sximm8		,
				 sximm5		,
				 PC			,
				
                // register operand fetch stage
                readnum     ,
                vsel        ,
                loada       ,
                loadb       ,

                // computation stage (sometimes called "execute")
                shift       ,
                asel        ,
                bsel        ,
                ALUop       ,
                loadc       ,
                loads       ,

                // set when "writing back" to register file
                writenum    ,
                write       ,  

                // outputs
                flag_out    ,
                datapath_out
             );
			 
	input wire clk, write, loada, loadb, asel, bsel, loadc, loads ;
	input wire [1:0] shift, ALUop ;
	input wire [2:0] readnum, writenum ;
	input wire [3:0] vsel ;
	input wire [7:0] PC ;
	input wire [15:0] mdata, sximm8, sximm5 ;
	
	wire [2:0] flag ;
	wire [15:0] data_in, data_out, REG_A_out, REG_B_out, sout, Ain, Bin, out ;
	
	output wire [2:0] flag_out ;
	output wire [15:0] datapath_out ;
	
	//multiplexer for receiving data from top level
	//changed to 4:1 with (mdata(16'b), sximm8(16'b), PC(8'b0, PC), C(16'b)
	four_one_mult data_in_dec( mdata, sximm8, {8'b0, PC}, datapath_out, vsel, data_in ) ;
	
	//Register File
	regfile REGFILE( data_in, writenum, write, readnum, clk, data_out ) ;
	
	//DFF for load A and load B
	register_load REG_A( data_out, loada, clk, REG_A_out ) ;
	register_load REG_B( data_out, loadb, clk, REG_B_out ) ;
	
	//input for shifter unit
	shifter U1( REG_B_out, shift, sout ) ;
	
	//multiplexer for asel and bsel
	two_one_mult MULT_A( {16{1'b0}}, REG_A_out, asel, Ain ) ;
		//changed {11'b0, datapath_in[4:0]} in lab 5
	two_one_mult MULT_B( sximm5, sout, bsel, Bin ) ;
	
	//ALU module 
	ALU U2( Ain, Bin, ALUop, out, flag ) ;
	
	//DFF for load C and status
	register_load REG_C( out, loadc, clk, datapath_out ) ;
	//changed from 1 bit in lab5 to 3 bits
		//{1'b overflow, 1'b Negative, 1'b Zero}
	register_load#3 status( flag, loads, clk, flag_out ) ;
			 
			 
endmodule 

//changed from 2:1 (datapath_in, datapathe_out (C)) to 
//4:1 (mdata(memory output), sximm8, PC, C) 
module four_one_mult (in3, in2, in1, in0, select, out ) ;
	parameter k = 16 ;
	input [k-1:0] in3, in2, in1, in0 ;
	input [3:0] select ;
	output wire [k-1:0] out ;

//4 input multiplexer	
	assign out = ({k{select[0]}}&in0) |
				 ({k{select[1]}}&in1) |
				 ({k{select[2]}}&in2) |
				 ({k{select[3]}}&in3) ;
	
endmodule 

module two_one_mult ( in1, in0, sel, out ) ;
	
	input [15:0] in1, in0 ;
	input sel ;
	output reg [15:0] out ;
	
	always @(*) begin
		case (sel) 
			1'b1 : out = in1 ;
			1'b0 : out = in0 ;
		endcase 
	end 

endmodule 

module shifter (in , shift, sout) ;
	input [15:0] in ;
	input [1:0] shift ;
	output reg [15:0] sout ;

//shifter always block takes input of 16'b datapath perform operations (shiftop) then output the operated datapath	
	always @(*) begin
		case (shift) 
			2'b00 : sout = in ;
			2'b01 : sout = {in[14:0], 1'b0} ;
			2'b10 : sout = {1'b0, in[15:1]} ;
			2'b11 : sout = {in[15], in[15:1]} ;
		endcase 
	end 
endmodule


module ALU ( Ain, Bin, ALUop, out, status ) ;
	input  [15:0] Ain, Bin ;
	input  [1:0]  ALUop ;
	wire [15:0] s ;
	wire ovf ;
	output reg [15:0] out ;
	output reg [2:0] status ;

	
	AddSub1 ovf_check(Ain, Bin, ALUop[0], s, ovf) ;
		
		always @(*) begin 
			case (ALUop)
				2'b00: out = s ;
				2'b01: out = s ;
				2'b10: out = Ain & Bin ;
				2'b11: out = ~Bin ;
			endcase 
			
			// zero flag
			if (out == ({16{1'b0}}))
				status[0] = 1'b1 ;
			else 
				status[0] = 1'b0;
			
			// negative flag
			if (out[15] == 1'b1) 
				status[1] = 1'b1 ;
			else 
				status[1] = 1'b0 ;
				
			// overflow flag	
			if (ovf == 1'b1) 
				status[2] = 1'b1;
			else 
				status[2] = 1'b0; 
				
		end 

endmodule 

//code collected from figure 10.14
//add a+b or subtract a-b, check for overflow
module AddSub1 ( a, b, sub, s, ovf ) ;
	parameter n = 16 ;
	input [n-1:0] a, b ;
	input sub ;
	output [n-1:0] s ;
	output ovf ;
	wire c1, c2 ;
	
	assign ovf = c1 ^ c2 ;
	
	//add non sign bits 
	assign {c1, s[n-2:0]} = a[n-2:0] + (b[n-2:0] ^ {n-1{sub}}) + sub ;
	
	//add sign bits 
	assign {c2, s[n-1]} = a[n-1] + (b[n-1] ^ sub) + c1 ;

endmodule 


