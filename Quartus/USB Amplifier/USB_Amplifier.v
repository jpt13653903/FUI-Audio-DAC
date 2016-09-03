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

 output      LV_LCD_RS,   // D14
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
wire [15:0]Volume[1:0];
wire [15:0]Audio [1:0]; // Registered just after falling edge of Audio_Clk

USB_Audio USB_Audio_inst(
 .Clk  (USB_Clk),
 .Reset(Reset),

 .FrameNumber(FrameNumber),

 .Active(Active),
 .Mute  (Mute),
 .Volume(Volume),

 .Audio_Clk(Clk_48k),
 .Audio    (Audio),

 .DP(USB_D_P),
 .DM(USB_D_N)
);
//------------------------------------------------------------------------------

assign LED = Mute ? 8'hFF : ~{
 Volume[0][14], Volume[0][12], Volume[0][10], Volume[0][ 8],
 Volume[0][ 6], Volume[0][ 4], Volume[0][ 2], Volume[0][ 0]
};
//------------------------------------------------------------------------------

wire Clk_384k, Clk_48k, Clk_500;

ClockRecovery ClockRecovery_inst(
 Clk, Reset,
 FrameNumber[0],
 Clk_384k, Clk_48k, Clk_500
);

assign TP = {FrameNumber[0], PWM, Clk_384k, Clk_48k, Clk_500};
//------------------------------------------------------------------------------

reg [ 1:0]pClk_384k;
reg [ 1:0]pClk_48k;

reg [ 1:0]Audio_Sign;
reg [15:0]Audio_Abs       [1:0];
reg [30:0]Audio_Scaled_Abs[1:0];
reg [30:0]Audio_Scaled    [1:0];

always @(posedge Clk) begin
 pClk_384k <= {pClk_384k[0], Clk_384k};

 if(pClk_384k == 2'b10) begin
  pClk_48k <= {pClk_48k[0], Clk_48k};

  if(pClk_48k == 2'b01) begin
   Audio_Sign[0] <= Audio[0][15];
   Audio_Abs [0] <= Audio[0][15] ? -Audio[0] : Audio[0];

   Audio_Sign[1] <= Audio[1][15];
   Audio_Abs [1] <= Audio[1][15] ? -Audio[1] : Audio[1];
  end

  Audio_Scaled[0] <= Audio_Sign[0] ? -Audio_Scaled_Abs[0] : Audio_Scaled_Abs[0];
  Audio_Scaled[1] <= Audio_Sign[1] ? -Audio_Scaled_Abs[1] : Audio_Scaled_Abs[1];
 end

 if(Mute) begin
  Audio_Scaled_Abs[0] <= 0;
  Audio_Scaled_Abs[1] <= 0;
 end else begin
  Audio_Scaled_Abs[0] <= Audio_Abs[0] * Volume[0];
  Audio_Scaled_Abs[1] <= Audio_Abs[1] * Volume[1];
 end
end
//------------------------------------------------------------------------------

wire [6:0]Audio_D[1:0];

NoiseShaper #(
 .InputN (31),
 .OutputN( 7),
 .N      ( 4)

)NoiseShaper_0(
 .Clk    (Clk),
 .Reset  (Reset),
 .Clk_Ena(pClk_384k == 2'b01),

 .Input (Audio_Scaled[0] + 31'h4100_0000),
 .Output(Audio_D     [0])
);

NoiseShaper #(
 .InputN (31),
 .OutputN( 7),
 .N      ( 4)

)NoiseShaper_1(
 .Clk    (Clk),
 .Reset  (Reset),
 .Clk_Ena(pClk_384k == 2'b01),

 .Input (Audio_Scaled[1] + 31'h4100_0000),
 .Output(Audio_D     [1])
);
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

reg tReset;
always @(posedge Clk) begin
 tReset <= Reset;

 if(tReset) begin
  PWM_Count <= 0;

 end else begin
  if(pClk_384k == 2'b01) PWM_Count <= 0; 
  else                   PWM_Count <= PWM_Count + 1'b1;

  PWM[0] <= ({1'b0, Audio_D[0]} > PWM_Count);
  PWM[1] <= ({1'b0, Audio_D[1]} > PWM_Count);
 end
end

assign Audio_Out = Active ? PWM : 2'd0;
//------------------------------------------------------------------------------

assign LV_LCD_RS   = 1'b1;
assign LV_LCD_R_nW = 1'b1;
assign LV_LCD_E    = 1'b1;
assign LV_LCD_D    = 0;
//------------------------------------------------------------------------------

assign Red    = 0;
assign Green  = 0;
assign Blue   = 0;
assign H_Sync = 0;
assign V_Sync = 0;
//------------------------------------------------------------------------------

endmodule
//------------------------------------------------------------------------------

