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

module USB_Amplifier(
 input Clk,               // N14 (50 MHz)

 // On-board the BeMicro
 input  [4:1]SW,          // AB5,  V5, R1, M1
 output [8:1]LED,         // AA5, AB4, T6, V4, T1, R2, N1, M2

 // Daughter-board
 output USB_D_P_Pull,     // K14
 output USB_D_N_Pull,     // E16
 inout  USB_D_P,          // K15
 inout  USB_D_N,          // E15

 output reg [6:1]TP,      // C13, C14, J13, H14, C17, D17

 input       S_PDIF_In,   // B14
 output reg nS_PDIF,      // A14
 output reg  S_PDIF_Out,  // A9

 output [2:1]Audio_Out,   // B8, B10

 input       LV_LCD_RS,   // D14
 output      LV_LCD_R_nW, // E13
 output      LV_LCD_E,    // E12
 output [7:4]LV_LCD_D,    // C9, J11, H12, D13

 output [3:0]Red,         // B3, A3, C3, A2
 output [3:0]Green,       // B5, A5, B4, A4
 output [3:0]Blue,        // A7, A8, B7, A6
 output      H_Sync,      // B1
 output      V_Sync       // B2
);
//------------------------------------------------------------------------------

assign USB_D_P_Pull = 1'b1;
assign USB_D_N_Pull = 1'bZ;
//------------------------------------------------------------------------------

wire [4:1]SW_Debounced;
//wire [4:1]SW_Repeated;

genvar g;
generate
 for(g = 1; g <= 4; g++) begin: Gen_Buttons
  Debounce Debounce_Inst(Clk, ~SW          [g], SW_Debounced[g]); 
//  Repeater Repeater_Inst(Clk,  SW_Debounced[g], SW_Repeated [g]);
 end
endgenerate
//------------------------------------------------------------------------------

wire USB_Clk;
wire nReset;
wire  Reset;

USB_PLL USB_PLL_Inst(
 .inclk0(Clk),
 .c0    (USB_Clk),
 .locked(nReset)
);
always @(posedge USB_Clk) Reset <= ~nReset;
//------------------------------------------------------------------------------

wire [10:0]FrameNumber;

wire       Active;
wire       Mute;
wire [ 7:0]Volume_USB[1:0];
wire [15:0]Audio     [1:0]; // Registered just after falling edge of Audio_Clk

USB_Audio USB_Audio_inst(
 .Clk  (USB_Clk),
 .Reset(Reset),

 .FrameNumber(FrameNumber),

 .Active(Active),
 .Mute  (Mute),
 .Volume(Volume_USB),

 .Audio_Clk(Clk_48k),
 .Audio    (Audio),

 .HID_Status({
  ( SW_Debounced[1] & SW_Debounced[3]) | RemoteButtons[1], // Stop
  ( SW_Debounced[1] & SW_Debounced[2]) | RemoteButtons[2], // Previous
  (~SW_Debounced[1] & SW_Debounced[2]) | RemoteButtons[0], // Next
  ( SW_Debounced[1] & SW_Debounced[4]) | RemoteButtons[3], // Play / Pause
  (~SW_Debounced[1] & SW_Debounced[3]) | RemoteVolumeDown, // Volume Down
  (~SW_Debounced[1] & SW_Debounced[4]) | RemoteVolumeUp    // Volume Up
 }),

 .DP(USB_D_P),
 .DM(USB_D_N)
);
//------------------------------------------------------------------------------

assign LED = ~(SW_Debounced[1] ? RemoteKnob : {RemoteKnob[5:2], RemoteButtons});
//------------------------------------------------------------------------------

wire Clk_384k, Clk_48k, Clk_500;

ClockRecovery ClockRecovery_inst(
 Clk, Reset,
 FrameNumber[0],
 Clk_384k, Clk_48k, Clk_500
);

assign TP = {nPWM, PWM, Clk_384k, RemoteStream};
//------------------------------------------------------------------------------

reg [15:0]Volume_Log[1:0];

generate
 for(g = 0; g < 2; g++) begin: Gen_Volume
  Volume Volume_Inst(
   .clock  (Clk),
   .address(Volume_USB[g]),
   .q      (Volume_Log[g])
  );
 end
endgenerate
//------------------------------------------------------------------------------

reg [ 1:0]pClk_384k;
reg [ 1:0]pClk_48k;

reg [ 1:0]Audio_Sign;
reg [15:0]Audio_Abs       [1:0];
reg [31:0]Audio_Scaled_Abs[1:0];
reg [31:0]Audio_Scaled    [1:0];

integer j;

always @(posedge Clk) begin
 pClk_384k <= {pClk_384k[0], Clk_384k};

 for(j = 0; j < 2; j++) begin
  if(pClk_384k == 2'b10) begin
   pClk_48k <= {pClk_48k[0], Clk_48k};

   if(pClk_48k == 2'b01) begin
    Audio_Sign[j] <= Audio[j][15];
    Audio_Abs [j] <= Audio[j][15] ? -Audio[j] : Audio[j];
   end

   Audio_Scaled[j] <= Audio_Sign[j] ? -Audio_Scaled_Abs[j] : Audio_Scaled_Abs[j];
  end

  if(Mute) Audio_Scaled_Abs[j] <= 0;
  else     Audio_Scaled_Abs[j] <= Audio_Abs[j] * Volume_Log[j];
 end
end
//------------------------------------------------------------------------------

wire [6:0]Audio_D[1:0];

generate
 for(g = 0; g < 2; g++) begin: Gen_PWM
  NoiseShaper #(
   .InputN (32),
   .OutputN( 7),
   .N      ( 4)

  )NoiseShaper_0(
   .Clk    (Clk),
   .Reset  (Reset),
   .Clk_Ena(pClk_384k == 2'b01),

   .Input ({~Audio_Scaled[g][31], Audio_Scaled[g][30:0]}),
   .Output(  Audio_D     [g])
  );
 end
endgenerate
//------------------------------------------------------------------------------

assign nS_PDIF    = 1'bZ;
assign S_PDIF_Out = 1'b0;

//always @(posedge Clk) begin
// if(&Count) begin
//  nS_PDIF     <= ~S_PDIF_In;
//   S_PDIF_Out <=  S_PDIF_In;
// end
//end
//------------------------------------------------------------------------------

reg [7:0]PWM_Count;
reg [1:0]PWM;

reg  [7:0]nPWM_Count;
wire [6:0]nAudio_D[1:0];
reg  [1:0]nPWM;

// Given the way Clk_384k is generated, the PWM is not guaranteed 50% centred
assign nAudio_D[0] = (|Audio_D[0]) ? (-Audio_D[0]) : 7'h7F;
assign nAudio_D[1] = (|Audio_D[1]) ? (-Audio_D[1]) : 7'h7F;

reg tReset;
always @(posedge Clk) begin
 tReset <= Reset;

 if(tReset) begin
   PWM_Count <= 0;
  nPWM_Count <= 0;

 end else begin
  if(pClk_384k == 2'b01) PWM_Count <= 0; 
  else                   PWM_Count <= PWM_Count + 1'b1;

   PWM[0] <= ({1'b0,  Audio_D[0]} > PWM_Count);
   PWM[1] <= ({1'b0,  Audio_D[1]} > PWM_Count);

  if(pClk_384k == 2'b10) nPWM_Count <= 0; 
  else                   nPWM_Count <= nPWM_Count + 1'b1;

  nPWM[0] <= ({1'b0, nAudio_D[0]} > nPWM_Count);
  nPWM[1] <= ({1'b0, nAudio_D[1]} > nPWM_Count);
 end
end

assign Audio_Out = Active ? PWM : 2'd0;
assign LV_LCD_D  = Active ? {1'b0, PWM[0], 1'b0, nPWM[0]} : 4'd0;
//------------------------------------------------------------------------------

wire      RemoteStream;
wire [3:0]RemoteButtons;
wire [7:0]RemoteKnob;
wire      RemoteVolumeUp;
wire      RemoteVolumeDown;

RemoteCleaner RemoteCleaner_inst(Clk, Reset, LV_LCD_RS, RemoteStream);

RemoteDecoder RemoteDecoder_inst(
 Clk, Reset,

 RemoteStream,

 RemoteButtons,
 RemoteKnob
);

RemoteVolume RemoteVolume_inst(
 Clk, Reset,

 RemoteKnob[3:2],

 RemoteVolumeUp,
 RemoteVolumeDown
);
//------------------------------------------------------------------------------

//assign LV_LCD_RS   = 1'b1;
assign LV_LCD_R_nW = 1'b1;
assign LV_LCD_E    = 1'b1;
//assign LV_LCD_D    = 0;
//------------------------------------------------------------------------------

assign Red    = 0;
assign Green  = 0;
assign Blue   = 0;
assign H_Sync = 0;
assign V_Sync = 0;
//------------------------------------------------------------------------------

endmodule
//------------------------------------------------------------------------------

