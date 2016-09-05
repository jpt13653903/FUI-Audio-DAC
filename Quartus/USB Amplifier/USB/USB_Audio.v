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

module USB_Audio(
 input  Clk,
 input  Reset,

 output [10:0]FrameNumber,

 output reg      Active,
 output reg      Mute,
 output reg [7:0]Volume[1:0],

 input            Audio_Clk,  // 48 kHz
 output reg [15:0]Audio[1:0], // Registered just after falling edge of Audio_Clk

 inout DP, DM
);
//------------------------------------------------------------------------------

wire       ResetRequest;
reg  [ 6:0]Address;
wire [ 3:0]Endpoint;
reg        Stall;
wire       Error;

wire      OUT_Sequence;
wire      OUT_Setup;
wire      OUT_SoP;
wire      OUT_EoP;
wire      OUT_WaitRequest = (Endpoint > 1);
wire [7:0]OUT_Data;
wire      OUT_Valid;
wire      OUT_Isochronous = (Endpoint == 1);

reg       IN_Sequence;
reg  [7:0]IN_Data;
reg       IN_Ready;
wire      IN_ZeroLength;
wire      IN_WaitRequest;
wire      IN_Ack;
reg       IN_Isochronous;
//------------------------------------------------------------------------------
            
reg [9:0]FIFO_WriteAddress;
wire     FIFO_Write = (Endpoint == 1) & OUT_Valid & ~OUT_EoP;

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
      if(tReset | ~Active) FIFO_WriteAddress <= 0;
 else if(FIFO_Write      ) FIFO_WriteAddress <= FIFO_WriteAddress + 1'b1;

 // Resynchronise in the very rare case where a byte is lost and resynchronise:
 else if((Endpoint == 1) & OUT_Valid & OUT_EoP) FIFO_WriteAddress[1:0] <= 0;
end
//------------------------------------------------------------------------------

reg [1:0]Clk_48k;
reg      FIFO_Ready;
reg [7:0]FIFO_Length;

always @(posedge Clk) begin 
 Clk_48k <= {Clk_48k[0], Audio_Clk};

 FIFO_Length <= FIFO_WriteAddress[9:2] - FIFO_ReadAddress;

 if(tReset | ~Active) begin
  FIFO_Ready       <= 0;
  FIFO_ReadAddress <= 0;

  {Audio[1], Audio[0]} <= 0;
   
 end else begin
  if(FIFO_Ready) begin
   if(FIFO_Length == 8'h20) FIFO_Ready <= 1'b0;
  end else begin
   if(FIFO_Length == 8'h80) FIFO_Ready <= 1'b1;
  end

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

USB_Transceiver USB_Transceiver_Inst(
 .Clk  (Clk),
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

 .DP(DP),
 .DM(DM)
);
//------------------------------------------------------------------------------

reg  [9:0]Descriptor_Address;
wire      Descriptor_ClockEnable = 1'b1;
reg  [7:0]Descriptor_Data;

USB_Descriptors USB_Descriptors_Inst(
 .address(Descriptor_Address),
 .clken  (Descriptor_ClockEnable),
 .clock  (Clk),
 .q      (Descriptor_Data)
);
//------------------------------------------------------------------------------

`include "USB_Constants.vh"
//------------------------------------------------------------------------------

reg       Direction;
reg [ 1:0]Type;
reg [ 4:0]Recipient;
reg [ 7:0]Request;
reg [15:0]Value;
reg [15:0]Index;
reg [15:0]Length;
reg [ 6:0]ByteCount;
reg [15:0]DataSize;

reg [15:0]Temp;

assign IN_ZeroLength = ~|DataSize;
//------------------------------------------------------------------------------

reg   [5:0]State;
localparam Idle             = 6'd_0;
localparam GetRequest       = 6'd_1;
localparam GetValueLow      = 6'd_2;
localparam GetValueHigh     = 6'd_3;
localparam GetIndexLow      = 6'd_4;
localparam GetIndexHigh     = 6'd_5;
localparam GetLengthLow     = 6'd_6;
localparam GetLengthHigh    = 6'd_7;
localparam GetEoP           = 6'd_8;
localparam GetDescriptor    = 6'd_9;
localparam SetAddress       = 6'd10;
localparam SetConfiguration = 6'd11;
localparam SetInterface     = 6'd12;

localparam SetControl  = 6'd13;
localparam GetControl  = 6'd14;
localparam SendControl = 6'd15;

localparam SendData = 6'd62;
localparam GetAck   = 6'd63;
//------------------------------------------------------------------------------

wire [7:0]Descriptor_Type  = Value[15:8];
wire [7:0]Descriptor_Index = Value[ 7:0];
wire [7:0]ControlSelect    = Value[15:8];
wire [7:0]ChannelSelect    = Value[ 7:0];
wire [7:0]UnitID           = Index[15:8];
wire [7:0]Interface        = Index[ 7:0];
//------------------------------------------------------------------------------

reg tReset;
always @(posedge Clk) begin
 tReset <= Reset | ResetRequest;
//------------------------------------------------------------------------------

 if(tReset) begin
  Active    <= 0; // Idle (i.e. no sound)
  Mute      <= 0; // False
  Volume[0] <= 8'hBD; // 75%
  Volume[1] <= 8'hBD;

  Address <= 0;
  Stall   <= 0;

  IN_Sequence    <= 0;
  IN_Ready       <= 0;
  IN_Isochronous <= 0;

  State <= Idle;

  ByteCount <= 0;
//------------------------------------------------------------------------------

 end else if(OUT_Valid & OUT_SoP & OUT_Setup) begin
   IN_Ready    <= 1'b0;
   Stall       <= 0;
   IN_Sequence <= 1'b1;
   {Direction, Type, Recipient} <= OUT_Data;
   State <= GetRequest;
//------------------------------------------------------------------------------

 end else if(Endpoint == 0) begin
  case(State)
   Idle:; // Wait for SETUP, which is the short-circuit state above
//------------------------------------------------------------------------------

   GetRequest: begin
    if(OUT_Valid) begin
     Request <= OUT_Data;
     State   <= GetValueLow;
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
     State        <= GetEoP;
    end
   end
//------------------------------------------------------------------------------

   GetEoP: begin
    if(OUT_Valid & OUT_EoP) begin
     case({Type, Request})
      // Standard
//      {2'b00, GET_STATUS}:        State <= GetStatus;
//      {2'b00, CLEAR_FEATURE}:     State <= ClearFeature;
//      {2'b00, SET_FEATURE}:       State <= SetFeature;
      {2'b00, SET_ADDRESS}:       State <= SetAddress;
      {2'b00, GET_DESCRIPTOR}:    State <= GetDescriptor;
//      {2'b00, SET_DESCRIPTOR}:    State <= SetDescriptor;
//      {2'b00, GET_CONFIGURATION}: State <= GetConfiguration;
      {2'b00, SET_CONFIGURATION}: State <= SetConfiguration;
//      {2'b00, GET_INTERFACE}:     State <= GetInterface;
      {2'b00, SET_INTERFACE}:     State <= SetInterface;
//      {2'b00, SYNCH_FRAME}:       State <= SynchFrame;

      // Audio Class Specific
      {2'b01, SET_CUR}: State <= SetControl;
      {2'b01, GET_CUR},
      {2'b01, GET_MIN},
      {2'b01, GET_MAX},
      {2'b01, GET_RES}: State <= GetControl;

      default: begin
       Stall <= 1'b1;
       State <= Idle;
      end
     endcase
    end
   end
//------------------------------------------------------------------------------

   GetDescriptor: begin
    ByteCount <= 0;

    if(Error) begin
     Stall <= 1'b1;
     State <= Idle;

    end else begin
     case(Descriptor_Type)
      DEVICE: begin
       Descriptor_Address <= DEVICE_POINTER;
       State              <= SendData;
       if(Length < 16'd18) DataSize <= Length;
       else                DataSize <= 16'd18;
      end

      CONFIGURATION: begin
       Descriptor_Address <= CONFIGURATION_POINTER;
       State              <= SendData;
       if(Length < CONFIGURATION_LENGTH) DataSize <= Length;
       else                              DataSize <= CONFIGURATION_LENGTH;
      end

      STRING: begin
       case(Descriptor_Index)
        10'd_0: begin
         Descriptor_Address <= STRING__0_POINTER;
         State              <= SendData;
         if(Length < STRING__0_LENGTH) DataSize <= Length;
         else                          DataSize <= STRING__0_LENGTH;
        end

        10'd_1: begin
         Descriptor_Address <= STRING__1_POINTER;
         State              <= SendData;
         if(Length < STRING__1_LENGTH) DataSize <= Length;
         else                          DataSize <= STRING__1_LENGTH;
        end

        10'd_2: begin
         Descriptor_Address <= STRING__2_POINTER;
         State              <= SendData;
         if(Length < STRING__2_LENGTH) DataSize <= Length;
         else                          DataSize <= STRING__2_LENGTH;
        end

        10'd_3: begin
         Descriptor_Address <= STRING__3_POINTER;
         State              <= SendData;
         if(Length < STRING__3_LENGTH) DataSize <= Length;
         else                          DataSize <= STRING__3_LENGTH;
        end

        default: begin
         Stall <= 1'b1;
         State <= Idle;
        end
       endcase
      end

      default: begin
       Stall <= 1'b1;
       State <= Idle;
      end
     endcase
    end
   end
//------------------------------------------------------------------------------

   SetAddress: begin
    // Set-up for status
    DataSize <= 0;

    if(IN_Ack) begin
     Address  <= Value[6:0];
     IN_Ready <= 1'b0;
     State    <= Idle;
    end else begin
     IN_Ready <= 1'b1;
    end
   end
//------------------------------------------------------------------------------

   SetConfiguration: begin
    // Configuration <= Value[7:0]; Not applicable to this application

    // Set-up for status
    DataSize <= 0;

    if(IN_Ack) begin
     IN_Ready <= 1'b0;
     State    <= Idle;
    end else begin
     IN_Ready <= 1'b1;
    end
   end
//------------------------------------------------------------------------------

   SetInterface: begin
    if(Index == 16'd1) begin
     Active <= Value[0]; // Only one bit in this application
    end

    // Set-up for status
    DataSize <= 0;

    if(IN_Ack) begin
     IN_Ready <= 1'b0;
     State    <= Idle;
    end else begin
     IN_Ready <= 1'b1;
    end
   end
//------------------------------------------------------------------------------

   SetControl: begin
    // Set-up for status
    DataSize <= 0;

    if(IN_Ack) begin
     IN_Ready <= 1'b0;
     State    <= Idle;

    end else if(OUT_Valid) begin
     IN_Ready <= 1'b1;

     if(OUT_EoP) begin
      case({Request, ChannelSelect, ControlSelect, Interface, UnitID})
       {SET_CUR, 8'h_00, MUTE_CONTROL  , 16'h_00_02}: Mute      <= Temp[8];
       {SET_CUR, 8'h_01, VOLUME_CONTROL, 16'h_00_02}: Volume[0] <= Temp[7:0];
       {SET_CUR, 8'h_02, VOLUME_CONTROL, 16'h_00_02}: Volume[1] <= Temp[7:0];

       default: begin
        Stall <= 1'b1;
        State <= Idle;
       end
      endcase
     end else begin // Not EoP
      Temp <= {OUT_Data, Temp[15:8]};
     end
    end else begin
     IN_Ready <= 1'b1;
    end
   end
//------------------------------------------------------------------------------

   GetControl: begin
    ByteCount <= 0;

    case({Request, ChannelSelect, ControlSelect, Interface, UnitID})
     {GET_CUR, 8'h_00, MUTE_CONTROL, 16'h_00_02}: begin
      IN_Data  <= {7'd0, Mute};
      DataSize <= 16'd1;
      IN_Ready <= 1'b1;
      State    <= SendControl;
     end

     {GET_CUR, 8'h_01, VOLUME_CONTROL, 16'h_00_02}: begin
      {Temp, IN_Data} <= {8'd0, Volume[0]};
      DataSize <= 16'd2;
      IN_Ready <= 1'b1;
      State    <= SendControl;
     end

     {GET_CUR, 8'h_02, VOLUME_CONTROL, 16'h_00_02}: begin
      {Temp, IN_Data} <= {8'd0, Volume[1]};
      DataSize <= 16'd2;
      IN_Ready <= 1'b1;
      State    <= SendControl;
     end

     {GET_MIN, 8'h_01, VOLUME_CONTROL, 16'h_00_02},
     {GET_MIN, 8'h_02, VOLUME_CONTROL, 16'h_00_02}: begin
      {Temp, IN_Data} <= 16'h0000;
      DataSize <= 16'd2;
      IN_Ready <= 1'b1;
      State    <= SendControl;
     end

     {GET_MAX, 8'h_01, VOLUME_CONTROL, 16'h_00_02},
     {GET_MAX, 8'h_02, VOLUME_CONTROL, 16'h_00_02}: begin
      {Temp, IN_Data} <= 16'h00FF;
      DataSize <= 16'd2;
      IN_Ready <= 1'b1;
      State    <= SendControl;
     end

     {GET_RES, 8'h_01, VOLUME_CONTROL, 16'h_00_02},
     {GET_RES, 8'h_02, VOLUME_CONTROL, 16'h_00_02}: begin
      {Temp, IN_Data} <= 16'h0001;
      DataSize <= 16'd2;
      IN_Ready <= 1'b1;
      State    <= SendControl;
     end

     default: begin
      Stall <= 1'b1;
      State <= Idle;
     end
    endcase
   end
//------------------------------------------------------------------------------

   SendControl: begin
    if(IN_Ready) begin
     if(IN_Ack) IN_Sequence <= ~IN_Sequence;

     if(~IN_WaitRequest) begin
      if(ByteCount == (DataSize-1'b1)) IN_Ready <= 1'b0;

      ByteCount       <= ByteCount + 1'b1;
      {Temp, IN_Data} <= {8'd0, Temp};
     end

     if(OUT_Valid & OUT_EoP) begin
      IN_Ready <= 1'b0;
      State    <= Idle;
     end

    end else begin // Waiting for Ack
     if(Error) begin
      State <= GetControl;

     end else if(IN_Ack) begin
      IN_Sequence <= ~IN_Sequence;
      DataSize    <= 0;
      ByteCount   <= 0;
      IN_Ready    <= 1'b1;
     end
    end
   end
//------------------------------------------------------------------------------

   SendData: begin
    IN_Data <= Descriptor_Data;

    if(IN_WaitRequest) begin
     IN_Ready <= 1'b1;

     // In the case of zero-length packets:
     if(IN_Ack) IN_Sequence <= ~IN_Sequence;

    end else begin
     if(
      (ByteCount == 7'd63) ||
      (ByteCount == (DataSize-1'b1))
     ) begin
      IN_Ready <= 1'b0;
      State    <= GetAck;

     end else begin
      IN_Ready <= 1'b1;
     end

     ByteCount          <= ByteCount + 1'b1;
     Descriptor_Address <= Descriptor_Address + 1'b1;
    end

    if(OUT_Valid) begin
     IN_Ready <= 1'b0;
     if(OUT_EoP) State <= Idle;
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
     ByteCount   <= 0;
     State       <= SendData;
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

