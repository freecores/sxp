/* Testbench for regfile 
   SXP Processor
   Sam Gladstone
*/
`timescale 1ns / 1ns
`include "../../dpmem/src/dpmem.v"
`include "../src/mem_regf.v"

module regf_test();

parameter WIDTH = 4;
parameter SIZE = 16;

reg clk;
reg reset_b;
reg halt;
reg [WIDTH-1:0] addra;
reg a_en;
reg [WIDTH-1:0] addrb;
reg b_en;
reg [WIDTH-1:0] addrc;
reg [31:0] dc;
reg wec;

wire [31:0] qra;
wire a_en_out;
wire [31:0] qrb;
wire b_en_out;

integer i;
integer clk_cnt;
integer errors;

mem_regf #(WIDTH,SIZE) i_regf  (
		.clk(clk),
		.reset_b(reset_b),
		.halt(halt),
		.addra(addra),			// reg a addr 
		.a_en(a_en),			// valid reg a read
		.addrb(addrb),			// reg b addr 
		.b_en(b_en),			// valid reg b read
		.addrc(addrc),			// reg c addr 
	        .wec(wec),			// write enable reg c
		.dc(dc),			// data input reg c
		
		.qra(qra),			// data output a
		.qrb(qrb));			// data output b


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
    errors = 0;
    addra = 'b 0;
    a_en = 1'b 0;
    addrb = 'b 0;
    b_en = 1'b 0;
    halt = 1'b 0;

    @(negedge clk);
    reset_b = 1'b 1;
    @(negedge clk);
    reset_b = 1'b 0;
    @(negedge clk);
    reset_b = 1'b 1;
    @(negedge clk);
    @(negedge clk);
    @(negedge clk);

    // Test out port C write functionality

    wec = 1'b 1;
    for (i=0;i<SIZE;i=i+1)
      begin
        addrc = i;
        dc = i;
        @(negedge clk);
      end
    wec = 1'b 0;

    for (i=0;i<SIZE;i=i+1)
      begin    
        addra = i;
        a_en = 1'b 1;
        addrb = SIZE - (i+1);
        b_en = 1'b 1;
        if (i==5)
          begin
            addrc = 'd 5;
            dc = 32'd 1234;
            wec = 1'b 1;
          end
        else
          wec = 1'b 0;
        if (i==7)
          begin
            halt = 1'b 1;
            @(negedge clk);
            @(negedge clk);
            @(negedge clk);
            @(negedge clk);
            halt = 1'b 0;
          end
        @(negedge clk);
      end

    a_en = 1'b 0;
    b_en = 1'b 0;

    @(negedge clk);
    @(negedge clk);
    @(negedge clk);
    @(negedge clk);
    @(negedge clk);
    @(negedge clk);
    
    $finish; 
  end

always @(posedge clk)
  begin
    if (!halt)
      $display ("after rising edge clk # %d, regf output a = %d",clk_cnt,qra); 

    if (!halt)
      $display ("after rising edge clk # %d, regf output b = %d",clk_cnt,qrb); 
  end


endmodule

/*  $Id: test_regf.v,v 1.1 2001-10-29 01:10:34 samg Exp $ 
 *  Module : test_regf 
 *  Author : Sam Gladstone
 *  Function : testbench for reg files
 *  $Log: not supported by cvs2svn $
 */

