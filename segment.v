module segment(
input        [3:0] cnt, 
output  reg  [6:0] HEX
);
assign  scan=4'b0001; 
always@(cnt) 
begin   
  case(cnt)
	 4'b0000:HEX= 7'b1000000;  
    4'b0001:HEX= 7'b1111001;	// ---a---- 
	 4'b0010:HEX= 7'b0100100; 	// |	  |
	 4'b0011:HEX= 7'b0110000; 	// f 	  b 
	 4'b0100:HEX= 7'b0011001; 	// |	  |
	 4'b0101:HEX= 7'b0010010; 	// ---g----
	 4'b0110:HEX= 7'b0000010; 	// |	  |
	 4'b0111:HEX= 7'b1111000; 	// e 	  c
	 4'b1000:HEX= 7'b0000000; 	// |	  |
	 4'b1001:HEX= 7'b0011000; 	// ---d----
	 4'b1010:HEX= 7'b0001000;
	 4'b1011:HEX= 7'b0000011;
	 4'b1100:HEX= 7'b0100111;
	 4'b1101:HEX= 7'b0100001;
	 4'b1110:HEX= 7'b0000110;
	 4'b1111:HEX= 7'b0001110;
	 default:HEX= 7'b1000000;  
  endcase 
 end 
endmodule 