module SDRAM (
		input 				clk_50m,
		input					rst_n,

		input	[2:0]			key,

		output	[6:0]		hex0,
		output	[6:0]		hex1,
		output	[6:0]		hex2,
		output	[6:0]		hex3,

		output	[12:0]	sdram_addr,
		output	[1:0]		sdram_ba,
		output				sdram_cas_n,
		output				sdram_cke,
		output				sdram_clk,
		output				sdram_cs_n,
		inout		[31:0]	sdram_dq,
		output	[3:0]		sdram_dqm,
		output				sdram_ras_n,
		output				sdram_we_n		
);

reg		[7:0]		counter;
reg		[1:0]		key1_dly,key2_dly;
reg		[15:0]	display_latch;


wire	[15:0]		display;
wire					read;

reg					latch;



reg					wr1_wen;

wire					clk_27m;


assign	write = key1_dly[1] && !key1_dly[0];
assign  	read  = key2_dly[1] && !key2_dly[0];

always @ (posedge clk_27m or negedge rst_n)
begin
    if (!rst_n)
    begin
    	key1_dly <= 2'b11;
    	key2_dly <= 2'b11;
    	counter <= 0;
    	wr1_wen <= 1'b0;
    	latch <= 1'b0;
    end
    else	
    begin
      key1_dly <= {key1_dly[0],key[1]};
      key2_dly <= {key2_dly[0],key[2]};
		
	    if (wr1_wen)
			begin
				counter <= counter + 1;
				if (counter == 8'b0000_1111)
					wr1_wen <= 1'b0;
			end
			
      else if (write)
         wr1_wen <= 1'b1;
 
      latch <= read;
		
      if (latch)
         display_latch <= display;
    end
end

PLL_0002 pll_inst (
		.refclk   (clk_50m),   //  refclk.clk
		.rst      (!rst_n),      //   reset.reset
		.outclk_0 (clk_27m), // outclk0.clk
		.locked   ()          // (terminated)
);
	
	
Sdram_Control	u1	
	(	//	HOST Side
							.REF_CLK(clk_27m),
							.RESET_N(1'b1),
							//	FIFO Write Side 1
							.WR1_DATA({8'b0, counter}),
							.WR1(wr1_wen),
							.WR1_ADDR(0),
							.WR1_MAX_ADDR(16),			//预计写入256笔数据
							.WR1_LENGTH(9'h1),			//单次写入64笔数据
							.WR1_LOAD(!rst_n),
							.WR1_CLK(clk_27m),
							//	FIFO Read Side 1
							.RD1_DATA(display),
							.RD1(read),
							.RD1_ADDR(0),	
							.RD1_MAX_ADDR(16),
							.RD1_LENGTH(9'h1),			//单次读取64笔数据
							.RD1_LOAD(!rst_n || wr1_wen),	//当连续写完sdram时，需要重头写入“读取数据缓冲器”
							.RD1_CLK(clk_27m),
							//	SDRAM Side
							.SA(sdram_addr),
							.BA(sdram_ba),
							.CS_N(sdram_cs_n),
							.CKE(sdram_cke),
							.RAS_N(sdram_ras_n),
							.CAS_N(sdram_cas_n),
							.WE_N(sdram_we_n),
							.DQ(sdram_dq[15:0]),
							.DQM({sdram_dqm[1:0]}),
							.SDR_CLK(sdram_clk)	
	);
	
segment u2
(
		.cnt(display_latch[3:0]),
		.HEX(hex0)
);

segment u3
(
		.cnt(display_latch[7:4]),
		.HEX(hex1)
);

segment u4
(
		.cnt(display_latch[11:8]),
		.HEX(hex2)
);

segment u5
(
		.cnt(display_latch[15:12]),
		.HEX(hex3)
);

endmodule
