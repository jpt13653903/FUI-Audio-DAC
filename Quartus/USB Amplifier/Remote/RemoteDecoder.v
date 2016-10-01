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

module RemoteDecoder(
 input Clk, // 50 MHz
 input Reset,
 
 input Input,

 output reg [3:0]Buttons,
 output reg [7:0]Knob
);
//------------------------------------------------------------------------------

reg [24:0]Timeout; // About 670 ms on a 50 MHz clock
reg [15:0]Count;
reg      tInput;

reg [35:0]Stream;
reg [15:0]Decoded;
reg [15:0]ValidEdges;
//------------------------------------------------------------------------------

integer j;
always @(*) begin
 for(j = 0; j < 16; j++) begin
  Decoded   [j] = Stream[2*j  ] ^ Stream[2*j+1];
  ValidEdges[j] = Stream[2*j+1] ^ Stream[2*j+2];
 end
end
//------------------------------------------------------------------------------

reg tReset;
always @(posedge Clk) begin
 tReset  <= Reset;
 tInput  <= Input;
//------------------------------------------------------------------------------

 if(tReset) begin
  Timeout <= 0;
  Count   <= 0;
  Stream  <= 0;

  Buttons <= 0;
  Knob    <= 0;
//------------------------------------------------------------------------------

 end else if(tInput ^ Input) begin
  if(Count[15]) begin // > 655.34 μs
   if(&Count[14:0]) begin // > 1.3107 ms
    Stream <= 0;

   end else begin // < 1.3107 ms
    Stream <= {Stream[33:0], tInput, tInput};
   end
  end else begin // < 655.34 μs
    Stream <= {Stream[34:0], tInput};
  end

  Count   <= 0;
  Timeout <= 0;
//------------------------------------------------------------------------------

 end else if(~&Count) begin
  if(
   (~|Count        ) && // Previous clock shifted data
   (~|Stream[35:32]) && // Synchronisation blank
   ( &ValidEdges   ) && // Inter-bit edges
   (~|Decoded[3: 1]) && // Unused bits set to zero (reserved for future use)
   ( ^Decoded      )    // Odd parity
  ) begin
   Buttons <= Decoded[15:12];
   Knob    <= Decoded[11: 4];
  end

  Count   <= Count   + 1'b1;
  Timeout <= Timeout + 1'b1;
//------------------------------------------------------------------------------

 end else begin
  if(&Timeout) Buttons <= 0;
  else         Timeout <= Timeout + 1'b1;
 end
end
//------------------------------------------------------------------------------

endmodule
//------------------------------------------------------------------------------

