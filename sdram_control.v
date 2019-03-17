module Sdram_Control(
		//	HOST Side
		REF_CLK,
		RESET_N,
		//	FIFO Write Side 1
		WR1_DATA,
		WR1,
		WR1_ADDR,
		WR1_MAX_ADDR,
		WR1_LENGTH,
		WR1_LOAD,
		WR1_CLK,
		//	FIFO Read Side 1
      RD1_DATA,
		RD1,
		RD1_ADDR,
		RD1_MAX_ADDR,
		RD1_LENGTH,
		RD1_LOAD,	
		RD1_CLK,
		//	SDRAM Side
		SA,
		BA,
		CS_N,
		CKE,
		RAS_N,
		CAS_N,
		WE_N,
		DQ,
		DQM,
		SDR_CLK
);

`include        "Sdram_Params.h"

//DSIZE=16		SDRAM数据总线宽度
//ASIZE=23		SDRAM的总地址宽度

//	HOST Side
input                           REF_CLK;                //
input                           RESET_N;                //
//	FIFO Write Side 1
input [`DSIZE-1:0]              WR1_DATA;               	//数据输入
input							        WR1;						 	//写使能
input	[`ASIZE-1:0]			     WR1_ADDR;					  	//写入起始地址
input	[`ASIZE-1:0]			     WR1_MAX_ADDR;				//写入最大地址
input	[8:0]					        WR1_LENGTH;					//写入数据的笔数
input							        WR1_LOAD;						//复位地址&清空fifo
input							        WR1_CLK;						//写fifo时钟
//	FIFO Read Side 1
output [`DSIZE-1:0]             RD1_DATA;               	//数据输出
input						           RD1;							//读请求
input	[`ASIZE-1:0]			     RD1_ADDR;						//读出起始地址
input	[`ASIZE-1:0]			     RD1_MAX_ADDR;				//读出最大地址
input	[8:0]					        RD1_LENGTH;					//读出数据的笔数
input							        RD1_LOAD;						//复位地址&清空fifo
input							        RD1_CLK;						//读fifo时钟
//	SDRAM Side
output  [11:0]                  SA;                     	//SDRAM 地址输出
output  [1:0]                   BA;                     	//SDRAM bank 地址
output  [1:0]                   CS_N;                  	//SDRAM 片选
output                          CKE;                    	//SDRAM 时钟使能
output                          RAS_N;                  	//SDRAM 行地址选通
output                          CAS_N;                  	//SDRAM 列地址选通
output                          WE_N;                   	//SDRAM 写使能
inout   [`DSIZE-1:0]            DQ;                     	//SDRAM 数据总线
output  [`DSIZE/8-1:0]          DQM;                    	//SDRAM 数据掩码行
output							     SDR_CLK;				    	//SDRAM 时钟
//	Internal Registers/Wires
//	Controller
reg		[`ASIZE-1:0]			mADDR;							//内部地址
reg		[8:0]				    	mLENGTH;							//内部长度
reg		[`ASIZE-1:0]			rWR1_ADDR;						//每次连续写的起始地址				
reg		[`ASIZE-1:0]			rRD1_ADDR;						//每次连续读的起始位置
reg		     			    		WR_MASK;							//Write port active mask
reg		     			    		RD_MASK;							//Read port active mask
reg							      mWR_DONE;						//写入完成标志位，一个sdram时钟周期
reg							      mRD_DONE;						//读取完成标志位，一个sdram时钟周期
reg							      mWR,Pre_WR;						//内部WR边缘捕获
reg							      mRD,Pre_RD;						//内部RD边缘捕获
reg 		[9:0] 					ST;								//控制状态
reg		[1:0] 					CMD;								//控制命令
reg									PM_STOP;							//页面模式停止标志位
reg								  	Read;								//读取有效标志位
reg									Write;							//写入有效标志位
reg	  [`DSIZE-1:0]    		mDATAOUT;        				//控制数据输出
wire    [`DSIZE-1:0]    mDATAIN;                			//控制数据输入
wire    [`DSIZE-1:0]    mDATAIN1;                			//控制数据输入1
wire                    CMDACK;                 			//控制器命令确认
//	DRAM Control
reg  	[`DSIZE/8-1:0]    DQM;                    //SDRAM 数据屏蔽线
reg     [11:0]          SA;                     //SDRAM 地址输出
reg     [1:0]           BA;                     //SDRAM bank地址
reg     [1:0]           CS_N;                   //SDRAM 片选
reg                     CKE;                    //SDRAM 时钟使能
reg                     RAS_N;                  //SDRAM 行地址使能
reg                     CAS_N;                  //SDRAM 列地址使能
reg                     WE_N;                   //SDRAM 写使能


wire    [11:0]          ISA;                    //SDRAM 地址输出
wire    [1:0]           IBA;                    //SDRAM bank地址
wire    [1:0]           ICS_N;                  //SDRAM 片选
wire                    ICKE;                   //SDRAM 时钟使能
wire                    IRAS_N;                 //SDRAM 行地址使能
wire                    ICAS_N;                 //SDRAM 列地址使能
wire                    IWE_N;                  //SDRAM 写使能
//	FIFO Control
reg								  OUT_VALID;					//输出数据请求读取端
reg								  IN_REQ;						//输入数据请求读取端
wire	[15:0]					  write_side_fifo_rusedw1;
wire	[15:0]					  read_side_fifo_wusedw1;
//	DRAM Internal Control
wire    [`ASIZE-1:0]    saddr;
wire                    load_mode;
wire                    nop;
wire                    reada;
wire                    writea;
wire                    refresh;
wire                    precharge;
wire                    oe;
wire							ref_ack;
wire							ref_req;
wire							init_req;
wire							cm_ack;
wire                    last_pm;


			
Sdram_PLL_0002 sdram_pll_inst (
		.refclk   (REF_CLK),   	// refclk.clk
		.rst      (1'b0),      	// reset.reset
		.outclk_0 (CLK), 			// outclk0.clk
		.outclk_1 (SDR_CLK), 	// outclk1.clk
		.locked   ()          	// (terminated)
);

control_interface u_control(
                .CLK(CLK),
                .RESET_N(RESET_N),
                .CMD(CMD),
                .ADDR(mADDR),
                .REF_ACK(ref_ack),
                .CM_ACK(cm_ack),
                .NOP(nop),
                .READA(reada),
                .WRITEA(writea),
                .REFRESH(refresh),
                .PRECHARGE(precharge),
                .LOAD_MODE(load_mode),
                .SADDR(saddr),
                .REF_REQ(ref_req),
				        .INIT_REQ(init_req),
                .CMD_ACK(CMDACK)
                );

command u_command(
                .CLK(CLK),
                .RESET_N(RESET_N),
                .SADDR(saddr),
                .NOP(nop),
                .READA(reada),
                .WRITEA(writea),
                .REFRESH(refresh),
				        .LOAD_MODE(load_mode),
                .PRECHARGE(precharge),
                .REF_REQ(ref_req),
				        .INIT_REQ(init_req),
                .REF_ACK(ref_ack),
                .CM_ACK(cm_ack),
                .OE(oe),
				        .PM_STOP(PM_STOP),
                .SA(ISA),
                .BA(IBA),
                .CS_N(ICS_N),
                .CKE(ICKE),
                .RAS_N(IRAS_N),
                .CAS_N(ICAS_N),
                .WE_N(IWE_N)
                );
                
Sdram_WR_FIFO 	u_write_fifo(
				.data(WR1_DATA),
				.wrreq(WR1),
				.wrclk(WR1_CLK),
				.aclr(WR1_LOAD),
				.rdreq(IN_REQ&WR_MASK),
				.rdclk(CLK),
				.q(mDATAIN1),
				.rdusedw(write_side_fifo_rusedw1)
				);
				
Sdram_RD_FIFO 	u_read_fifo(
				.data(mDATAOUT),
				.wrreq(OUT_VALID&RD_MASK),
				.wrclk(CLK),
				.aclr(RD1_LOAD),
				.rdreq(RD1),
				.rdclk(RD1_CLK),
				.q(RD1_DATA),
				.wrusedw(read_side_fifo_wusedw1)
				);

assign	mDATAIN	= (WR_MASK)	?	mDATAIN1	:	`DSIZE'hzzzz;  //mDATAIN为写FIFO出来的数据
assign  	DQ 		= oe ? mDATAIN : `DSIZE'hzzzz;				//数据总线为mDATAIN
assign 	last_pm 	= (ST==SC_CL+mLENGTH);							//控制状态=指令延迟+数据宽度，则last_pm置1

always @(posedge CLK)
begin
    SA <= ISA;
    BA <= IBA;
    CS_N <= ICS_N;
    CKE <= ICKE;
    RAS_N <= last_pm ? 1'b0 : IRAS_N;
    CAS_N <= last_pm ? 1'b1 : ICAS_N;
    WE_N <= last_pm ? 1'b0	: IWE_N; 
    PM_STOP <= last_pm ? 1'b1 : 1'b0;
    DQM <= (Read || Write) ? 2'b00 : 2'b11;
    mDATAOUT<= DQ;
end

always@(posedge CLK or negedge RESET_N)
begin
	if(RESET_N==0)
	begin
		CMD			<=  0;
		ST			<=  0;
		Pre_RD		<=  0;
		Pre_WR		<=  0;
		Read		<=	0;
		Write		<=	0;
		OUT_VALID	<=	0;
		IN_REQ		<=	0;
		mWR_DONE	<=	0;
		mRD_DONE	<=	0;
	end
	else
	begin
		Pre_RD	<=	mRD;
		Pre_WR	<=	mWR;
		case(ST)
		0:	begin
				if({Pre_RD,mRD}==2'b01)     //读
				begin
					Read	<=	1;
					Write	<=	0;
					CMD	<=	2'b01;
					ST		<=	1;
				end
				else if({Pre_WR,mWR}==2'b01)//写
				begin
					Read	<=	0;
					Write	<=	1;
					CMD		<=	2'b10;
					ST		<=	1;
				end
			end
		1:	begin
				if(CMDACK==1)
				begin
					CMD<=2'b00;
					ST<=2;
				end
			end
		default:	
			begin	
				if(ST!=SC_CL+SC_RCD+mLENGTH+1)
				ST<=ST+1;
				else
				ST<=0;
			end
		endcase
	
		if(Read)
		begin
			if(ST==SC_CL+SC_RCD+1)
			OUT_VALID	<=	1;
			else if(ST==SC_CL+SC_RCD+mLENGTH+1)
			begin
				OUT_VALID	<=	0;
				Read		<=	0;
				mRD_DONE	<=	1;
			end
		end
		else
		mRD_DONE	<=	0;
		
		if(Write)
		begin
			if(ST==SC_CL-1)
			IN_REQ	<=	1;
			else if(ST==SC_CL+mLENGTH-1)
			IN_REQ	<=	0;
			else if(ST==SC_CL+mLENGTH)
			begin
				Write	<=	0;
				mWR_DONE<=	1;
			end
		end
		else
		mWR_DONE<=	0;

	end
end
//	Internal Address & Length Control
always@(posedge CLK or negedge RESET_N)
begin
	if(!RESET_N)
	begin
		rWR1_ADDR		<=	WR1_ADDR;
		rRD1_ADDR		<=	RD1_ADDR;
	end
	else
	begin
		//	Write Side 1
		if(WR1_LOAD)
			rWR1_ADDR	<=	WR1_ADDR;    //WR1_LOAD为1时，地址复位
		else if(mWR_DONE&WR_MASK)      //写入完成&WR_MASK
		begin
			if(rWR1_ADDR<WR1_MAX_ADDR-WR1_LENGTH)  //没写到最大地址，每次加写入笔数
			rWR1_ADDR	<=	rWR1_ADDR+WR1_LENGTH;
			else
			rWR1_ADDR	<=	WR1_ADDR;
		end
		//	Read Side 1
		if(RD1_LOAD)
			rRD1_ADDR	<=	RD1_ADDR;
		else if(mRD_DONE&RD_MASK)
		begin
			if(rRD1_ADDR<RD1_MAX_ADDR-RD1_LENGTH)
			rRD1_ADDR	<=	rRD1_ADDR+RD1_LENGTH;
			else
			rRD1_ADDR	<=	RD1_ADDR;
		end
	end
end
//	Auto Read/Write Control
always@(posedge CLK or negedge RESET_N)
begin
	if(!RESET_N)
	begin
		WR_MASK	<=	1'b0;
		RD_MASK	<=	1'b0;
		mWR		<=	0;
		mRD		<=	0;
	end
	else
	begin
		if( (mWR==0) && (mRD==0) && (ST==0) &&
			(WR_MASK==0)	&&	(RD_MASK==0) )
		begin
			//	Read Side 1
			if( (read_side_fifo_wusedw1 < RD1_LENGTH) && (RD1_LOAD==0))
			begin
				mADDR	<=	rRD1_ADDR;
				mLENGTH	<=	RD1_LENGTH;
				WR_MASK	<=	1'b0;
				RD_MASK	<=	1'b1;
				mWR		<=	0;
				mRD		<=	1;				
			end
			//	Write Side 1
			else if( (write_side_fifo_rusedw1 >= WR1_LENGTH) && (WR1_LENGTH!=0) && (WR1_LOAD==0))
			begin
				mADDR	<=	rWR1_ADDR;
				mLENGTH	<=	WR1_LENGTH;
				WR_MASK	<=	1'b1;
				RD_MASK	<=	1'b0;
				mWR		<=	1;
				mRD		<=	0;
			end
		end
		if(mWR_DONE)
		begin
			WR_MASK	<=	0;
			mWR		<=	0;
		end
		if(mRD_DONE)
		begin
			RD_MASK	<=	0;
			mRD		<=	0;
		end
	end
end

endmodule