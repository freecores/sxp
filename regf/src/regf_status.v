/*
 Scoreboarding module for reg file
 SXP Processor
 Sam Gladstone

*/

module regf_status (
		clk,		// system clock
                reset_b,	// power on reset
		stall,		// stall status register
		halt,		// system stall
                dest_en,	// instr has dest register (en scoreboarding) 
		dest_addr,	// destination address from instruction
  		wec,		// port C write back request 
		addrc,		// port C write back address 
                addra,		// reg file address reg A (source 1) 
                addrb,		// reg file address reg B (source 2) 
		a_en,		// A register is enabled
	        b_en,		// B reguster is enabled	
		flush_pipeline,	// pipeline flush (initialize status)
           
                safe_switch,	// safe to context switch or interupt;
                stall_regf);	// stall the reg file and modules prior 

parameter WIDTH = 5;
parameter SIZE = 32;

input clk;
input reset_b;
input stall;
input halt;
input dest_en;
input [WIDTH-1:0] dest_addr;
input wec;
input [WIDTH-1:0] addrc;
input [WIDTH-1:0] addra;
input [WIDTH-1:0] addrb;
input a_en;
input b_en;
input flush_pipeline;

output stall_regf;
output safe_switch;
               
// Internal varibles and signals
reg [SIZE-1:0] reg_stat;	// register status field
reg [SIZE-1:0] d_field;		// destination field 
reg [SIZE-1:0] w_field;		// write field
reg status_a;
reg status_b;

wire dest_en_stall;

integer k;
integer j;
 
assign safe_switch = !reg_stat;		// The bang ORs the contents and inverts the final single bit

assign dest_en_stall = (stall) ? 1'b 0 : dest_en;

always @(dest_addr or dest_en_stall)
  begin
    for (j=0;j<SIZE;j=j+1)
      d_field[j] = ((j == dest_addr) && dest_en_stall) ? 1'b 1 : 1'b 0;
  end

always @(addrc or wec)
  begin
    for (k=0;k<SIZE;k=k+1)
      w_field[k] = ((k == addrc) && wec) ? 1'b 0 : 1'b 1;
  end

always @(posedge clk or negedge reset_b)
  begin
    if (!reset_b)
      reg_stat <= 'b 0;
    else
      if (flush_pipeline)
        reg_stat <= 'b 0;
      else
        if (!halt)		// Should be only for halt signals (not stall_1_2) 
          reg_stat <= #1 (reg_stat & w_field) | d_field;
  end

always @(addrc or addra or wec or a_en or reg_stat)
  begin
    if ((addrc == addra) && wec || !a_en)
      status_a = 1'b 0;
    else
      status_a = reg_stat[addra];
  end

always @(addrc or addrb or wec or b_en or reg_stat)
  begin
    if ((addrc == addrb) && wec || !b_en)
      status_b = 1'b 0;
    else
      status_b = reg_stat[addrb];
  end

// assign status_a = ((addrc == addra) && wec || !a_en) ? 1'b 0 : reg_stat[addra];
// assign status_b = ((addrc == addrb) && wec || !b_en) ? 1'b 0 : reg_stat[addrb];
// For some reason this will not work on Icarus, need to check with other sim tools.
// It complains that assign statements can not have variable bit select but I found
// an example in Baskar's book that shows it. (I also found in the same book a statement
// that said that assign statements could only have constant bit selects.

assign stall_regf = status_a | status_b;

endmodule

/* 
 * $ID$
 * Module : regf_status 
 * Arthor : Sam Gladstone
 * Purpose: Scoreboard controller for reg file 
 * Issues :
 * $LOG$
 */
