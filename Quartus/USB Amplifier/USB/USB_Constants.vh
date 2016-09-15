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

// Line Symbols   +-
localparam J = 2'b10; // -- also the "Idle" state
localparam K = 2'b01;
localparam H = 2'b11;
localparam L = 2'b00;
localparam Z = 2'bZZ;
//------------------------------------------------------------------------------

// Start Signature
localparam START = 8'h80;
//------------------------------------------------------------------------------

// Token Constants
localparam TOKEN = 2'b___01;
localparam OUT   = 4'b_0001;
localparam IN    = 4'b_1001;
localparam SOF   = 4'b_0101;
localparam SETUP = 4'b_1101;

localparam CRC5POL = 5'b00101;
localparam CRC5RES = 5'b01100;
//------------------------------------------------------------------------------

// Handshaking Constants
localparam  ACK  = 4'b_0010;
localparam NACK  = 4'b_1010;
localparam STALL = 4'b_1110;
localparam NYET  = 4'b_0110;
//------------------------------------------------------------------------------

// Data Constants
localparam DATA     =  2'b__11;
localparam DATA0    =  4'b0011;
localparam DATA1    =  4'b1011;
localparam CRC16POL = 16'h8005;
localparam CRC16RES = 16'h800D;
//------------------------------------------------------------------------------

// Standard Request Codes
localparam GET_STATUS        = 8'd_0;
localparam CLEAR_FEATURE     = 8'd_1;
localparam SET_FEATURE       = 8'd_3;
localparam SET_ADDRESS       = 8'd_5;
localparam GET_DESCRIPTOR    = 8'd_6;
localparam SET_DESCRIPTOR    = 8'd_7;
localparam GET_CONFIGURATION = 8'd_8;
localparam SET_CONFIGURATION = 8'd_9;
localparam GET_INTERFACE     = 8'd10;
localparam SET_INTERFACE     = 8'd11;
localparam SYNCH_FRAME       = 8'd12;

// Audio Class Request Codes
localparam SET_CUR = 8'h01;
localparam GET_CUR = 8'h81;
localparam GET_MIN = 8'h82;
localparam GET_MAX = 8'h83;
localparam GET_RES = 8'h84;
//------------------------------------------------------------------------------

// Descriptor Types
localparam DEVICE                    = 8'h1;
localparam CONFIGURATION             = 8'h2;
localparam STRING                    = 8'h3;
localparam INTERFACE                 = 8'h4;
localparam ENDPOINT                  = 8'h5;
localparam DEVICE_QUALIFIER          = 8'h6;
localparam OTHER_SPEED_CONFIGURATION = 8'h7;
localparam INTERFACE_POWER           = 8'h8;

localparam CS_UNDEFINED     = 8'h20;
localparam CS_DEVICE        = 8'h21;
localparam CS_CONFIGURATION = 8'h22;
//------------------------------------------------------------------------------

// Control Constants
localparam MUTE_CONTROL   = 8'h01;
localparam VOLUME_CONTROL = 8'h02;
//------------------------------------------------------------------------------

// Descriptor Pointers
localparam DEVICE_POINTER        = 10'h000;

localparam CONFIGURATION_POINTER = 10'h012;
localparam CONFIGURATION_LENGTH  = 16'd189;

localparam STRING__0_POINTER = 10'h100; // Languages: English (UK)
localparam STRING__0_LENGTH  = 16'd_4;

localparam STRING__1_POINTER = 10'h140; // Manufacturer = "J Taylor"
localparam STRING__1_LENGTH  = 16'd18;

localparam STRING__2_POINTER = 10'h180; // Product = Interface 0 = HID Interface = "JPT Amplifier"
localparam STRING__2_LENGTH  = 16'd28;

localparam STRING__3_POINTER = 10'h1C0; // Terminal ID3 = "Amplifier and Speakers"
localparam STRING__3_LENGTH  = 16'd46;
//------------------------------------------------------------------------------

