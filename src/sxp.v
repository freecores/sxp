/* SXP (Simple Extensible Pipeline) Core
 *
 * Architecture - Sam Gladstone
 *
 */

// `define SYNC_REG

module sxp 
		(clk,
		 reset_b,
		 mem_inst,		// Instruction ram read data
		 spqa,			// scratch pad memory port A output (load data)
                 ext_ra,		// extension register a
		 ext_rb,		// extension register b
		 ext_result,		// extension bus result data
		 ext_cvnz,		// extension ALU flag result
                 halt,			// halts operation of processor
                 int_req,		// interupt request
		 int_num,		// interupt number for request

		 int_rdy,		// interupt controller ready for interupt
		 int_srv_req,		// signal that interupt is being serviced
                 int_srv_num,		// interupt number being serviced
		 ext_alu_a,		// reg A for ext ALU
		 ext_alu_b,		// reg B for ext ALU
                 ext_inst,		// copy of 32 bit instruction for extension architecture
		 ext_inst_vld,		// test ext architecture that instruction is valid
		 ext_we,		// extension bus write enable (dest)
 		 extr_addr,		// ext bus address to read from (qra)
		 extw_data,		// data to write to extension bus (dest)
                 extw_addr,		// ext address to write to
		 spl_addr,		// scratch pad memory (Port A) load address (from reg file A)
		 spw_addr,		// scratch pad memory (Port B) write address (from ALU passthough)
 		 spw_we,		// scretch pad memory (Port B) write enable (from wb source section)
		 spw_data,		// scratch pad memory (Port B) write data (from ALU passthrough) 
		 mem_pc);		// Program Counter Address
		  

parameter RF_WIDTH = 4;
parameter RF_SIZE  = 16;

input clk;
input reset_b;
input [31:0] mem_inst;
input [31:0] spqa;
input [31:0] ext_ra;
input [31:0] ext_rb;
input [31:0] ext_result;
input [3:0] ext_cvnz;
input halt;
input int_req;
input [15:0] int_num;


output int_rdy;
output int_srv_req;
output [15:0] int_srv_num;
output [31:0] ext_alu_a;
output [31:0] ext_alu_b;

output  ext_we;
reg     ext_we;

output [31:0] extr_addr;
output [31:0] extw_data;
output [31:0] extw_addr;
output [31:0] spl_addr;
output [31:0] spw_addr;

output spw_we;
reg spw_we;

output [31:0] spw_data;
output [31:0] mem_pc;

output [31:0] ext_inst;

output ext_inst_vld;


// Scratch pad signal and regs
reg [31:0] spl_addr_3;
reg [31:0] spl_addr_3_wb;
reg [31:0] spl_data_3_wb;
reg spl_we_3_wb;
reg [31:0] spl_data;


// Internal Wires
wire stall_1_2;			// signal to stall pipelines 1 and 2
reg [31:0] wb_data;		// write back registered data


// Fetch interface wires
wire  set_pc;
wire flush_pipeline;		// signal to invalidate all pipelines
wire stall_fetch;		// stall for fetch module

// Regf interface wires
reg wec;			// write enable for RF write to port C
wire [31:0] qra;		// regfile output for A
wire [31:0] qrb;		// regfile output for B


// ALU interface wires 
wire [3:0] cvnz_a;		// base ALU A flags
wire [3:0] cvnz_b;		// base ALU B flags
wire [31:0] ya;			// A result from ALU 
wire [31:0] yb;			// B result from ALU 


// Pipeline #1 wires and regs
wire stall_1;			// stall 1st pipeline (fetch)
wire [31:0] pcn_1;		// Program Counter + 1
wire inst_vld_1;		// instruction valid from pipeline 1
wire [31:0] inst_1; 		// 32 bit instruction from pipeline 1

wire [1:0] dest_cfg_1;		// destination configuration from pipeline 1
wire [RF_WIDTH-1:0] dest_addr_1;// destination address for reg file writeback
wire [2:0] src_cfg_1;		// ALU source configuration from pipeline 1
wire [2:0] alu_cfg_1;		// ALU configuration from pipeline 1
wire [3:0] wb_cfg_1;		// write back source configuration from pipeline 1

wire [RF_WIDTH-1:0] addra_1;	// address for reg file A from pipeline 1
wire [RF_WIDTH-1:0] addrb_1;	// address for reg file B from pipeline 1
wire [RF_WIDTH-1:0] addrc_1;	// address for reg file write C from pipeline 1
wire [15:0] imm_1;		// immediate value from pipeline 1

reg dest_en_1;			// destination register enable for scoreboarding
reg a_en;			// A reg is enable for reg file and scoreboarding
reg b_en;			// B reg is enable for reg file and scoreboarding

wire cond_jump_1;		// lsb of instruction is used for conditional reg jumps
wire jz_1;			// jump if zero instruction (false is jump if not zero) 
wire jal_1;			// jump and link from pipeline 1


// Pipeline #2 (from memory latency) wires and regs
wire stall_2;			// stall 2nd pipeline
reg  inst_vld_2;		// instruction valid signal from pipeline 2
reg  [1:0] dest_cfg_2;		// destination configuration from pipeline 2
reg  [RF_WIDTH-1:0] dest_addr_2;// destination address for RF write from pipeline 2
reg  [2:0] src_cfg_2;		// ALU source configuration from pipeline 2
reg  [2:0] alu_cfg_2;		// ALU configuration from pipeline 2
reg  [3:0] wb_cfg_2;		// write back source configuration from pipeline 2
reg  [15:0] imm_2;		// immediate value from pipeline 2
reg  [31:0] pcn_2;		// next PC address from pipeline 2 
reg  [31:0] a_2;		// Selected ALU A from pipeline 2
reg  [31:0] b_2;		// Selected ALU B from pipeline 2
reg  cond_jump_2;		// Conditional jump from pipeline 2
reg  jz_2;			// jump if zero instruction (false is jump if not zero) 
reg  jal_2;			// jump and link from pipeline 2


// Pipeline #3 (for ALU setup) wires and regs
reg [31:0] r_qra;		// load stall protection register

wire stall_3;			// stall 3rd pipeline
reg  inst_vld_3;		// instruction valid signal from pipeline 3
reg  [1:0] dest_cfg_3;		// destination configuration from pipeline 3
reg  [RF_WIDTH-1:0] dest_addr_3;// destination address for RF write from pipeline 3
reg  [2:0] alu_cfg_3;		// ALU configuration from pipeline 3
reg  [3:0] wb_cfg_3;		// write back source configuration from pipeline 3
reg  [31:0] pcn_3;		// next program counter value for pipeline 3
reg  [31:0] a_3;		// ALU input A from pipeline 3
reg  [31:0] b_3;		// ALU input B from pipeline 3
reg  cond_jump_3;		// Conditional jump from pipeline 3
reg  jz_3;			// jump if zero instruction (false is jump if not zero) 
reg  jal_3;			// jump and link from pipeline 3


// Pipeline #4 (WB and destination logic) wires and regs
wire stall_4;			// stall 4th pipeline
reg  set_pc_4;			// preliminary signal to set pc in pipeline 4
reg  inst_vld_4;		// instruction valid signal from pipeline 4
reg  [1:0] dest_cfg_4;		// destination configuration from pipeline 4
reg  [RF_WIDTH-1:0] dest_addr_4;// destination address for RF write from pipeline 4
reg  [3:0] wb_cfg_4;		// write back source configuration from pipeline 4
reg  [31:0] spqa_4;		// scratch pad output from pipeline 4 
reg  [31:0] ya_4;		// used for scratch pad memory stores
reg  [31:0] yb_4;		// used for scratch pad memory stores
reg  [31:0] ext_result_4;	// ext ALU result from pipeline 4
reg  [31:0] pcn_4;		// next program counter value for pipeline 4
reg  [3:0] ext_cvnz_4;		// ext ALU flags from pipeline 4
reg  [3:0] cvnz_a_4;		// ALU a result from pipeline 4
reg  [3:0] cvnz_b_4;		// ALU b result from pipeline 4
wire [RF_WIDTH-1:0] addrc_wb;	// connects dest_addr_4 to reg file write port C
reg  cond_jump_4;		// Conditional jump from pipeline 4
reg  jz_4;			// jump if zero instruction (false is jump if not zero) 
reg  jal_4;			// jump and link from pipeline 4

wire [31:0] regc_data;		// data to be written to port C (reg file)

// stall signal handling
assign stall_1 = stall_1_2 || halt;
assign stall_2 = stall_1_2 || halt;
assign stall_3 = halt;
assign stall_4 = halt;


// Interupt signals
wire idle;
wire jal_req;
wire safe_switch;
wire nop_detect;
wire int_jal_req;

// Processor Interupt controller
int_cont i_int_cont(
                .clk(clk),                      // system clock
                .reset_b(reset_b),              // system reset
                .halt(halt),                    // processor halt signal
                .int_req(int_req),              // signal that an interupt is requested
                .int_num(int_num),              // interupt number that is being requested
                .safe_switch(safe_switch),      // signal that processor is safe to switch
                .nop_detect(nop_detect),        // signal that the processor just executed a NOP instruction
 
                .int_rdy(int_rdy),              // 1 when int req will be serviced when requested
                .idle(idle),          		// signal to idle processor;
                .jal_req(jal_req),              // signal to fetch to insert the JAL instruction
                .int_srv_req(int_srv_req),      // signal that the interupt was serviced
                .int_srv_num(int_srv_num));     // interupt number that was serviced



// Fetch Section
fetch  	i_fetch (
		 .clk(clk),			// system clock
		 .reset_b(reset_b),		// system reset
    		 .stall(stall_1),		// stall for fetch
		 .set_pc(set_pc),		// signal to set the program counter
		 .pc_init(wb_data),		// value to set the program counter to 
		 .mem_inst(mem_inst),		// instruction that was read from memory
                 .idle(idle),			// idle fetch process 
                 .jal_req(jal_req),		// interupt jump and link request;
                 .int_srv_num(int_srv_num),	// interupt number for JAL

		 .int_jal_req(int_jal_req),	// interupt JAL signal request
		 .mem_pc(mem_pc),		// address to get from memory 
		 .pcn(pcn_1),			// Next PC address
		 .flush_pipeline(flush_pipeline),	// Invalidate all pipelines (done during jumps)
    		 .inst_vld(inst_vld_1),		// instruction valid flag
		 .inst(inst_1));		// instruction to be sent to pipeline

assign ext_inst = inst_1;
assign ext_inst_vld = inst_vld_1;

// Need to begin breaking out wire meaning for the next section
assign dest_cfg_1 = inst_1[31:30];
assign src_cfg_1 = inst_1[29:27];
assign alu_cfg_1 = inst_1[26:24];
assign wb_cfg_1 = inst_1[23:20];

assign dest_addr_1 = inst_1[19:16];
assign addra_1 = (src_cfg_1 == 3'b001) ? dest_addr_1 : inst_1[15:12];
assign addrb_1 = inst_1[11:8];
assign imm_1 = inst_1[15:0]; 

assign cond_jump_1 = inst_1[0]; 
assign jz_1 = inst_1[1]; 
assign jal_1 = (!src_cfg_1[0] && !src_cfg_1[2]) ? inst_1[2] : int_jal_req; 
// This protects jal against imm and ext type sources

// ----------------------- Reg File Section ------------------------

always @(src_cfg_1 or inst_vld_1 or dest_cfg_1)
  begin
    if (inst_vld_1) 
      begin
        dest_en_1 = !dest_cfg_1;		// Destination is register
        case (src_cfg_1)
          3'b 000 : begin
                      a_en = 1'b 1;
                      b_en = 1'b 1;
                    end  
          3'b 001 : begin
                      a_en = 1'b 1;
                      b_en = 1'b 0;
                    end  
          3'b 010 : begin
                      a_en = 1'b 0;
                      b_en = 1'b 1;
                    end  
          3'b 011 : begin
                      a_en = 1'b 0;
                      b_en = 1'b 0;
                    end  
          3'b 100 : begin
                      a_en = 1'b 1;
                      b_en = 1'b 0;
                    end  
          3'b 101 : begin
                      a_en = 1'b 0;
                      b_en = 1'b 1;
                    end  
          3'b 110 : begin
                      a_en = 1'b 0;
                      b_en = 1'b 0;
                    end  
          3'b 111 : begin
                      a_en = 1'b 0;
                      b_en = 1'b 0;
                    end  
         endcase
      end
    else
      begin
        a_en = 1'b 0;
        b_en = 1'b 0;
        dest_en_1 = 1'b 0;
      end
  end

`ifdef SYNC_REG
sync_regf #(4,16) i_regf ( 
	        .clk(clk),			// system clock
		.reset_b(reset_b),		// power on reset
		.halt(halt),			// system wide halt
	   	.addra(addra_1),		// Port A read address 
                .a_en(a_en),			// Port A read enable
		.addrb(addrb_1),		// Port B read address 
                .b_en(b_en),			// Port B read enable 
		.addrc(addrc_wb),		// Port C write address 
	        .dc(regc_data),			// Port C write data 
		.wec(wec),			// Port C write enable 

		.qra(qra),			// Port A registered output data	
		.qrb(qrb));			// Port B registered output data 	
`else
mem_regf #(4,16) i_regf ( 
	        .clk(clk),			// system clock
		.reset_b(reset_b),		// power on reset
		.halt(halt),			// system wide halt
	   	.addra(addra_1),		// Port A read address 
                .a_en(a_en),			// Port A read enable
		.addrb(addrb_1),		// Port B read address 
                .b_en(b_en),			// Port B read enable 
		.addrc(addrc_wb),		// Port C write address 
	        .dc(regc_data),			// Port C write data 
		.wec(wec),			// Port C write enable 

		.qra(qra),			// Port A registered output data	
		.qrb(qrb));			// Port B registered output data 	
`endif
 
regf_status #(4,16) i_regf_status(
                .clk(clk),            		// system clock
                .reset_b(reset_b),        	// power on reset
		.stall(stall_1_2),		// stall in pipeline 1 and 2 
		.halt(halt),			// system wide stall signal
                .dest_en(dest_en_1),        	// instr has dest register (en scoreboarding)
                .dest_addr(dest_addr_1),      	// destination address from instruction
                .wec(wec),   	         	// port C write back request
                .addrc(addrc_wb),          	// port C write back address
                .addra(addra_1),          	// reg file address reg A (source 1)
                .addrb(addrb_1),          	// reg file address reg B (source 2)
		.a_en(a_en),			// Reg A is enabled in instruction
		.b_en(b_en),			// Reg B is enabled in instruction
		.flush_pipeline(flush_pipeline),// Reinitialize status after pipeline flush
 
                .safe_switch(safe_switch),    // safe to context switch or interupt;
                .stall_regf(stall_1_2));    // stall the reg file and modules prior


`ifdef SYNC_REG
always @(inst_vld_1 or stall_1_2 or  dest_cfg_1 or dest_addr_1 or src_cfg_1 or 
         alu_cfg_1 or wb_cfg_1 or imm_1 or pcn_1 or cond_jump_1 or b_en or
         jz_1 or jal_1)
  begin
    inst_vld_2 = (stall_1_2 || flush_pipeline) ? 1'b 0 : inst_vld_1; 		// Breaks the pipeline when reg needs to be stalled
    dest_cfg_2 = dest_cfg_1;
    dest_addr_2 = dest_addr_1;
    src_cfg_2 = src_cfg_1;
    alu_cfg_2 = alu_cfg_1;
    wb_cfg_2 = wb_cfg_1;
    imm_2 = imm_1;
    pcn_2 = pcn_1;
    cond_jump_2 = cond_jump_1 & b_en;				// not valid unles b is enabled for read
    jz_2 = jz_1; 
    jal_2 = jal_1;	
  end
`else
// There is a pipeline inside the memory for the regfile 
// Need to account for memory pipeline to keep everything alligned 
always @(posedge clk or negedge reset_b)
  begin
    if (!reset_b)
      begin
        inst_vld_2 <= 'b 0;
        dest_cfg_2 <= 'b 0;
        dest_addr_2 <= 'b 0;
        src_cfg_2 <= 'b 0;
        alu_cfg_2 <= 'b 0;
        wb_cfg_2 <= 'b 0;
	imm_2 <= 'b 0;
        pcn_2 <= 'b 0;
        cond_jump_2 <= 'b 0;
        jz_2 <= 'b 0; 
        jal_2 <= 'b 0;
      end
    else
      if (flush_pipeline)
        inst_vld_2 <= 'b 0;
      else
        if (!halt)
          begin
            inst_vld_2 <= (stall_1_2) ? 1'b 0 : inst_vld_1; 	// Breaks the pipeline when reg needs to be stalled
            if (inst_vld_1 && !stall_1_2)			// This will save some power by causing unecessary toggling
              begin
                dest_cfg_2 <= dest_cfg_1;
                dest_addr_2 <= dest_addr_1;
                src_cfg_2 <= src_cfg_1;
                alu_cfg_2 <= alu_cfg_1;
                wb_cfg_2 <= wb_cfg_1;
                imm_2 <= imm_1;
                pcn_2 <= pcn_1;
                cond_jump_2 <= cond_jump_1 & b_en;	// not valid unles b is enabled for read
                jz_2 <= jz_1; 
 		jal_2 <= jal_1;	
              end
          end
  end
`endif
 
// Not sure if protection is needed or which stall (2 or 3) to use? 
// Load Stall protection circuit.
always @(posedge clk or negedge reset_b)
  begin
    if (!reset_b)
      r_qra <= 'b 0;
    else
      if (!halt)
        r_qra <= qra;
  end
assign spl_addr = (halt) ? r_qra : qra; // scratch pad memory load address from Reg A in pipeline 2
assign extr_addr = (halt) ? r_qra : qra; // ext bus load address from Reg A in pipeline 2
// End of memory load with stall protecttion


// Ready to select source data for ALU
always @(src_cfg_2 or qra or qrb or ext_ra or ext_rb or pcn_2 or imm_2)
  begin
    case (src_cfg_2)
      3'b 000 : begin
                  a_2 = qra;
                  b_2 = qrb;
                end
      3'b 001 : begin
                  a_2 = qra;
                  b_2 = {16'b 0, imm_2};
                end
      3'b 010 : begin
                  a_2 = pcn_2;
                  b_2 = qrb;
                end
      3'b 011 : begin
                  a_2 = pcn_2;
                  b_2 = {16'b 0, imm_2};
                end
      3'b 100 : begin
                  a_2 = qra;
                  b_2 = ext_rb;
                end
      3'b 101 : begin
                  a_2 = ext_ra;
                  b_2 = qrb;
                end
      3'b 110 : begin
                  a_2 = ext_ra;
                  b_2 = {16'b 0, imm_2};
                end
      3'b 111 : begin
                  a_2 = ext_ra;
                  b_2 = ext_rb;
                end
    endcase
  end


// --------- 3rd pipeline (ALU signals) ----------- 
always @(posedge clk or negedge reset_b)
  begin
    if (!reset_b)
      begin
        inst_vld_3 <= 'b 0;
        a_3 <= 'b 0;
        b_3 <= 'b 0;
        dest_cfg_3 <= 'b 0;
        dest_addr_3 <= 'b 0;
        alu_cfg_3 <= 'b 0;
        wb_cfg_3 <= 'b 0;
	pcn_3 <= 'b 0;
        cond_jump_3 <= 'b 0;
        jz_3 <= 'b 0; 
	jal_3 <= 'b 0;
	spl_addr_3 <= 'b 0;
	spl_addr_3_wb <= 'b 0;
	spl_data_3_wb <= 'b 0;
        spl_we_3_wb <= 'b 0;
      end
    else
      if (flush_pipeline)		// flush pipeline take priority
        inst_vld_3 <= 'b 0;
      else
        if (!stall_3)
          begin
            inst_vld_3 <= inst_vld_2;
            if (inst_vld_2)		// For power savings
              begin
                a_3 <= a_2;
                b_3 <= b_2;
                dest_cfg_3 <= dest_cfg_2;
                dest_addr_3 <= dest_addr_2;
                alu_cfg_3 <= alu_cfg_2;
                wb_cfg_3 <= wb_cfg_2;
		pcn_3 <= pcn_2;
                cond_jump_3 <= cond_jump_2;
                jz_3 <= jz_2; 
		jal_3 <= jal_2;
	        spl_addr_3 <= spl_addr;
	        spl_addr_3_wb <= spw_addr;
	        spl_data_3_wb <= spw_data;
		spl_we_3_wb <= spw_we;
              end          
          end
  end

assign ext_alu_a = a_3;			// allow ext ALU to see the inputs
assign ext_alu_b = b_3;			// allow ext ALU to see the inputs

alu      i_alu ( 
		.opcode(alu_cfg_3),	// alu function select
		.a(a_3),		// a operand
		.b(b_3),		// b operand
		.cin(1'b 0),		// carry input		(How do we handle this?)
		.ya(ya),		// data output
		.yb(yb),		// data output
		.cvnz_a(cvnz_a),	// flag output for a
		.cvnz_b(cvnz_b)		// flag output for b
	        );

always @(spqa or spw_we or spl_addr_3 or spw_addr or spw_data or spl_we_3_wb or spl_addr_3_wb or spl_data_3_wb)
  begin
    if ((spl_addr_3 == spw_addr) && spw_we)
      spl_data = spw_data;
    else
      if ((spl_addr_3 == spl_addr_3_wb) && spl_we_3_wb)
        spl_data = spl_data_3_wb;
      else
        spl_data = spqa;
  end 


// New Pipeline 4 starts here
always @(posedge clk or negedge reset_b)
  begin
    if (!reset_b)
      begin
        ext_result_4 <= 'b 0;
        ext_cvnz_4 <= 'b 0;
	spqa_4 <= 'b 0;
        ya_4 <= 'b 0;
        cvnz_a_4 <= 'b 0;
        yb_4 <= 'b 0; 
        cvnz_b_4 <= 'b 0;
        inst_vld_4 <= 'b 0;
        wb_cfg_4 <= 'b 0;
        dest_addr_4 <= 'b 0;
        dest_cfg_4 <= 'b 0;
	pcn_4 <= 'b 0;
	cond_jump_4 <= 'b 0;
        jz_4 <= 'b 0; 
	jal_4 <= 'b 0;
      end
    else
      if (flush_pipeline)			// Pipeline flush takes priority over stall
        inst_vld_4 <= 'b 0;
      else
        if (!stall_4)
          begin
            inst_vld_4 <= inst_vld_3;
            if (inst_vld_3)			// For power savings
              begin
                ext_result_4 <= ext_result;
                ext_cvnz_4 <= ext_cvnz;
	        spqa_4 <= spl_data;
                ya_4 <= ya;
                cvnz_a_4 <= cvnz_a;
                yb_4 <= yb;		
                cvnz_b_4 <= cvnz_b;
                inst_vld_4 <= inst_vld_3;
                wb_cfg_4 <= wb_cfg_3;
                dest_addr_4 <= dest_addr_3;
                dest_cfg_4 <= dest_cfg_3;
		pcn_4 <= pcn_3;
	        cond_jump_4 <= cond_jump_3;
                jz_4 <= jz_3; 
		jal_4 <= jal_3;
              end
          end
  end

always @(wb_cfg_4 or ya_4 or cvnz_a_4 or yb_4 or cvnz_b_4 or spqa_4 or ext_cvnz_4 or ext_result_4)
  begin
    case (wb_cfg_4) 
      4'b 0000 : wb_data = ya_4;
      4'b 0001 : wb_data = yb_4;
      4'b 0010 : wb_data = spqa_4;
      4'b 0011 : wb_data = ext_result_4;
      4'b 0100 : wb_data = { {31{1'b 0}} , cvnz_a_4[0]}; 	// Store Z
      4'b 0101 : wb_data = { {31{1'b 0}} , cvnz_a_4[1]}; 	// Store N
      4'b 0110 : wb_data = { {31{1'b 0}} , cvnz_a_4[2]}; 	// Store V
      4'b 0111 : wb_data = { {31{1'b 0}} , cvnz_a_4[3]}; 	// Store C
      4'b 1000 : wb_data = { {31{1'b 0}} , cvnz_b_4[0]}; 	// Store Z
      4'b 1001 : wb_data = { {31{1'b 0}} , cvnz_b_4[1]}; 	// Store N
      4'b 1010 : wb_data = { {31{1'b 0}} , cvnz_b_4[2]}; 	// Store V
      4'b 1011 : wb_data = { {31{1'b 0}} , cvnz_b_4[3]}; 	// Store C
      4'b 0100 : wb_data = { {31{1'b 0}} , ext_cvnz_4[0]}; 	// Store Z
      4'b 0101 : wb_data = { {31{1'b 0}} , ext_cvnz_4[1]}; 	// Store N
      4'b 0110 : wb_data = { {31{1'b 0}} , ext_cvnz_4[2]}; 	// Store V
      4'b 0111 : wb_data = { {31{1'b 0}} , ext_cvnz_4[3]}; 	// Store C
    endcase
  end

// Destination handling only write enable is instruction is valid
always @(dest_cfg_4 or inst_vld_4 or cond_jump_4 or yb_4[0] or jz_4 or set_pc)
  begin
    wec = 1'b 0;		// Write enable port C (reg file)
    set_pc_4 = 1'b 0;		// set new PC val
    spw_we = 1'b 0; 		// scratch pad write enable
    ext_we = 1'b 0;		// write enable for ext bus 
    if (inst_vld_4)
      case (dest_cfg_4)
        2'b 00 : wec = 1'b 1; 
        2'b 01 : begin
                   set_pc_4 = (cond_jump_4) ? (yb_4[0]^jz_4) : 1'b 1;
                   wec = jal_4 & set_pc;	// Must be set_pc not set_pc_4
                 end
        2'b 10 : spw_we = 1'b 1;
        2'b 11 : ext_we = 1'b 1;
        default: begin
                   wec = 1'b 0;
                   set_pc_4 = 1'b 0;
                   spw_we = 1'b 0;
                   ext_we = 1'b 0;
                 end
      endcase
    else 
      begin
        wec = 1'b 0;
        set_pc_4 = 1'b 0;
        spw_we = 1'b 0;
        ext_we = 1'b 0;
      end
  end

  assign regc_data = (jal_4 && set_pc) ? pcn_4 : wb_data;	// data to write to reg port C
  assign set_pc = (wb_data == pcn_4) ? 1'b 0 : set_pc_4;	// speed feature, don't jump 0
  assign addrc_wb = dest_addr_4;				// reg file write back address 

  assign nop_detect = inst_vld_4 & ~(wec | set_pc | spw_we | ext_we);	// 1 when no operation is being done

  assign extw_data = wb_data;					// extension data for writing
  assign extw_addr = yb_4;

  assign spw_addr = yb_4;					// data from write back pipeline 4
  assign spw_data = wb_data;					// data from pipelined ALU output B

endmodule


/*
 * $Id: sxp.v,v 1.2 2001-10-26 22:07:34 samg Exp $
 * Module : sxp.v
 * Scope  : top level module
 * Author : Sam Gladstone
 * Function : SXP processor top level
 *
 * $Log: not supported by cvs2svn $
 * Revision 1.1  2001/10/26 20:03:48  samg
 * 1st version
 *
 *
 */ 
