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

module USB_Control(
 input Clk,
 input Reset,
 input Error,

 output reg [6:0]Address,
 output reg      Stall,

 input           OUT_Setup,
 input           OUT_SoP,
 input           OUT_EoP,
 output          OUT_WaitRequest,
 input      [7:0]OUT_Data,
 input           OUT_Sequence,
 input           OUT_Valid,
 output          OUT_Isochronous,
 
 output reg      IN_Sequence,
 output reg [7:0]IN_Data,
 output reg      IN_Ready,
 output          IN_ZeroLength,
 input           IN_WaitRequest,
 input           IN_Ack,
 output reg      IN_Isochronous,

 output reg      Active,
 output reg      Mute,
 output reg [7:0]Volume[1:0]
);
//------------------------------------------------------------------------------

`include "USB_Constants.vh"
//------------------------------------------------------------------------------

assign OUT_WaitRequest = 1'b0;
assign OUT_Isochronous = 1'b0;
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
 tReset <= Reset;
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

 end else begin
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

