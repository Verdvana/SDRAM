module control_interface(
		CLK,
		RESET_N,
		CMD,
		ADDR,
		REF_ACK,
		INIT_ACK,
		CM_ACK,
		NOP,
		READA,
		WRITEA,
		REFRESH,
		PRECHARGE,
		LOAD_MODE,
		SADDR,
		REF_REQ,
		INIT_REQ,
		CMD_ACK
        );

`include        "Sdram_Params.h"

input                     	CLK;                    // 
input                     	RESET_N;                // 
input   [2:0]             	CMD;                    // 命令输入
input   [`ASIZE-1:0]     	ADDR;                   // 地址输入
input                    	REF_ACK;                // 执行更新指令
input								INIT_ACK;					// 执行初始化指令
input                     	CM_ACK;                 // 执行指令

output reg                	NOP;                    // 译码出“空”指令
output reg                	READA;                  // 译码出“读”指令
output reg                	WRITEA;                 // 译码出“写”指令
output reg                	REFRESH;                // 译码出“更新”指令
output reg                	PRECHARGE;              // 译码出“预充电”指令
output reg                	LOAD_MODE;              // 译码出“模式设定”指令
output reg [`ASIZE-1:0]   	SADDR;                  // 地址输出
output reg                	REF_REQ;                // 正常读写时“更新”指令
output reg                	INIT_REQ;               // 初始化动作
output reg                	CMD_ACK;                // 开始执行指令


            

// Internal signals
reg     [15:0]          	timer;						// 正常读写时的更新计时器
reg	  [15:0]					init_timer;					// 初始化时的计时器



// Command decode and ADDR register
always @(posedge CLK or negedge RESET_N)
begin
        if (RESET_N == 0) 
        begin
                NOP             <= 0;
                READA           <= 0;
                WRITEA          <= 0;
                SADDR           <= 0;
        end
        
        else
        begin
        
                SADDR <= ADDR;                                  // 对齐地址信号与指令信号
                                                             
                if (CMD == 3'b000)                              // 译码出“空”指令
                        NOP <= 1;
                else
                        NOP <= 0;
                        
                if (CMD == 3'b001)                              // 译码出“读”指令
                        READA <= 1;
                else
                        READA <= 0;
                 
                if (CMD == 3'b010)                              // 译码出“写”指令
                        WRITEA <= 1;
                else
                        WRITEA <= 0;
                        
        end
end


//  生成 CMD_ACK
always @(posedge CLK or negedge RESET_N)
begin
        if (RESET_N == 0)
                CMD_ACK <= 0;
        else
                if ((CM_ACK == 1) & (CMD_ACK == 0))
                        CMD_ACK <= 1;
                else
                        CMD_ACK <= 0;
end


// refresh 计时器
always @(posedge CLK or negedge RESET_N) begin
        if (RESET_N == 0) 
        begin
                timer           <= 0;
                REF_REQ         <= 0;
        end        
        else 
        begin
                if (REF_ACK == 1)
				begin
                	timer <= REF_PER;
					REF_REQ	<=0;
				end
				else if (INIT_REQ == 1)
				begin
                	timer <= REF_PER+200;
					REF_REQ	<=0;					
				end
                else
                	timer <= timer - 1'b1;

                if (timer==0)
                    REF_REQ    <= 1;

        end
end

// initial 计时器
always @(posedge CLK or negedge RESET_N) begin
        if (RESET_N == 0) 
        begin
                init_timer      <= 0;
				REFRESH         <= 0;
                PRECHARGE      	<= 0; 
				LOAD_MODE		<= 0;
				INIT_REQ		<= 0;
        end        
        else 
        begin
                if (init_timer < (INIT_PER+201))
					init_timer 	<= init_timer+1;
					
				if (init_timer < INIT_PER)
				begin
					REFRESH		<=0;
					PRECHARGE	<=0;
					LOAD_MODE	<=0;
					INIT_REQ	<=1;
				end
				else if(init_timer == (INIT_PER+20))
				begin
					REFRESH		<=0;
					PRECHARGE	<=1;
					LOAD_MODE	<=0;
					INIT_REQ	<=0;
				end
				else if( 	(init_timer == (INIT_PER+40))	||
							(init_timer == (INIT_PER+60))	||
							(init_timer == (INIT_PER+80))	||
							(init_timer == (INIT_PER+100))	||
							(init_timer == (INIT_PER+120))	||
							(init_timer == (INIT_PER+140))	||
							(init_timer == (INIT_PER+160))	||
							(init_timer == (INIT_PER+180))	)
				begin
					REFRESH		<=1;
					PRECHARGE	<=0;
					LOAD_MODE	<=0;
					INIT_REQ	<=0;
				end
				else if(init_timer == (INIT_PER+200))
				begin
					REFRESH		<=0;
					PRECHARGE	<=0;
					LOAD_MODE	<=1;
					INIT_REQ	<=0;				
				end
				else
				begin
					REFRESH		<=0;
					PRECHARGE	<=0;
					LOAD_MODE	<=0;
					INIT_REQ	<=0;									
				end
        end
end

endmodule

