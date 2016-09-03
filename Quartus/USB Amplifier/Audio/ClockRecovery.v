//==============================================================================
// Copyright (C) John-Philip Taylor
// jpt13653903@gmail.com
//
// This file is part of USB Amplifier
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

// All clocks are optimised for long-term stability of the rising-edge
//------------------------------------------------------------------------------

module ClockRecovery(
 input Clk, // 50 MHz
 input Reset,

 input      Reference, // 500 Hz
 output reg Clk_384k,
 output reg Clk_48k,
 output reg Clk_500
);
//------------------------------------------------------------------------------

// Localise the reset
reg tReset;
always @(posedge Clk) tReset <= Reset;
//------------------------------------------------------------------------------

reg [7:0]Count_384k; // Also used for 384 kHz
reg [2:0]Count_48k;
reg [6:0]Count_500;

reg [23:0]Period; // This is the control variable to set the frequency
reg [ 7:0]Period_NS; // Noise-shaped version of the period.
//------------------------------------------------------------------------------

NoiseShaper #(
 .InputN (24),
 .OutputN( 8),
 .N      ( 4)

)NoiseShaper_inst(
 .Clk    (Clk),
 .Reset  (Reset),
 .Clk_Ena(~|Count_384k),

 .Input (Period),
 .Output(Period_NS)
);
//------------------------------------------------------------------------------

// Frequency Synthesiser
always @(posedge Clk) begin
 if(tReset) begin
  Count_384k <= 0;
  Count_48k  <= 0;
  Count_500  <= 0;

 end else begin
  if(Count_384k == Period_NS) begin
   Clk_384k   <= 1'b1;
   Count_384k <= 0;
 
   if(Count_48k == 3'd7) begin
    Clk_48k   <= 1'b1;
    Count_48k <= 0;

    if(Count_500 == 7'd95) begin
     Clk_500   <= 1'b1;
     Count_500 <= 0;

    end else begin
     if(Count_500 == 7'd48) Clk_500 <= 1'b0;
     Count_500 <= Count_500 + 1'b1;
    end

   end else begin
    if(Count_48k == 2'd3) Clk_48k <= 1'b0;
    Count_48k <= Count_48k + 1'b1;
   end

  end else begin
   if(Count_384k == 8'd64) Clk_384k <= 1'b0;
   Count_384k <= Count_384k + 1'b1;
  end
 end
end

reg [ 1:0]Ref;
reg [16:0]PhaseCount;
reg [16:0]Phase_Abs;
reg [24:0]Phase_Scaled_Abs;
reg [24:0]Phase_Scaled;
reg [24:0]Phase_Filtered_Large;
reg [16:0]Phase_Filtered;

always @(posedge Clk) begin
 Ref <= {Ref[0], Reference};

 if(tReset) begin
  Period         <= 24'h_81_00_00;
  Phase_Filtered <= 0;

 end else begin
  Phase_Filtered   <= Phase_Filtered_Large[24:8];
  Phase_Abs        <= Phase_Filtered[16] ? -Phase_Filtered : Phase_Filtered;
  Phase_Scaled_Abs <= Phase_Abs * 8'hFF;
  Phase_Scaled     <= Phase_Filtered[16] ? -Phase_Scaled_Abs : Phase_Scaled_Abs;

  if(^Ref) begin // 1 ms interval
   Phase_Filtered_Large <= Phase_Scaled + {{8{PhaseCount[16]}}, PhaseCount};

   Period     <= 24'h_81_00_00 + {{6{Phase_Filtered[16]}}, Phase_Filtered, 1'd0};
   PhaseCount <= 0;

  end else begin
   if(Clk_500 ^ Ref[0]) PhaseCount <= PhaseCount + 1'b1;
   else                 PhaseCount <= PhaseCount - 1'b1;

        if(Period < 24'h_80_00_00) Period = 24'h_80_00_00;
   else if(Period > 24'h_82_00_00) Period = 24'h_82_00_00;
  end
 end
end
//------------------------------------------------------------------------------

endmodule
//------------------------------------------------------------------------------

