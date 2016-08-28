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

reg [26:0]Count;
always @(posedge USB_Clk) Count <= Count + 1'b1;

assign LED = ~{Count[26:24], ~SW, Keeper};
//------------------------------------------------------------------------------

wire       ResetRequest;
reg  [ 6:0]Address;
wire [ 3:0]Endpoint;
wire [10:0]FrameNumber;
reg        Stall;
wire       Error;

wire      OUT_Setup;
wire      OUT_SoP;
wire      OUT_EoP;
reg       OUT_WaitRequest;
wire [7:0]OUT_Data;
wire      OUT_Valid;
reg       OUT_Isochronous;
 
reg       IN_Sequence;
reg  [7:0]IN_Data;
reg       IN_Ready;
reg       IN_ZeroLength;
wire      IN_WaitRequest;
wire      IN_Ack;
reg       IN_Isochronous;

wire Keeper =
 |  ResetRequest
 | &Endpoint
 | &FrameNumber
 |  Error
 |  OUT_Setup
 |  OUT_SoP
 |  OUT_EoP
 | &OUT_Data
 |  OUT_Sequence
 |  OUT_Valid
 |  IN_WaitRequest
 |  IN_Ack
;

USB_Transceiver USB_Transceiver_Inst(
 .Clk  (USB_Clk),
 .Reset(Reset),

 .ResetRequest(ResetRequest),
 .Address     (Address),
 .Endpoint    (Endpoint),
 .FrameNumber (FrameNumber),
 .Error       (Error),

 .OUT_Setup      (OUT_Setup),
 .OUT_SoP        (OUT_SoP),
 .OUT_EoP        (OUT_EoP),
 .OUT_WaitRequest(OUT_WaitRequest),
 .OUT_Data       (OUT_Data),
 .OUT_Sequence   (OUT_Sequence),
 .OUT_Valid      (OUT_Valid),
 .OUT_Isochronous(OUT_Isochronous),
 .OUT_Stall      (Stall),
 
 .IN_Sequence   (IN_Sequence),
 .IN_Data       (IN_Data),
 .IN_Ready      (IN_Ready),
 .IN_ZeroLength (IN_ZeroLength),
 .IN_WaitRequest(IN_WaitRequest),
 .IN_Ack        (IN_Ack),
 .IN_Isochronous(IN_Isochronous),
 .IN_Stall      (Stall),

 .DP(USB_D_P),
 .DM(USB_D_N)
);
//------------------------------------------------------------------------------

reg  [9:0]Descriptor_Address;
wire      Descriptor_ClockEnable = 1'b1;
wire [7:0]Descriptor_Data;

USB_Descriptors USB_Descriptors_Inst(
 .address(Descriptor_Address),
 .clken  (Descriptor_ClockEnable),
 .clock  (USB_Clk),
 .q      (Descriptor_Data)
);
//------------------------------------------------------------------------------

`include "USB/USB_Constants.vh"
//------------------------------------------------------------------------------

reg       Direction;
reg [ 1:0]Type;
reg [ 4:0]Recipient;
reg [ 7:0]RequestType;
reg [ 7:0]Request;
reg [15:0]Value;
reg [15:0]Index;
reg [15:0]Length;
reg [ 6:0]ByteCount;
reg [ 7:0]DataSize;
//------------------------------------------------------------------------------

reg   [5:0]State;
localparam Idle          = 6'd_0;
localparam GetRequest    = 6'd_1;
localparam GetValueLow   = 6'd_2;
localparam GetValueHigh  = 6'd_3;
localparam GetIndexLow   = 6'd_4;
localparam GetIndexHigh  = 6'd_5;
localparam GetLengthLow  = 6'd_6;
localparam GetLengthHigh = 6'd_7;
localparam GetDescriptor = 6'd_8;
localparam SendData      = 6'd_9;
localparam GetAck        = 6'd10;
//------------------------------------------------------------------------------

wire Descriptor_Type  = Value[15:8];
wire Descriptor_Index = Value[ 7:0];
//------------------------------------------------------------------------------

reg tReset;
always @(posedge USB_Clk) begin
 tReset <= Reset | ResetRequest;
//------------------------------------------------------------------------------

 if(tReset) begin
  Address         <= 0;
  Stall           <= 0;
  OUT_WaitRequest <= 0;
  OUT_Isochronous <= 0;
 
  IN_Sequence    <= 0;
  IN_Data        <= 0;
  IN_Ready       <= 0;
  IN_Isochronous <= 0;
  IN_ZeroLength  <= 0;

  State <= Idle;

  ByteCount <= 0;
//------------------------------------------------------------------------------

 end else begin
  OUT_WaitRequest <= ~(Endpoint == 0);
//------------------------------------------------------------------------------

  case(State)
   Idle: begin
    if(OUT_Valid & OUT_SoP) begin
     if(OUT_Setup) begin
      Stall       <= 0;
      IN_Sequence <= 0;
      {Direction, Type, Recipient} <= OUT_Data;
      State <= GetRequest;
     end
    end
   end
//------------------------------------------------------------------------------

   GetRequest: begin
    if(OUT_Valid) begin
     RequestType <= OUT_Data;
     State       <= GetValueLow;
    end
   end
//------------------------------------------------------------------------------

   GetValueLow: begin
    if(OUT_Valid) begin
     Value[7:0] <= OUT_Data;
     State      <= GetValueHigh;
    end
   end
//------------------------------------------------------------------------------

   GetValueHigh: begin
    if(OUT_Valid) begin
     Value[15:8] <= OUT_Data;
     State       <= GetIndexLow;
    end
   end
//------------------------------------------------------------------------------

   GetIndexLow: begin
    if(OUT_Valid) begin
     Index[7:0] <= OUT_Data;
     State      <= GetIndexHigh;
    end
   end
//------------------------------------------------------------------------------

   GetIndexHigh: begin
    if(OUT_Valid) begin
     Index[15:8] <= OUT_Data;
     State       <= GetLengthLow;
    end
   end
//------------------------------------------------------------------------------

   GetLengthLow: begin
    if(OUT_Valid) begin
     Length[7:0] <= OUT_Data;
     State       <= GetLengthHigh;
    end
   end
//------------------------------------------------------------------------------

   GetLengthHigh: begin
    if(OUT_Valid) begin
     Length[15:8] <= OUT_Data;
     case(Request)
//      GET_STATUS:        State <= GetStatus;
//      CLEAR_FEATURE:     State <= ClearFeature;
//      SET_FEATURE:       State <= SetFeature;
//      SET_ADDRESS:       State <= SetAddress;
      GET_DESCRIPTOR:    State <= GetDescriptor;
//      SET_DESCRIPTOR:    State <= SetDescriptor;
//      GET_CONFIGURATION: State <= GetConfiguration;
//      SET_CONFIGURATION: State <= SetConfiguration;
//      GET_INTERFACE:     State <= GetInterface;
//      SET_INTERFACE:     State <= SetInterface;
//      SYNCH_FRAME:       State <= SynchFrame;

      default: begin
       Stall <= 1'b1;
       State <= Idle;
      end
     endcase
    end
   end
//------------------------------------------------------------------------------

   GetDescriptor: begin
    if(Error) begin
     Stall <= 1'b1;
     State <= Idle;

    end else begin
     case(Descriptor_Type)
      DEVICE: begin
       Descriptor_Address <= 0;
       ByteCount          <= 0;
       DataSize           <= 8'd18;
       State              <= SendData;
      end

//      CONFIGURATION: begin
//      end
//
//      STRING: begin
//      end

      default: begin
       Stall <= 1'b1;
       State <= Idle;
      end
     endcase
    end
   end
//------------------------------------------------------------------------------

   SendData: begin
    IN_Data       <= Descriptor_Data;
    IN_Ready      <= (Endpoint == 0);
    IN_ZeroLength <= ~|DataSize;

    if(IN_WaitRequest) begin
     if(IN_Ack) begin // Possible for zero-length packets
      IN_Ready <= 1'b0;
      State    <= Idle;
     end else begin
      IN_Ready <= 1'b1;
     end

    end else begin
     if(
      (ByteCount == 7'd63) ||
      (ByteCount == (DataSize-1'b1))
     )begin
      IN_Ready <= 1'b0;
      State    <= GetAck;

     end else begin
      IN_Ready <= 1'b1;
     end

     ByteCount          <= ByteCount + 1'b1;
     Descriptor_Address <= Descriptor_Address + 1'b1;
    end
   end
//------------------------------------------------------------------------------

   GetAck: begin
    if(Error) begin
     Descriptor_Address <= Descriptor_Address - ByteCount;
     ByteCount <= 0;
     State     <= SendData;

    end else if(IN_Ack) begin
     IN_Sequence <= ~IN_Sequence;
     DataSize    <= DataSize - ByteCount;
     if(ByteCount == 7'd64) State <= SendData;
     else                   State <= Idle;

     ByteCount <= 0;
    end
   end
//------------------------------------------------------------------------------

   default:;
  endcase  
 end
end
//------------------------------------------------------------------------------

assign TP = {4'd0, FrameNumber[0]};
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

