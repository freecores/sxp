/* 
  Synchronous reg file (Less latency than memory based reg file)
  SXP Processor
  Sam Gladstone
 */


module sync_regf (
		clk,			// system clock
		reset_b,		// power on reset
		halt,			// system wide halt
	   	addra,			// Port A read address 
                a_en,			// Port A read enable
		addrb,			// Port B read address 
                b_en,			// Port B read enable 
		addrc,			// Port C write address 
	        dc,			// Port C write data 
		wec,			// Port C write enable 

		qra,			// Port A registered output data	
		qrb);			// Port B registered output data 	

parameter WIDTH = 5;
parameter SIZE  = 32;

input clk;
input reset_b;
input halt;
input [WIDTH-1:0] addra;
input a_en;
input [WIDTH-1:0] addrb;
input b_en;
input [WIDTH-1:0] addrc;
input [31:0] dc;
input wec;

output [31:0] qra;
output [31:0] qrb;

// Internal varibles and signals
integer i;

reg [31:0] reg_file [0:SIZE-1];	// Syncronous Reg file

assign qra = ((addrc == addra) && wec) ? dc : reg_file[addra];
assign qrb = ((addrc == addrb) && wec) ? dc : reg_file[addrb];

always @(posedge clk or negedge reset_b)
  begin
    if (!reset_b)
      for (i=0;i<SIZE;i=i+1)
        reg_file [i] <= {32{1'b x}};
    else
      if (wec)
        reg_file[addrc] <= dc;
  end

task reg_display;
  integer k;
  begin
    for (k=0;k<SIZE;k=k+1)
      $display("Location %d = %h",k,reg_file[k]); 
  end
endtask

endmodule

/* 
 * $ID$
 * Module : sync_regf 
 * Arthor : Sam Gladstone
 * Purpose: synchronous register file 
 * Issues :
 * $LOG$
 */
