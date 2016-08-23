// Line Symbols   +-
localparam J = 2'b10; // -- also the "Idle" state
localparam K = 2'b01;
localparam H = 2'b11;
localparam L = 2'b00;
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
localparam DEVICE                    = 8'd1;
localparam CONFIGURATION             = 8'd2;
localparam STRING                    = 8'd3;
localparam INTERFACE                 = 8'd4;
localparam ENDPOINT                  = 8'd5;
localparam DEVICE_QUALIFIER          = 8'd6;
localparam OTHER_SPEED_CONFIGURATION = 8'd7;
localparam INTERFACE_POWER1          = 8'd8;
//------------------------------------------------------------------------------

