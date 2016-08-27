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

/* USB Transceiver
 
This module provides an abstraction of the USB protocol layer.  Multiple
USB devices and endpoints can connect to the IN and OUT interfaces by
using the Address and Endpoint output registers as "enable" signals.

As per the USB standard, OUT => Host -> Device; IN => Device -> Host
//----------------------------------------------------------------------------*/

module USB_Transceiver(
 input Clk, // 48 MHz, exactly
 input Reset,

 // Global fields
 output           ResetRequest, // Reset-condition on the bus
 output reg [ 6:0]Address,
 output reg [ 3:0]Endpoint,
 output reg [10:0]FrameNumber,   // Incremented every 1 ms (+/- 500 ns)
 output reg       Error, // For OUT: set on stuff or CRC error
                         // For IN:  set on no ack
                         // Cleared on next transaction

 // OUT Endpoints (Host -> Device)
 output reg      OUT_Setup,       // High when this is a SETUP transaction
 output reg      OUT_SoP,         // Start of packet (on first byte)
 output reg      OUT_EoP,         // End of packet (after last byte)
 input           OUT_WaitRequest, // Causes a N-Ack on OUT transaction
 output reg [7:0]OUT_Data,        // Only the body of the DATA packet is sent
 output reg      OUT_Valid,       // The other fields of this interface is valid
 input           OUT_Isochronous, // Disables hand-shaking
 
 // IN Endpoints (Device -> Host)
 input      [7:0]IN_Data,
 input           IN_Ready, // High means entire packet is ready, low means EoP
 output reg      IN_WaitRequest,
 output reg      IN_Ack, // Pulsed for one cycle when packet sent successfully
 input  reg      IN_Isochronous, // Disables hand-shaking

 // The physical bus
 inout DP, DM
);
//------------------------------------------------------------------------------

wire StuffError;

wire NRZI_RxData;
wire NRZI_RxStop;
wire NRZI_RxValid;

 // Transmitter
reg  NRZI_TxData;
reg  NRZI_TxSend;
wire NRZI_TxNext;

USB_NRZI USB_NRZI_inst(
 Clk, // 48 MHz, exactly
 Reset,

 // Global fields
 ResetRequest, // Reset-condition on the bus
 StuffError,

 // Receiver
 NRZI_RxData,  // Bit received
 NRZI_RxStop,  // Stop condition received (RxData is not valid)
 NRZI_RxValid, // Either RxData or RxStop is valid

 // Transmitter
 NRZI_TxData, // Bit to send
 NRZI_TxSend, // Make high to signal that transmit mode is required
 NRZI_TxNext, // Asks for next bit (must be valid in the next cycle)

 // The physical bus
 DP, DM
);
//------------------------------------------------------------------------------

// Localise the reset

reg tReset;
always @(posedge Clk) tReset <= Reset | ResetRequest;
//------------------------------------------------------------------------------

reg [3:0]PID;
reg      PID_Error;
reg [3:0]LastToken;

reg [23:0]Shift;
reg [ 4:0]CRC5;
reg [15:0]CRC16;
reg       CRC_Error;

reg   [2:0]State;
localparam Idle       = 3'd0;
localparam Token      = 3'd1;
localparam Data       = 3'd2;
localparam Handshake  = 3'd3;
localparam ErrorState = 3'd4;

wire [7:0]SoP_1 =             Shift[16:9];
wire [7:0]PID_1 = {NRZI_Data, Shift[23:17]};

always @(posedge Clk) begin
 if(tReset) begin
  Shift     <= 0;
  State     <= Idle;
  PID_Error <= 0;
  CRC_Error <= 0;
  LastToken <= 0;
  
 end else if(NRZI_Valid) begin
  case(State)
   Idle: begin
    Shift <= {NRZI_Data, Shift[23:1]};
    CRC5  <= 5'b11111;
    CRC16 <= 16'hFFFF;

    if(SoP_1 == 8'h80) begin
     if(PID_1[7:4] == ~PID_1[3:0]) begin
      PID <= PID_1[3:0];
      case(PID_1[1:0])
       2'b01: State <= Token;
       2'b11: State <= Data;
       2'b10: State <= Handshake;
       default:;
      endcase
     end else begin
      PID_Error <= 1'b1;
      State     <= ErrorState;
     end
    end
   end

   Token: begin
    if(CRC5[4] ^ NRZI_Data) CRC5 <= {CRC5[3:0], 1'b0} ^ 5'b00101;
    else                    CRC5 <= {CRC5[3:0], 1'b0};

    if(NRZI_Stop) begin
     if(CRC5 == 5'b01100) begin
      case(PID[3:2])
       2'b01: begin
        FrameNumber <= Shift[18:8];
       end

       default: begin
        if(Shift[14:8] == Address) begin
         Endpoint  <= Shift[18:15];
         LastToken <= PID;
        end else begin
         LastToken <= 0; // Ignore further data packets and handshakes
        end
       end
      endcase
      Shift <= {24{1'b1}};
      State <= Idle;

     end else begin
      CRC_Error <= 1'b1;
      State     <= ErrorState;
     end
    end else begin
     Shift <= {NRZI_Data, Shift[23:1]};
    end
   end

   Data: begin
    if(CRC16[15] ^ NRZI_Data) CRC16 <= {CRC16[14:0], 1'b0} ^ 16'h8005;
    else                      CRC16 <= {CRC16[14:0], 1'b0};

    if(NRZI_Stop) begin
     if(CRC16 == 16'h800D) begin
      Shift <= {24{1'b1}};
      State <= Idle;
     end else begin
      CRC_Error <= 1'b1;
      State     <= ErrorState;
     end
    end else begin
     Shift <= {NRZI_Data, Shift[23:1]};
    end
   end

   Handshake: begin
    if(NRZI_Stop) begin
     Shift <= {24{1'b1}};
     State <= Idle;
    end
   end

   ErrorState: begin
    if(NRZI_Stop) begin
     PID_Error <= 1'b0;
     CRC_Error <= 1'b0;
     Shift     <= {24{1'b1}};
     State     <= Idle;
    end
   end

   default:;
  endcase
 end else begin
  if(NRZI_StuffError | PID_Error | CRC_Error) State <= ErrorState;
 end
end
//------------------------------------------------------------------------------

// This prevents Quartus from removing the nodes

assign In_ClkEnable = 
 &PID         |
 &Shift       |
 &FrameNumber |
 &Address     |
 &Endpoint    |
 &LastToken   |
 
 Reset_Request;
endmodule
//------------------------------------------------------------------------------

