//////////////////////////////////////////////////////////////////////
////                                                              ////
//// regf_status                                                  ////
////                                                              ////
//// This file is part of the SXP opencores effort.               ////
//// <http://www.opencores.org/cores/sxp/>                        ////
////                                                              ////
//// Module Description:                                          ////
//// Scoreboarding module for reg file                            ////
////                                                              ////
//// To Do:                                                       ////
////                                                              ////
//// Author(s):                                                   ////
//// - Sam Gladstone                                              ////
////                                                              ////
//////////////////////////////////////////////////////////////////////
////                                                              ////
//// Copyright (C) 2001 Sam Gladstone and OPENCORES.ORG           ////
////                                                              ////
//// This source file may be used and distributed without         ////
//// restriction provided that this copyright statement is not    ////
//// removed from the file and that any derivative work contains  ////
//// the original copyright notice and the associated disclaimer. ////
////                                                              ////
//// This source file is free software; you can redistribute it   ////
//// and/or modify it under the terms of the GNU Lesser General   ////
//// Public License as published by the Free Software Foundation; ////
//// either version 2.1 of the License, or (at your option) any   ////
//// later version.                                               ////
////                                                              ////
//// This source is distributed in the hope that it will be       ////
//// useful, but WITHOUT ANY WARRANTY; without even the implied   ////
//// warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR      ////
//// PURPOSE. See the GNU Lesser General Public License for more  ////
//// details.                                                     ////
////                                                              ////
//// You should have received a copy of the GNU Lesser General    ////
//// Public License along with this source; if not, download it   ////
//// from <http://www.opencores.org/lgpl.shtml>                   ////
////                                                              ////
//////////////////////////////////////////////////////////////////////
//
// $Id: regf_status.v,v 1.3 2001-12-02 19:05:47 samg Exp $ 
//
// CVS Revision History
//
// $Log: not supported by cvs2svn $
// Revision 1.2  2001/11/08 23:58:10  samg
// added header and modified parameter structure
//
//

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

parameter AWIDTH = 5;

input clk;
input reset_b;
input stall;
input halt;
input dest_en;
input [AWIDTH-1:0] dest_addr;
input wec;
input [AWIDTH-1:0] addrc;
input [AWIDTH-1:0] addra;
input [AWIDTH-1:0] addrb;
input a_en;
input b_en;
input flush_pipeline;

output stall_regf;
output safe_switch;
               
// Internal varibles and signals
reg [(1<<AWIDTH)-1:0] reg_stat;		// register status field
reg [(1<<AWIDTH)-1:0] d_field;		// destination field 
reg [(1<<AWIDTH)-1:0] w_field;		// write field
reg status_a;
reg status_b;

wire dest_en_stall;

integer k;
integer j;
 
assign safe_switch = !reg_stat;		// The bang ORs the contents and inverts the final single bit

assign dest_en_stall = (stall) ? 1'b 0 : dest_en;

always @(dest_addr or dest_en_stall)
  begin
    for (j=0;j<(1<<AWIDTH);j=j+1)
      d_field[j] = ((j == dest_addr) && dest_en_stall) ? 1'b 1 : 1'b 0;
  end

always @(addrc or wec)
  begin
    for (k=0;k<(1<<AWIDTH);k=k+1)
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
          reg_stat <= (reg_stat & w_field) | d_field;
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

assign stall_regf = status_a | status_b & !flush_pipeline;

endmodule

