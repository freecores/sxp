/* Testbench module for SXP processor
   Sam Gladstone
*/

`timescale 1ns / 1ps
`include "../dpmem/src/dpmem.v"
`include "../fetch/src/fetch.v"
`include "../int_cont/src/int_cont.v"
`include "../regf/src/mem_regf.v"
`include "../regf/src/sync_regf.v"
`include "../regf/src/regf_status.v"
`include "../alu/src/alu_r.v"
`include "../src/sxp.v"
//`define SYNC_REG

module test_sxp ();

parameter RF_WIDTH = 4;
parameter RF_SIZE = 16;

// Interface signals
reg clk;
integer clk_cnt;
reg reset_b;
wire [31:0] mem_inst;
wire [31:0] spqa;
reg [31:0] ext_ra;
reg [31:0] ext_rb;
reg [31:0] ext_result;
reg [3:0] ext_cvnz;
reg halt;
reg int_req;
reg [15:0] int_num;

wire int_rdy;
wire int_srv_req;
wire [15:0] int_srv_num;
wire [31:0] ext_alu_a;
wire [31:0] ext_alu_b;
wire [31:0] ext_inst;
wire ext_inst_vld;
wire ext_we;
wire [31:0] extw_data;
wire [31:0] extw_addr;
wire [31:0] extr_addr;
wire [31:0] spl_addr;
wire [31:0] spw_addr;
wire spw_we;
wire [31:0] spw_data;
wire [31:0] mem_pc;

// Inst mem signals
reg [31:0] prg_load_addr;
reg [31:0] prg_load_inst;
reg prg_load_we;

integer i;
reg first_inst;
integer inst_cnt;
integer last_clk;
integer first_clk;
integer delta_clk;
integer test_cnt;

reg print_regs;
reg finish_sim;

sxp #(RF_WIDTH,RF_SIZE) i_sxp
		(.clk(clk),
		 .reset_b(reset_b),
		 .mem_inst(mem_inst),		// Instruction ram read data
		 .spqa(spqa),			// scratch pad memory port A output
                 .ext_ra(ext_ra),		// extension register a
		 .ext_rb(ext_rb),		// extension register b
		 .ext_result(ext_result),	// extension bus result data
		 .ext_cvnz(ext_cvnz),		// extension bus result data
		 .halt(halt),			// Halt processor completely
                 .int_req(int_req),		// interupt request signal
                 .int_num(int_num),		// interupt number for request

		 .int_rdy(int_rdy),		// processor interupt controller ready
 		 .int_srv_req(int_srv_req),	// signal that interupt is being serviced
 		 .int_srv_num(int_srv_num),	// interupt number that is being serviced
		 .ext_alu_a(ext_alu_a),		// reg a for ext alu
		 .ext_alu_b(ext_alu_b),		// reg b for ext alu
                 .ext_inst(ext_inst),		// copy of 32 bit instruction for ext architecture
		 .ext_inst_vld(ext_inst_vld),	// instruction valid signal for ext architecture
		 .ext_we(ext_we),		// extension bus write enable (dest)
		 .extw_data(extw_data),		// data to write to extension bus (dest)
		 .extw_addr(extw_addr),		// address to write to extension bus (dest)
		 .extr_addr(extr_addr),		// address to read from extension bus 
		 .spl_addr(spl_addr),		// scratch pad memory (Port A) load address (from reg file A)
		 .spw_addr(spw_addr),		// scratch pad memory (Port B) write address (from ALU passthough)
 		 .spw_we(spw_we),		// scretch pad memory (Port B) write enable (from wb source section)
		 .spw_data(spw_data),		// scratch pad memory (Port B) write data (from ALU passthrough) 
		 .mem_pc(mem_pc));		// Program Counter Address
		  

dpmem #(32, 64) inst_memory (
                  .clk(clk),
		  .reset_b(reset_b),
		  .addra(mem_pc),	// address a port
		  .addrb(32'b 0),	// address b port
	          .wea(1'b 0),		// write enable a
	          .web(1'b 0),		// write enable b
	          .oea(1'b 1),		// output enable a
	          .oeb(1'b 0),		// output enable b
		  .da(32'b 0),		// data input a
		  .db(32'b 0),		// data input b
		
		  .qa(mem_inst),		// data output a
		  .qb());			// data output b

dpmem #(32, 64) sp_memory (
                  .clk(clk),
		  .reset_b(reset_b),
		  .addra(spl_addr),		// address a port
		  .addrb(spw_addr),		// address b port
	          .wea(1'b 0),			// write enable a
	          .web(spw_we),			// write enable b
	          .oea(1'b 1),			// output enable a
	          .oeb(1'b 0),			// output enable b
		  .da(32'b 0),			// data input a
		  .db(spw_data),		// data input b
		
		  .qa(spqa),			// data output a
		  .qb());			// data output b
initial
  begin
    $dumpfile("./icarus.vcd");
    $dumpvars(2, test_sxp);
  end

   
initial
  begin
    clk = 1'b 0;
    clk_cnt = 0;
    #10 forever 
      begin
        #2.5 clk = ~clk;
        if (clk)
          clk_cnt = clk_cnt + 1;
      end
  end


initial
  begin
    finish_sim = 1'b 0;
    first_inst = 1'b 0;
    int_req = 1'b 0;
    halt = 1'b 1;
    ext_ra = 32'b 0;
    ext_rb = 32'b 0;
    ext_result = 32'b 0;
    prg_load_we = 1'b 0;
    reset_b = 1'b 1;
    @(negedge clk);
    reset_b = 1'b 0;
    @(negedge clk);
    reset_b = 1'b 1;

    @(negedge clk);
    $display ("Showing regs");

   program_load;
    @(negedge clk);
    @(negedge clk);
    @(negedge clk);
    halt = 1'b 0;

    halt = 1'b 0;
    test_cnt = 0;
    while (!finish_sim)
      begin
        test_cnt = test_cnt + 1;
        //#1 halt = ~halt;
        if (test_cnt == 14)
          begin
            $display ("Interupt 1 is being issued");
            int_req = 1'b 1;
            int_num = 16'd 1;
          end
        else
          begin
            int_req = 1'b 0;
            int_num = 16'd 0;
          end
        @(negedge clk);
      end

    $display ("SXP Proc test finished");
    delta_clk = last_clk - first_clk;
    $display ("Efficiency ratio was  %d / %d",inst_cnt ,delta_clk);
    halt = 1'b 1;
    @(negedge clk);
    $stop;
  end    

always @(posedge clk or negedge reset_b)
  begin
    if (!reset_b)
      finish_sim <= 1'b 0;
    else
      if (ext_we)
        finish_sim <= 1'b 1;
  end

always @(negedge clk)
  begin
    if ((i_sxp.inst_vld_4)&&!first_inst)
      begin
        first_inst = 1'b 1;
        first_clk = clk_cnt;
        inst_cnt = 0;
      end
    else
      if (i_sxp.inst_vld_4 && !halt)
        begin
          inst_cnt = inst_cnt + 1;
          last_clk = clk_cnt;
        end
  end

always @(negedge clk)
  begin
    if (i_sxp.inst_vld_4 && !halt && !i_sxp.nop_detect)
      begin
        if (!i_sxp.nop_detect)
          print_regs <= #1 1'b 1;
        else
          print_regs <= 1'b 0;
      end
    else
      print_regs <= 1'b 0;
  end

always @(negedge clk)
  begin
    if (print_regs)
      begin
        `ifdef SYNC_REG
        i_sxp.i_regf.reg_display;
        `else
        i_sxp.i_regf.i1_dpmem.mem_display;
        `endif
        $display ("-----------------------------");
      end
  end

task program_load;
integer prg_load_ptr;
  begin
    $readmemh ("test.sxp",inst_memory.mem);
  end
endtask
endmodule

/*
 *  $Id: test_sxp.v,v 1.1 2001-10-26 22:01:01 samg Exp $ 
 *  Module : test_sxp
 *  Author : Sam Gladstone 
 *  Function : Testbench for SXP processor 
 *  $Log: not supported by cvs2svn $
 */
