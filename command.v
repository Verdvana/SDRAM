module command( 
			CLK,
			RESET_N,
			SADDR,
			NOP,
			READA,
			WRITEA,
			REFRESH,
			PRECHARGE,
			LOAD_MODE,
			REF_REQ,
			INIT_REQ,
			PM_STOP,
			REF_ACK,
			CM_ACK,
			OE,
			SA,
			BA,
			CS_N,
			CKE,
			RAS_N,
			CAS_N,
			WE_N
        );

`include        "Sdram_Params.h"

input                 	CLK;                    // 
input                	RESET_N;                // 
input   [`ASIZE-1:0]   	SADDR;                  //地址
input                  	NOP;                    //空命令
input                	READA;                  //解码出读命令
input                  	WRITEA;                 //解码出写命令
input                	REFRESH;                //解码出刷新命令
input                 	PRECHARGE;              //解码出预充电命令
input                 	LOAD_MODE;              //解码出LOAD_MODE命令
input                  	REF_REQ;                //隐藏的刷新请求
input							INIT_REQ;					//隐藏的初始请求
input							PM_STOP;					  	//页面模式停止

output reg             	REF_ACK;                //刷新请求确认
output reg            	CM_ACK;                 //命令确认
output reg             	OE;                     //数据路径模块的OE信号

output reg	[11:0]     	SA;                     //SDRAM 地址
output reg	[1:0]     	BA;                     //SDRAM 块地址
output reg	[1:0]      	CS_N;                   //SDRAM 片选
output reg             	CKE;                    //SDRAM 时钟使能
output reg            	RAS_N;                  //SDRAM RAS
output reg            	CAS_N;                  //SDRAM CAS
output reg            	WE_N;                   //SDRAM WE_N




// Internal signals
reg                    	do_reada;
reg                    	do_writea;
reg                 		do_refresh;
reg                    	do_precharge;
reg                   	do_load_mode;
reg							do_initial;
reg                    	command_done;
reg     [7:0]         	command_delay;
reg     [1:0]          	rw_shift;
reg                    	do_act;
reg                   	rw_flag;
reg                    	do_rw;
reg     [6:0]          	oe_shift;
reg                    	oe1;
reg                    	oe2;
reg                    	oe3;
reg                    	oe4;
reg     [3:0]         	rp_shift;
reg                    	rp_done;
reg							ex_read;
reg							ex_write;

wire    [`ROWSIZE - 1:0]        rowaddr;        //宽度：13
wire    [`COLSIZE - 1:0]        coladdr;        //宽度：9
wire    [`BANKSIZE - 1:0]       bankaddr;       //宽度：2

assign   rowaddr   = SADDR[`ROWSTART + `ROWSIZE - 1: `ROWSTART];          // 行地址 （A0-A12）  SADDR[20:9]
assign   coladdr   = SADDR[`COLSTART + `COLSIZE - 1:`COLSTART];           // 列地址 （A0-A9）   SADDR[8:0]
assign   bankaddr  = SADDR[`BANKSTART + `BANKSIZE - 1:`BANKSTART];        // 块地址 （BA0,BA1） SADDR[22:21]



// 如果当前有另一个命令已经运行，则此始终阻止监视各个命令行并向下一个阶段发出命令。
//
always @(posedge CLK or negedge RESET_N)
begin
        if (RESET_N == 0) 
        begin
                do_reada        <= 0;
                do_writea       <= 0;
                do_refresh      <= 0;
                do_precharge    <= 0;
                do_load_mode    <= 0;
				do_initial		<= 0;
                command_done    <= 0;
                command_delay   <= 0;
                rw_flag         <= 0;
                rp_shift        <= 0;
                rp_done         <= 0;
				ex_read			<= 0;
				ex_write		<= 0;
        end
        
        else
        begin

//  如果sdram当前不忙，则发出适当的命令
			if( INIT_REQ == 1 )
			begin
                do_reada        <= 0;
                do_writea       <= 0;
                do_refresh      <= 0;
                do_precharge    <= 0;
                do_load_mode    <= 0;
				do_initial		<= 1;
                command_done    <= 0;
                command_delay   <= 0;
                rw_flag         <= 0;
                rp_shift        <= 0;
                rp_done         <= 0;
				ex_read			<= 0;
				ex_write		<= 0;
			end
			else
			begin
				do_initial		<= 0;
				
                if ((REF_REQ == 1 | REFRESH == 1) & command_done == 0 & do_refresh == 0 & rp_done == 0         // Refresh
                        & do_reada == 0 & do_writea == 0)
                        do_refresh <= 1;         
                else
                        do_refresh <= 0;

                if ((READA == 1) & (command_done == 0) & (do_reada == 0) & (rp_done == 0) & (REF_REQ == 0))    // READA
                begin
				        do_reada <= 1;
						ex_read <= 1;
				end
                else
                        do_reada <= 0;
                    
                if ((WRITEA == 1) & (command_done == 0) & (do_writea == 0) & (rp_done == 0) & (REF_REQ == 0))  // WRITEA
                begin
				        do_writea <= 1;
						ex_write <= 1;
				end
                else
                        do_writea <= 0;

                if ((PRECHARGE == 1) & (command_done == 0) & (do_precharge == 0))                              // PRECHARGE
                        do_precharge <= 1;
                else
                        do_precharge <= 0;
 
                if ((LOAD_MODE == 1) & (command_done == 0) & (do_load_mode == 0))                              // LOADMODE
                        do_load_mode <= 1;
                else
                        do_load_mode <= 0;
                                               
// 设置 command_delay shift寄存器和command_done标志命令延迟移位寄存器是一个定时器，用于确保SDRAM器件有足够的时间完成最后一个命令。

                if ((do_refresh == 1) | (do_reada == 1) | (do_writea == 1) | (do_precharge == 1)
                     | (do_load_mode == 1))
                begin
                        command_delay <= 8'b11111111;
                        command_done  <= 1;
                        rw_flag <= do_reada;                                                  
                end
                
                else
                begin
                        command_done        <= command_delay[0];                // the command_delay shift operation
                        command_delay		<= (command_delay>>1);
                end 
                
 
 // 启动用于refresh，writea和reada命令的附加计时器              
                if (command_delay[0] == 0 & command_done == 1)
                begin
                	rp_shift <= 4'b1111;
                	rp_done <= 1;
                end
                else
                begin						
					if(SC_PM == 0)
					begin
						rp_shift	<= (rp_shift>>1);
                    	rp_done		<= rp_shift[0];
					end
					else
					begin
						if( (ex_read == 0) && (ex_write == 0) )
						begin
							rp_shift	<= (rp_shift>>1);
        	            	rp_done		<= rp_shift[0];
						end
						else
						begin
							if( PM_STOP==1 )
							begin
								rp_shift	<= (rp_shift>>1);
        	      		      	rp_done     <= rp_shift[0];
								ex_read		<= 1'b0;
								ex_write	<= 1'b0;
							end					
						end
					end
                end
			end
        end
end


// 为数据路径模块生成OE信号的逻辑对于正常脉冲串写入，OE的持续时间取决于配置的脉冲串长度。
// 对于页面模式访问（SC_PM = 1），OE信号在写入命令开始时打开， 保持打开直到检测到PRECHARGE（页面突发终止）。
//
always @(posedge CLK or negedge RESET_N)
begin
        if (RESET_N == 0)
        begin
                oe_shift <= 0;
                oe1      <= 0;
                oe2      <= 0;
                OE       <= 0;
        end
        else
        begin
                if (SC_PM == 0)
                begin
                        if (do_writea == 1)
                        begin
                                if (SC_BL == 1)                       // 根据突发长度将移位寄存器设置为适当的值。
                                        oe_shift <= 0;
                                else if (SC_BL == 2)
                                        oe_shift <= 1;
                                else if (SC_BL == 4)
                                        oe_shift <= 7;
                                else if (SC_BL == 8)
                                        oe_shift <= 127;
                                oe1 <= 1;
                        end
                        else 
                        begin
                                oe_shift <= (oe_shift>>1);
                                oe1  <= oe_shift[0];
                                oe2  <= oe1;
                                oe3  <= oe2;
                                oe4  <= oe3;
                                if (SC_RCD == 2)
                                        OE <= oe3;
                                else
                                        OE <= oe4;
                        end
                end
                else
                begin
                        if (do_writea == 1)                                    // 用于页面模式访问的OE生成
                                oe4   <= 1;
                        else if (do_precharge == 1 | do_reada == 1 | do_refresh==1 | do_initial == 1 | PM_STOP==1 )
                                oe4   <= 0;
                        OE <= oe4;
                end
                               
        end
end




// 此始终块会跟踪激活命令与后续WRITEA或READA命令RC之间的时间。
// 使用配置寄存器设置SC_RCD设置移位寄存器。
// 移位寄存器加载单个“1”，寄存器内的位置取决于SC_RCD。
// 当'1'移出寄存器时，它设置so_rw，触发writea或reada命令。
//
always @(posedge CLK or negedge RESET_N)
begin
        if (RESET_N == 0)
        begin
                rw_shift <= 0;
                do_rw    <= 0;
        end
        
        else
        begin
                
                if ((do_reada == 1) | (do_writea == 1))
                begin
                        if (SC_RCD == 1)                          // 设置移位寄存器
                                do_rw <= 1;
                        else if (SC_RCD == 2)
                                rw_shift <= 1;
                        else if (SC_RCD == 3)
                                rw_shift <= 2;
                end
                else
                begin
                        rw_shift <= (rw_shift>>1);
                        do_rw    <= rw_shift[0];
                end 
        end
end              

// 该始终块生成命令确认，CM_ACK，信号。
// 它还生成确认信号REF_ACK，该信号确认由内部刷新定时器电路产生的刷新请求。
always @(posedge CLK or negedge RESET_N) 
begin

        if (RESET_N == 0) 
        begin
                CM_ACK   <= 0;
                REF_ACK  <= 0;
        end
        
        else
        begin
                if (do_refresh == 1 & REF_REQ == 1)                   // 内部刷新定时器刷新请求
                        REF_ACK <= 1;
                else if ((do_refresh == 1) | (do_reada == 1) | (do_writea == 1) | (do_precharge == 1)   // 外部命令
                         | (do_load_mode))
                        CM_ACK <= 1;
                else
                begin
                        REF_ACK <= 0;
                        CM_ACK  <= 0;
                end
        end
end 
                    






// 这个始终块生成地址，cs，cke和命令信号（ras，cas，wen）
// 
always @(posedge CLK ) begin
        if (RESET_N==0) begin
                SA    <= 0;
                BA    <= 0;
                CS_N  <= 1;
                RAS_N <= 1;
                CAS_N <= 1;
                WE_N  <= 1;
                CKE   <= 0;
        end
        else begin
                CKE <= 1;

// 生成 SA 	
                if (do_writea == 1 | do_reada == 1)    // 正在发出ACTIVATE命令，因此显示行地址
                        SA <= rowaddr;
                else
                        SA <= coladdr;                 // 否则总是出现列地址
                if ((do_rw==1) | (do_precharge))
                        SA[10] <= !SC_PM;              // 设置SA [10]进行自动预充电读/写或预充电全部命令
                                                       // 如果控制器处于页面模式，请不要设置它。       
                if (do_precharge==1 | do_load_mode==1)
                        BA <= 0;                       // 如果执行precharge或load_mode命令，则设置BA = 0
                else
                        BA <= bankaddr[1:0];           // 否则用适当的地址位设置它
		
                if (do_refresh==1 | do_precharge==1 | do_load_mode==1 | do_initial==1)
                        CS_N <= 0;                                    // 如果执行刷新，预充电（全部）或load_mode，则选择两个芯片选择
                else
                begin
                        CS_N[0] <= SADDR[`ASIZE-1];                   // 否则根据msb地址位设置芯片选择
                        CS_N[1] <= ~SADDR[`ASIZE-1];
                end
				
				if(do_load_mode==1)
				SA	  <= {2'b00,SDR_CL,SDR_BT,SDR_BL};


//根据发出的命令，在RAS_N，CAS_N和WE_N上生成适当的逻辑电平。
//		
                if ( do_refresh==1 ) begin                        // Refresh: S=00, RAS=0, CAS=0, WE=1
                        RAS_N <= 0;
                        CAS_N <= 0;
                        WE_N  <= 1;
                end
                else if (do_precharge==1) begin                 // Precharge All: S=00, RAS=0, CAS=1, WE=0
                        RAS_N <= 0;
                        CAS_N <= 1;
                        WE_N  <= 0;
                end
                else if (do_load_mode==1) begin                 // Mode Write: S=00, RAS=0, CAS=0, WE=0
                        RAS_N <= 0;
                        CAS_N <= 0;
                        WE_N  <= 0;
                end
                else if (do_reada == 1 | do_writea == 1) begin  // Activate: S=01 or 10, RAS=0, CAS=1, WE=1
                        RAS_N <= 0;
                        CAS_N <= 1;
                        WE_N  <= 1;
                end
                else if (do_rw == 1) begin                      // Read/Write: S=01 or 10, RAS=1, CAS=0, WE=0 or 1
                        RAS_N <= 1;
                        CAS_N <= 0;
                        WE_N  <= rw_flag;
                end
				else if (do_initial ==1) begin
                        RAS_N <= 1;
                        CAS_N <= 1;
                        WE_N  <= 1;				
				end
                else begin                                      // No Operation: RAS=1, CAS=1, WE=1
                        RAS_N <= 1;
                        CAS_N <= 1;
                        WE_N  <= 1;
                end
        end 
end

endmodule
