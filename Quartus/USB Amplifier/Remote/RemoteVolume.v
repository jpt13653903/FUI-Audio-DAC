//==============================================================================
// Copyright (C) John-Philip Taylor
// jpt13653903@gmail.com
//
// This file is part of a FUI Audio DAC
//
// This file is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>
//============================================================================== 

// This module removes glitches from the received data stream

module RemoteVolume(
 input Clk, // 50 MHz
 input Reset,
 
 input [1:0]Input,

 output reg Up,
 output reg Down
);
//------------------------------------------------------------------------------

reg [18:0]Count; // About 10 ms
reg [ 1:0]tInput;
//------------------------------------------------------------------------------

reg tReset;
always @(posedge Clk) begin
 tReset <= Reset;
 Count  <= Count + 1'b1;
//------------------------------------------------------------------------------

 if(tReset) begin
  Up   <= 0;
  Down <= 0;
//------------------------------------------------------------------------------

 end else if(&Count) begin
  case({tInput, Input})
   4'b00_01, 4'b01_10, 4'b10_11, 4'b11_00: Up   <= 1'b1;
   4'b00_11, 4'b11_10, 4'b10_01, 4'b01_00: Down <= 1'b1;

   default: begin
    Up   <= 0;
    Down <= 0;
   end
  endcase
  tInput <= Input;
 end
end
//------------------------------------------------------------------------------

endmodule
//------------------------------------------------------------------------------

