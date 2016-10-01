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

module RemoteCleaner(
 input Clk,
 input Reset,

 input      Input,
 output reg Output
);
//------------------------------------------------------------------------------

reg [13:0]Count;
reg [ 1:0]tInput;

reg tReset;

always @(posedge Clk) begin
 tReset <= Reset;
 tInput <= {tInput[0], Input};

 if(tReset) begin
  Count  <= 0;
  Output <= 0;

 end else if(^tInput) begin
  Count <= 0;

 end else begin
  if(&Count) Output <= tInput[0];
  else       Count  <= Count + 1'b1;
 end
end
//------------------------------------------------------------------------------

endmodule
//------------------------------------------------------------------------------

