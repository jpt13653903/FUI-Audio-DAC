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

/* USB Physical Layer
 
This module provides an abstraction of the raw USB physical layer.  It
performs the following functions:

- Receiver:
  - Clock-recovery
  - Translate incoming NRZI signalling to bit-stream
  - Remove stuff bits, and signal stuff-bit error conditions

- Transmitter:
  - Insert stuff bits into bit-stream
  - Translate bit-stream to NRZI signalling
//----------------------------------------------------------------------------*/

`include "USB_Interfaces.vh"
//----------------------------------------------------------------------------*/

module USB_NRZI(
 input Clk, // 48 MHz, exactly
 input Reset,

 // Global fields
 output reg ResetRequest, // Reset-condition on the bus
 output reg StuffError;   // Cleared just after receiving stop condition

 // Receiver
 output reg RxData;  // Bit received
 output reg RxStop;  // Stop condition received (RxData is not valid)
 output reg RxValid; // Either RxData or RxStop is valid

 // Transmitter
 input      TxData; // Bit to send
 input      TxSend; // Make high to signal that transmit mode is required
 output reg TxNext; // Asks for next bit (must be valid in the next cycle)

 // The physical bus
 inout reg DP, DM
);
//------------------------------------------------------------------------------

`include "USB_Constants.vh"
//------------------------------------------------------------------------------

// Localise the reset

reg tReset;
always @(posedge Clk) tReset <= Reset | ResetRequest;
//------------------------------------------------------------------------------

// NRZI Transceiver

reg   [1:0]Symbol;
reg   [1:0]Symbol_1;
reg   [1:0]Symbol_4;
reg   [1:0]ClkCount;
reg   [2:0]StuffCount; // Used to handle stuff-bits
reg   [6:0]L_Count;    // Used to detect bus reset

reg   [1:0]State;
localparam Idle         = 2'd0;
localparam Receiving    = 2'd1;
localparam Transmitting = 2'd2;
localparam SendStop     = 2'd3;
//------------------------------------------------------------------------------

always @(posedge Clk) begin
 Symbol_1 <= Symbol;
 Symbol   <= {DP, DM};
//------------------------------------------------------------------------------

 if(tReset) begin
  {DP, DM} <= Z;

  L_Count      <= 0;
  ResetRequest <= 0;

  RxValid <= 0;
  TxNext  <= 0;
  State   <= Idle;
//------------------------------------------------------------------------------

 end else begin
  if(Symbol == L) begin
   if(L_Count == 7'd120) ResetRequest <= 1'b1;
   else                  L_Count      <= L_Count + 1'b1;
  end else begin
   L_Count      <= 0;
   ResetRequest <= 0;
  end
//------------------------------------------------------------------------------

  case(State)
   Idle: begin
    {DP, DM}   <= Z;
    RxData     <= 0;
    ClkCount   <= 0;
    StuffCount <= 0;
    Symbol_4   <= Symbol;

    if({Symbol_1, Symbol} == {K, K}) begin
     RxValid <= 1'b1;
     State   <= Receiving;

    end else if((Symbol == J) && TxSend) begin
     State <= Transmitting;
    end
   end
//------------------------------------------------------------------------------

   Receiving: begin
    // Clock-recovery
    case({Symbol_1, Symbol})
     {J, K}, {K, J}                : ClkCount <= 2'd3;
     {J, H}, {J, L}, {K, H}, {K, L}: ClkCount <= 2'd2;
     default                       : ClkCount <= ClkCount + 1'b1;
    endcase

    // NRZI Decoder
    if(&ClkCount) begin
     Symbol_4 <= Symbol;
    
     case({Symbol_4, Symbol})
      {J, J}, {K, K}: begin // Receiving a 1
       if(StuffCount == 3'd6) StuffError <= 1'b1;
       RxData     <= 1'b1;
       RxValid    <= 1'b1;
       StuffCount <= StuffCount + 1'b1;
      end

      {J, K}, {K, J}: begin // Receiving a 0
       if(StuffCount != 3'd6) RxValid <= 1'b1;
       RxData     <= 1'b0;
       RxStop     <= 1'b0;
       StuffCount <= 0;
      end

      {J, L}, {K, L}: begin // Receiving a RxStop / EOP
       RxData  <= 1'b0;
       RxStop  <= 1'b1;
       RxValid <= 1'b1;
      end

      {L, J}: begin
       RxStop     <= 1'b0;
       StuffCount <= 0;
       StuffError <= 0;
       State      <= Idle;
      end
//------------------------------------------------------------------------------

      Transmitting: begin
       ClkCount <= ClkCount + 1'b1;
 
       if(&ClkCount) begin
        if(TxSend) begin
         if(TxData) begin
          if(StuffCount == 3'd6) begin
           {DP, DM}   <= ~Symbol;
           StuffCount <= 0;
          end else begin
           TxNext     <= 1'b1;
           StuffCount <= StuffCount + 1'b1;
          end

         end else begin // ~ TxData
          {DP, DM}   <= ~Symbol;
          TxNext     <= 1'b1;
          StuffCount <= 0;
         end

        end else begin // ~TxSend
         {DP, DM}   <= L;
         StuffCount <= 0;
         State      <= SendStop;
        end

       end else begin // ~&ClkCount
        TxNext <= 1'b0;
       end
      end
//------------------------------------------------------------------------------

      SendStop: begin
       if(StuffCount[0]) begin
        {DP, DM} <= J;
        State    <= Idle;
       end
       StuffCount <= StuffCount + 1'b1;
      end
//------------------------------------------------------------------------------

      default:;
     endcase
    end else begin
     RxValid <= 1'b0;
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

