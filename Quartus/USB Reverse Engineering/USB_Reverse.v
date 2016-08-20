module USB_Reverse(
 input Clk,               // N14 (50 MHz)

 // On-board the BeMicro
 input  [4:1]SW,          // AB5,  V5, R1, M1
 output [8:1]LED,         // AA5, AB4, T6, V4, T1, R2, N1, M2

 // Daughter-board
 output USB_D_P_Pull,     // K14
 output USB_D_N_Pull,     // E16
 inout  USB_D_P,          // K15
 inout  USB_D_N,          // E15

 output [6:1]TP,          // C13, C14, J13, H14, C17, D17

 input       S_PDIF_In,   // B14
 output reg nS_PDIF,      // A14
 output reg  S_PDIF_Out,  // A9

 output [2:1]Audio,       // B8, B10

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

reg [26:0]Count;
always @(posedge USB_Clk) Count <= Count + 1'b1;

assign LED[8:2] = {~Count[26:24], SW};
//------------------------------------------------------------------------------

assign USB_D_P_Pull = 1'b1;
assign USB_D_N_Pull = 1'bZ;

USB_Tranceiver USB_Tranceiver_Inst(
 USB_Clk, 
 Reset,
 
 USB_D_P,
 USB_D_N,

 LED[1]
);
//------------------------------------------------------------------------------

assign TP = 0;
//------------------------------------------------------------------------------

always @(posedge USB_Clk) begin
 if(&Count) begin
  nS_PDIF     <= ~S_PDIF_In;
   S_PDIF_Out <=  S_PDIF_In;
 end
end
//------------------------------------------------------------------------------

assign Audio = 0;
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

