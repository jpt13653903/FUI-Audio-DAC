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
 
This module provides an abstraction of the USB protocol layer.  Multiple USB 
endpoints can connect to the IN and OUT interfaces by using the Endpoint output 
register as an "enable" signals.

The Address is an input, and must be controlled by the control endpoint
connected to endpoint 0.

As per the USB standard, OUT => Host -> Device; IN => Device -> Host
//----------------------------------------------------------------------------*/

module USB_Transceiver(
 input Clk, // 48 MHz, exactly
 input Reset,

 // Global fields
 output           ResetRequest, // Reset-condition on the bus
 input      [ 6:0]Address,      // Must be reset to zero
 output reg [ 3:0]Endpoint,
 output reg [10:0]FrameNumber,  // Incremented every 1 ms (+/- 500 ns)
 output reg       Error, // For OUT: set on stuff or CRC error
                         // For IN:  set on no ack
                         // Cleared on next transaction

 // OUT Endpoints (Host -> Device)
 output reg      OUT_Setup,       // High when this is a SETUP transaction
 output reg      OUT_SoP,         // Start of packet (on first byte)
 output reg      OUT_EoP,         // End of packet (after last byte)
 input           OUT_WaitRequest, // Causes a N-Ack on OUT transaction
 output reg [7:0]OUT_Data,        // Only the body of the DATA packet is sent
 output reg      OUT_Sequence,    // Current sequence number
 output reg      OUT_Valid,       // The other fields of this interface is valid
 input           OUT_Isochronous, // Disables hand-shaking
 input           OUT_Stall,       // Always return a "Stall" hand-shake
 
 // IN Endpoints (Device -> Host)
 input           IN_Sequence,
 input      [7:0]IN_Data,
 input           IN_Ready, // High means entire packet is ready, low means EoP
 input           IN_ZeroLength, // Make high to means zero-length packet
 output reg      IN_WaitRequest,
 output reg      IN_Ack, // Pulsed for one cycle when packet sent successfully
 input  reg      IN_Isochronous, // Disables hand-shaking
 input           IN_Stall, // Always return a "Stall" hand-shake

 // The physical bus
 inout DP, DM
);
//------------------------------------------------------------------------------

`include "USB_Constants.vh"
//------------------------------------------------------------------------------

wire StuffError;

wire NRZI_RxData;
wire NRZI_RxStop;
wire NRZI_RxValid;

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

reg [ 3:0]PID;
reg [15:0]Shift;
reg [ 4:0]CRC5;
reg [15:0]CRC16;
//------------------------------------------------------------------------------

reg   [3:0]State;
localparam Idle             = 4'd0;
localparam ReceiveToken     = 4'd1;
localparam WaitForData      = 4'd2;
localparam ReceiveData      = 4'd3;
localparam SendHandshake    = 4'd4;
localparam SendDataHeader   = 4'd5;
localparam SendData         = 4'd6;
localparam SendCRC          = 4'd7;
localparam WaitForHandshake = 4'd8;
localparam Ignore           = 4'd9;
//------------------------------------------------------------------------------

reg [4:0]DataCount;
reg [6:0]TimeoutCount;
reg      OUT_WaitRequest_1;
//------------------------------------------------------------------------------

// Short-cuts
wire [7:0]SoP_1 =               Shift[ 8:1];
wire [7:0]PID_1 = {NRZI_RxData, Shift[15:9]};
//------------------------------------------------------------------------------

always @(posedge Clk) begin
 if(tReset) begin
  OUT_Valid      <= 1'b0;
  IN_WaitRequest <= 1'b1;
  IN_Ack         <= 1'b0;
  NRZI_TxSend    <= 1'b0;

  Shift <= 16'hFFFF;
  State <= Idle;
  Error <= 0;
//------------------------------------------------------------------------------

 end else begin
  case(State)
   Idle: begin
    OUT_EoP   <= 1'b0;
    OUT_Valid <= 1'b0;
    IN_Ack    <= 1'b0;

    if(NRZI_RxValid) begin
     Shift <= {NRZI_RxData, Shift[15:1]};
     CRC5  <= 5'b11111;

     if(SoP_1 == START) begin
      if(PID_1[7:4] == ~PID_1[3:0]) begin
       PID <= PID_1[3:0];

       if(PID_1[1:0] == TOKEN) begin
        Error <= 0;
        State <= ReceiveToken;
       end else begin // Packet meant for some other device
        State <= Ignore;
       end

      end else begin // PID Error
       Error <= 1'b1;
       State <= Ignore;
      end
     end
    end else if(StuffError) begin
     Error <= 1'b1;
     State <= Ignore;
    end
   end
//------------------------------------------------------------------------------

   ReceiveToken: if(NRZI_RxValid) begin
    CRC16 <= 16'hFFFF; // Setup for SendDataHeader (IN)

    if(CRC5[4] ^ NRZI_RxData) CRC5 <= {CRC5[3:0], 1'b0} ^ CRC5POL;
    else                      CRC5 <= {CRC5[3:0], 1'b0};

    if(NRZI_RxStop) begin
     if(CRC5 == CRC5RES) begin
      Endpoint <= Shift[10:7];

      case(PID[3:2])
       2'b11: begin // SETUP
        OUT_Setup <= 1'b1;
        if(Address == Shift[6:0]) State <= WaitForData;
        else                      State <= Idle;
       end

       2'b00: begin // OUT
        OUT_Setup <= 1'b0;
        if(Address == Shift[6:0]) State <= WaitForData;
        else                      State <= Idle;
       end

       2'b10: begin // IN
        if(Address == Shift[6:0]) State <= SendDataHeader;
        else                      State <= Idle;
       end

       2'b01: begin // SOF
        FrameNumber <= Shift[10:0];
        State       <= Idle;
       end

       default:;
      endcase
     end else begin // CRC Fail
      Error <= 1'b1;
      State <= Idle;
     end
     Shift <= 16'hFFFF;

    end else begin // ~NRZI_RxStop
     Shift <= {NRZI_RxData, Shift[15:1]};
    end

   end else if(StuffError) begin
    Error <= 1'b1;
    State <= Ignore;
   end
//------------------------------------------------------------------------------

   WaitForData: if(NRZI_RxValid) begin
    Shift     <= {NRZI_RxData, Shift[15:1]};
    CRC16     <= 16'hFFFF;
    OUT_SoP   <= 1'b1;
    OUT_EoP   <= 0;
    DataCount <= 0;

    OUT_WaitRequest_1 <= OUT_WaitRequest;

    if(SoP_1 == START) begin
     if(PID_1[7:4] == ~PID_1[3:0]) begin
      PID <= PID_1[3:0];
      if(PID_1[1:0] == DATA) begin
       State <= ReceiveData;

      end else begin // Wrong packet type
       Error <= 1'b1;
       State <= Ignore;
      end
     end else begin // PID Error
      Error <= 1'b1;
      State <= Ignore;
     end
    end
   end else if(StuffError) begin
    Error <= 1'b1;
    State <= Ignore;
   end
//------------------------------------------------------------------------------

   ReceiveData: if(NRZI_RxValid) begin
    OUT_Sequence <= PID[3];

    if(CRC16[15] ^ NRZI_RxData) CRC16 <= {CRC16[14:0], 1'b0} ^ CRC16POL;
    else                        CRC16 <= {CRC16[14:0], 1'b0};

    if(NRZI_RxStop) begin
     if(CRC16 == CRC16RES) begin
      OUT_EoP   <= 1'b1;
      OUT_Valid <= ~OUT_WaitRequest_1;

      if(OUT_Isochronous) begin
       Shift <= 16'hFFFF;
       State <= Idle;

      end else if(OUT_WaitRequest_1) begin
       Shift <= {~NACK, NACK, START};
       State <= SendHandshake;

      end else if(OUT_Stall) begin
       Shift <= {~STALL, STALL, START};
       State <= SendHandshake;

      end else begin
       Shift <= {~ACK, ACK, START};
       State <= SendHandshake;
      end
     end else begin // CRC Fail
      Error <= 1'b1;
      Shift <= 16'hFFFF;
      State <= Idle;
     end
     
    end else begin // ~NRZI_RxStop
     if(DataCount == 5'd16) begin // Data not part of CRC, so send it on...
      OUT_Data  <= Shift[7:0];
      OUT_Valid <= ~OUT_WaitRequest_1;
      DataCount <= 5'd9;
     end else begin
      OUT_Valid <= 1'b0;
      DataCount <= DataCount + 1'b1;
     end
     Shift <= {NRZI_RxData, Shift[15:1]};
    end

   end else if(StuffError) begin
    Error <= 1'b1;
    State <= Ignore;

   end else begin
    if(OUT_Valid) OUT_SoP <= 0;
    OUT_Valid <= 1'b0;
   end
//------------------------------------------------------------------------------

   SendHandshake: begin
    OUT_EoP   <= 1'b0;
    OUT_Valid <= 1'b0;

    if(NRZI_TxSend) begin
     if(NRZI_TxNext) begin
      if(DataCount == 5'd15) begin
       NRZI_TxSend <= 1'b0;
       Shift       <= 16'hFFFF;
       State       <= Idle;
      end else begin
       {Shift, NRZI_TxData} <= {1'b1, Shift};
      end
      DataCount <= DataCount + 1'b1;
     end

    end else begin
     DataCount <= 0;
     {Shift, NRZI_TxData} <= {1'b1, Shift};
     NRZI_TxSend <= 1'b1;
    end
   end
//------------------------------------------------------------------------------

   SendDataHeader: begin
    if(NRZI_TxSend) begin
     if(NRZI_TxNext) begin
      if(DataCount == 5'd15) begin
       DataCount <= 0;

       if(IN_Ready & ~IN_ZeroLength) begin
        {Shift, NRZI_TxData} <= {9'h1FF, IN_Data};
        if(CRC16[15] ^ IN_Data[0]) CRC16 <= {CRC16[14:0], 1'b0} ^ CRC16POL;
        else                       CRC16 <= {CRC16[14:0], 1'b0};

        DataCount      <= 0;
        IN_WaitRequest <= 1'b0;
        State          <= SendData;

       end else begin // ~IN_Ready : Transmission complete; send CRC
        {NRZI_TxData, CRC16} <= ~{CRC16, 1'b0};
        State <= SendCRC;
       end

      end else begin // DataCount != 15
       {Shift, NRZI_TxData} <= {1'b1, Shift};
       DataCount <= DataCount + 1'b1;
      end
     end

    end else begin // ~NRZI_TxSend
     if(IN_Ready) begin
      DataCount   <= 0;
      NRZI_TxSend <= 1'b1;

      if(IN_Sequence) {Shift, NRZI_TxData} <= {1'b1, ~DATA1, DATA1, START};
      else            {Shift, NRZI_TxData} <= {1'b1, ~DATA0, DATA0, START};

     end else begin // Not ready: send NACK / STALL
      if(IN_Isochronous) begin
       Shift <= 16'hFFFF;
       State <= Idle;

      end else if(IN_Stall) begin
       Shift <= {~STALL, STALL, START};
       State <= SendHandshake;

      end else begin
       Shift <= {~NACK, NACK, START};
       State <= SendHandshake;
      end
     end
    end
   end
//------------------------------------------------------------------------------
   
   SendData: begin
    if(NRZI_TxNext) begin
     if(DataCount == 5'd7) begin
      DataCount <= 0;

      if(IN_Ready) begin
       {Shift, NRZI_TxData} <= {9'h1FF, IN_Data};
       if(CRC16[15] ^ IN_Data[0]) CRC16 <= {CRC16[14:0], 1'b0} ^ CRC16POL;
       else                       CRC16 <= {CRC16[14:0], 1'b0};

       DataCount      <= 0;
       IN_WaitRequest <= 1'b0;

      end else begin // ~IN_Ready : Transmission complete; send CRC
       {NRZI_TxData, CRC16} <= ~{CRC16, 1'b0};
       State <= SendCRC;
      end

     end else begin // DataCount != 7
      {Shift, NRZI_TxData} <= {1'b1, Shift};
      if(CRC16[15] ^ Shift[0]) CRC16 <= {CRC16[14:0], 1'b0} ^ CRC16POL;
      else                     CRC16 <= {CRC16[14:0], 1'b0};
      DataCount      <= DataCount + 1'b1;
      IN_WaitRequest <= 1'b1;
     end

    end else begin // ~NRZI_TxNext
     IN_WaitRequest <= 1'b1;
    end
   end
//------------------------------------------------------------------------------

   SendCRC: if(NRZI_TxNext) begin
    TimeoutCount <= 0;

    {NRZI_TxData, CRC16} <= {CRC16, 1'b0};

    if(DataCount == 5'd15) begin
     DataCount <= 0;
     
     Shift       <= 16'hFFFF;
     NRZI_TxSend <= 1'b0;
     if(IN_Isochronous) begin
      IN_Ack <= 1'b1;
      State  <= Idle;
     end else begin
      State <= WaitForHandshake;
     end

    end else begin
     DataCount <= DataCount + 1'b1;
    end
   end
//------------------------------------------------------------------------------

   WaitForHandshake: begin
    if(NRZI_RxValid) begin
     TimeoutCount <= 0;

     if(Shift[7:0] == START) begin
      if(Shift[15:12] == ~Shift[11:8]) begin
       if(NRZI_RxStop && (Shift[11:8] == ACK)) begin
        IN_Ack <= 1'b1;
        Shift  <= 16'hFFFF;
        State  <= Idle;

       end else begin // Wrong packet type
        Error <= 1'b1;
        State <= Ignore;
       end
      end else begin // PID Error
       Error <= 1'b1;
       State <= Ignore;
      end
     end else begin // Not start yet
      Shift <= {NRZI_RxData, Shift[15:1]};
     end

    end else if(StuffError) begin
     Error <= 1'b1;
     State <= Ignore;

    end else begin
     if(TimeoutCount == 7'd76) begin // 17 bit-times after L -> J
      Error <= 1'b1;
      Shift <= 16'hFFFF;
      State <= Idle;
     end
     TimeoutCount <= TimeoutCount + 1'b1;
    end
   end
//------------------------------------------------------------------------------

   Ignore: begin
    Shift <= 16'hFFFF;
    if(NRZI_RxStop) State <= Idle;
   end
//------------------------------------------------------------------------------

   default:;
  endcase
 end
end
//------------------------------------------------------------------------------

endmodule
//------------------------------------------------------------------------------

