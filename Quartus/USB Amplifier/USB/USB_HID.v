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

module USB_HID(
 input Clk,
 input Reset,
 input Error,

 output reg      IN_Sequence,
 output reg [7:0]IN_Data,
 output reg      IN_Ready,
 output          IN_ZeroLength,
 input           IN_WaitRequest,
 input           IN_Ack,
 output          IN_Isochronous,

 input [5:0]Status // Stop | Prev | Next | Play/Pause | Vol Down | Vol Up
);
//------------------------------------------------------------------------------

assign IN_ZeroLength  = 1'b0;
assign IN_Isochronous = 1'b0;
//------------------------------------------------------------------------------

reg [15:0]Temp;
reg [ 1:0]ByteCount;
//------------------------------------------------------------------------------

reg        State;
localparam Idle        = 1'd0;
localparam SendControl = 1'd1;

reg tReset;
always @(posedge Clk) begin
 tReset <= Reset;
//------------------------------------------------------------------------------

 if(tReset) begin
  IN_Ready    <= 0;
  IN_Sequence <= 0;
  State       <= Idle;
//------------------------------------------------------------------------------

 end else begin
  case(State)
   Idle: begin
    ByteCount <= 0;

    {Temp, IN_Data} <= {10'd0, Status, 8'h01};
    IN_Ready <= 1'b1;
    State    <= SendControl;
   end
//------------------------------------------------------------------------------

   SendControl: begin
    if(IN_Ready) begin
     if(~IN_WaitRequest) begin
      if(ByteCount == 2'd2) IN_Ready <= 1'b0;

      ByteCount       <= ByteCount + 1'b1;
      {Temp, IN_Data} <= {16'd0, Temp};
     end

    end else begin // Waiting for Ack
     if(Error) begin
      State <= Idle;

     end else if(IN_Ack) begin
      IN_Sequence <= ~IN_Sequence;
      State       <= Idle;
     end
    end
   end
//------------------------------------------------------------------------------

   default:;
  endcase
 end
end
//------------------------------------------------------------------------------

endmodule
//------------------------------------------------------------------------------

