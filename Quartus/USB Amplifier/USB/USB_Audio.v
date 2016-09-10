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
wire [ 6:0]Address;
wire [ 3:0]Endpoint;
reg        Stall;
wire       Error;

wire      OUT_Setup;
wire      OUT_SoP;
wire      OUT_EoP;
reg       OUT_WaitRequest;
wire [7:0]OUT_Data;
wire      OUT_Sequence;
wire      OUT_Valid;
reg       OUT_Isochronous;

reg       IN_Sequence;
reg  [7:0]IN_Data;
reg       IN_Ready;
reg       IN_ZeroLength;
wire      IN_WaitRequest;
wire      IN_Ack;
reg       IN_Isochronous;

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

wire      Control_Stall;

reg       Control_OUT_Setup;
reg       Control_OUT_SoP;
reg       Control_OUT_EoP;
wire      Control_OUT_WaitRequest;
reg  [7:0]Control_OUT_Data;
reg       Control_OUT_Sequence;
reg       Control_OUT_Valid;
wire      Control_OUT_Isochronous;

wire      Control_IN_Sequence;
wire [7:0]Control_IN_Data;
wire      Control_IN_Ready;
wire      Control_IN_ZeroLength;
reg       Control_IN_WaitRequest;
reg       Control_IN_Ack;
wire      Control_IN_Isochronous;

USB_Control USB_Control_inst(
 .Clk            (Clk),
 .Reset          (Reset | ResetRequest),
 .Error          (Error),

 .Address        (Address),
 .Stall          (Control_Stall),

 .OUT_Setup      (Control_OUT_Setup),
 .OUT_SoP        (Control_OUT_SoP),
 .OUT_EoP        (Control_OUT_EoP),
 .OUT_WaitRequest(Control_OUT_WaitRequest),
 .OUT_Data       (Control_OUT_Data),
 .OUT_Sequence   (Control_OUT_Sequence),
 .OUT_Valid      (Control_OUT_Valid),
 .OUT_Isochronous(Control_OUT_Isochronous),
 
 .IN_Sequence    (Control_IN_Sequence),
 .IN_Data        (Control_IN_Data),
 .IN_Ready       (Control_IN_Ready),
 .IN_ZeroLength  (Control_IN_ZeroLength),
 .IN_WaitRequest (Control_IN_WaitRequest),
 .IN_Ack         (Control_IN_Ack),
 .IN_Isochronous (Control_IN_Isochronous),

 .Active         (Active),
 .Mute           (Mute),
 .Volume         (Volume)
);
//------------------------------------------------------------------------------

wire      Stream_Stall;

reg       Stream_OUT_EoP;
wire      Stream_OUT_WaitRequest;
reg  [7:0]Stream_OUT_Data;
reg       Stream_OUT_Valid;
wire      Stream_OUT_Isochronous;

USB_Stream USB_Stream_inst(
 .Clk            (Clk),
 .Reset          (Reset | ResetRequest | ~Active),

 .Stall          (Stream_Stall),

 .OUT_EoP        (Stream_OUT_EoP),
 .OUT_WaitRequest(Stream_OUT_WaitRequest),
 .OUT_Data       (Stream_OUT_Data),
 .OUT_Valid      (Stream_OUT_Valid),
 .OUT_Isochronous(Stream_OUT_Isochronous),

 .Audio_Clk      (Audio_Clk),
 .Audio          (Audio)
);
//------------------------------------------------------------------------------

always @(*) begin
 case(Endpoint)
  4'd0: begin
   Stall           = Control_Stall;
   OUT_WaitRequest = Control_OUT_WaitRequest;
   OUT_Isochronous = Control_OUT_Isochronous;
   IN_Sequence     = Control_IN_Sequence;
   IN_Data         = Control_IN_Data;
   IN_Ready        = Control_IN_Ready;
   IN_ZeroLength   = Control_IN_ZeroLength;
   IN_Isochronous  = Control_IN_Isochronous;

   Control_OUT_Setup      = OUT_Setup;
   Control_OUT_SoP        = OUT_SoP;
   Control_OUT_EoP        = OUT_EoP;
   Control_OUT_Data       = OUT_Data;
   Control_OUT_Sequence   = OUT_Sequence;
   Control_OUT_Valid      = OUT_Valid;
   Control_IN_WaitRequest = IN_WaitRequest;
   Control_IN_Ack         = IN_Ack;

   Stream_OUT_EoP   = 0;
   Stream_OUT_Data  = 0;
   Stream_OUT_Valid = 0;
  end

  4'd1: begin
   Stall           = Stream_Stall;
   OUT_WaitRequest = Stream_OUT_WaitRequest;
   OUT_Isochronous = Stream_OUT_Isochronous;
   IN_Sequence     = 0;
   IN_Data         = 0;
   IN_Ready        = 0;
   IN_ZeroLength   = 0;
   IN_Isochronous  = 0;

   Control_OUT_Setup      = 0;
   Control_OUT_SoP        = 0;
   Control_OUT_EoP        = 0;
   Control_OUT_Data       = 0;
   Control_OUT_Sequence   = 0;
   Control_OUT_Valid      = 0;
   Control_IN_WaitRequest = 0;
   Control_IN_Ack         = 0;

   Stream_OUT_EoP   = OUT_EoP;
   Stream_OUT_Data  = OUT_Data;
   Stream_OUT_Valid = OUT_Valid;
  end

  default: begin
   Stall           = 1'b1;
   OUT_WaitRequest = 1'b1;
   OUT_Isochronous = 0;
   IN_Sequence     = 0;
   IN_Data         = 0;
   IN_Ready        = 0;
   IN_ZeroLength   = 0;
   IN_Isochronous  = 0;

   Control_OUT_Setup      = 0;
   Control_OUT_SoP        = 0;
   Control_OUT_EoP        = 0;
   Control_OUT_Data       = 0;
   Control_OUT_Sequence   = 0;
   Control_OUT_Valid      = 0;
   Control_IN_WaitRequest = 0;
   Control_IN_Ack         = 0;

   Stream_OUT_EoP   = 0;
   Stream_OUT_Data  = 0;
   Stream_OUT_Valid = 0;
  end
 endcase
end
//------------------------------------------------------------------------------

endmodule
//------------------------------------------------------------------------------

