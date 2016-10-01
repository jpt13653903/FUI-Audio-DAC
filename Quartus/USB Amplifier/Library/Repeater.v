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

module Repeater(
 input  Clk, // 50 MHz
 input  Input,
 output Output
);
//------------------------------------------------------------------------------

reg [25:0]Count;
reg       Gate;
//------------------------------------------------------------------------------

always @(posedge Clk) begin
 Output <= Input & Gate;
    
 if(~Input) begin
  Gate  <= 1'b1;
  Count <= 26'd_49_999_999;

 end else if(|Count) begin
  Count <= Count - 1'b1;

 end else begin
  Gate  <= ~Gate;
  Count <= 26'd_499_999; // Once key-press every 20 ms
 end
end
//------------------------------------------------------------------------------

endmodule
//------------------------------------------------------------------------------

