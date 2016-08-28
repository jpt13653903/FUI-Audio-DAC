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

