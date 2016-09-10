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

// For all arrays, 0 => Left, 1 => Right
//------------------------------------------------------------------------------

module USB_Stream(
 input  Clk,
 input  Reset,

 output Stall,

 input            OUT_EoP,
 output           OUT_WaitRequest,
 input      [ 7:0]OUT_Data,
 input            OUT_Valid,
 output           OUT_Isochronous,

 input            Audio_Clk, // 48 kHz
 output reg [15:0]Audio[1:0] // Registered just after falling edge of Audio_Clk
);
//------------------------------------------------------------------------------

assign OUT_WaitRequest = 1'b0;
assign OUT_Isochronous = 1'b1;
assign OUT_Stall       = 1'b0;
//------------------------------------------------------------------------------
            
reg [9:0]FIFO_WriteAddress;
wire     FIFO_Write = OUT_Valid & ~OUT_EoP;

reg  [ 7:0]FIFO_ReadAddress;
wire [31:0]FIFO_Out;

USB_FIFO FIFO(
 .clock    (Clk),

 .wraddress(FIFO_WriteAddress),
 .wren     (FIFO_Write),
 .data     (OUT_Data),

 .rdaddress(FIFO_ReadAddress),
 .q        (FIFO_Out)
);

always @(posedge Clk) begin
      if(tReset    ) FIFO_WriteAddress <= 0;
 else if(FIFO_Write) FIFO_WriteAddress <= FIFO_WriteAddress + 1'b1;

 // Resynchronise in the very rare case where a byte is lost and resynchronise:
 else if(OUT_Valid & OUT_EoP) FIFO_WriteAddress[1:0] <= 0;
end
//------------------------------------------------------------------------------

reg [1:0]Clk_48k;
reg      FIFO_Ready;
reg [7:0]FIFO_Length;
//------------------------------------------------------------------------------

reg tReset;
always @(posedge Clk) begin 
 tReset  <= Reset;
 Clk_48k <= {Clk_48k[0], Audio_Clk};
//------------------------------------------------------------------------------

 FIFO_Length <= FIFO_WriteAddress[9:2] - FIFO_ReadAddress;
//------------------------------------------------------------------------------

 if(tReset) begin
  FIFO_Ready       <= 0;
  FIFO_ReadAddress <= 0;

  {Audio[1], Audio[0]} <= 0;
//------------------------------------------------------------------------------
   
 end else begin
  if(FIFO_Ready) begin
   if(FIFO_Length == 8'h20) FIFO_Ready <= 1'b0;
  end else begin
   if(FIFO_Length == 8'h80) FIFO_Ready <= 1'b1;
  end
//------------------------------------------------------------------------------

  if(FIFO_Ready) begin
   if(Clk_48k == 2'b10) begin
    {Audio[1], Audio[0]} <= FIFO_Out;
    FIFO_ReadAddress     <= FIFO_ReadAddress + 1'b1;
   end
  end else begin
   {Audio[1], Audio[0]} <= 0;
  end
 end
end
//------------------------------------------------------------------------------

endmodule
//------------------------------------------------------------------------------

