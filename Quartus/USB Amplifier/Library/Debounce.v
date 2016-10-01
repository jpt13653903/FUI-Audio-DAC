//==============================================================================
// Copyright (C) John-Philip Taylor
// jpt13653903@gmail.com
//
// This file is part of a library
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

module Debounce #(
 parameter N = 20 // Size of the dead-time counter
)(
 input  Clk, // 50 MHz
 input  Input,
 output Output
);
//------------------------------------------------------------------------------

reg [N-1:0]Count; // 21 ms
reg        Input_1;

always @(posedge Clk) begin
 Input_1 <= Input;

 if(|Count) begin
  Count <= Count - 1'b1;

 end else begin
  if(Output ^ Input_1) begin
   Output <= Input_1;
   Count  <= {N{1'b1}};
  end
 end
end
//------------------------------------------------------------------------------

endmodule
//------------------------------------------------------------------------------

