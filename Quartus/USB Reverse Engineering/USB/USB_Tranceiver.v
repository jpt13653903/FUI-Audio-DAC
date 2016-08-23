module USB_Tranceiver(
  input Clk, // 48 MHz, exactly
  input Reset,

  // Global fields
  output reg       Reset_Request, // Reset-condition on the bus
  input      [ 6:0]Address,       // Reset to zero
  output reg [10:0]FrameNumber,   // Incremented every 1 ms (+/- 500 ns)
  output reg [ 3:0]Endpoint,      // Current endpoint, set by IN, OUT and SETUP

  // Setup port of control endpoints
  output reg [ 3:0]Setup_Endpoint,
  output reg [ 7:0]Setup_RequestType,
  output reg [ 7:0]Setup_Request,
  output reg [15:0]Setup_Value,
  output reg [15:0]Setup_Index,
  output reg [15:0]Setup_Length,
  output reg       Setup_Valid, // Goes high on new transaction
  input            Setup_Ack,   // Signals that the endpoint received the setup

  // Out port (Host -> Device)
  input           Out_UseHandshaking, // 0 => Isochronous, 1 => All others
  output reg [7:0]Out_Data,
  output reg      Out_Valid,
  input           Out_WaitRequest, // Indicates that a NACK must be sent

  // In port (Device -> Host)
  input           In_UseHandshaking, // 0 => Isochronous, 1 => All others
  input      [9:0]In_ByteCount, // Number of bytes to send (can be 0)
  output reg      In_ClkEnable, // Read port clock-enable of the FIFO queue
  output reg [9:0]In_Address,   // Address into the FIFO queue (always from 0)
  input      [7:0]In_Data,      // Directly from the FIFO queue
  input           In_Send,      // All is set up and ready, so send the bytes
  output reg      In_Busy,      // Busy sending the bytes (goes low on success)

  // The physical bus
  inout reg DP, DM
);
//------------------------------------------------------------------------------

`include "USB_Constants.vh"
//------------------------------------------------------------------------------

// Todo:
//
// - Be able to transmit
// - Insert stuff bits and encode to NRZI

// Next layer:
// - De-serialise the bit stream into Sync, PID, etc.
// - Run the CRC checks
//
// - For transmit, insert the overhead and calculate the CRCs

// Start sequence:
// - Do nothing except wait for reset (SE0 for >= 2.5 μs)
// - After reset, wait for configure and respond

// Note:
// - An extended SE0 => reset -- implement this (section 7.1.7.5, page 181)
// - When implementing the transmit portion, change the bus on the cycle
//   that ClkCount == 0 (about to go to 3)

// CRCs:
// -- When sending CRCs, send them MSb first (page 226 of the specification)
//------------------------------------------------------------------------------

// NRZI Transceiver

reg [6:0]L_Count; // Used to detect bus reset

reg [1:0]Symbol;
reg [1:0]Symbol_1;
reg [1:0]Symbol_4;
reg [1:0]ClkCount;
reg [2:0]StuffCount;
reg      StuffError;

reg      Data;
reg      Stop;
reg      Valid;

reg        tReset;
reg   [1:0]State;
localparam Idle         = 2'd0;
localparam Receiving    = 2'd1;
localparam Transmitting = 2'd2;
//------------------------------------------------------------------------------

always @(posedge Clk) begin
 tReset   <= Reset | Reset_Request;
 Symbol_1 <= Symbol;
 Symbol   <= {DP, DM};
//------------------------------------------------------------------------------

 if(tReset) begin
  L_Count       <= 0;
  Reset_Request <= 0;

  Valid <= 0;
  State <= Idle;
//------------------------------------------------------------------------------

 end else begin
  if(Symbol == L) begin
   if(L_Count == 7'd120) Reset_Request <= 1'b1;
   else                  L_Count       <= L_Count + 1'b1;
  end else begin
   L_Count       <= 0;
   Reset_Request <= 0;
  end
//------------------------------------------------------------------------------

  case(State)
   Idle: begin
    Data     <= 1'b0;
    Symbol_4 <= Symbol;
    ClkCount <= 2'd0;

    if({Symbol_1, Symbol} == {K, K}) begin
     Valid <= 1'b1;
     State <= Receiving;

    end else if(1'b0/*Transmit trigger*/) begin
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
       Data       <= 1'b1;
       Valid      <= 1'b1;
       StuffCount <= StuffCount + 1'b1;
      end

      {J, K}, {K, J}: begin // Receiving a 0
       if(StuffCount != 3'd6) Valid <= 1'b1;
       Data       <= 1'b0;
       Stop       <= 1'b0;
       StuffCount <= 0;
      end

      {J, L}, {K, L}: begin // Receiving a Stop / EOP
       Data  <= 1'b0;
       Stop  <= 1'b1;
       Valid <= 1'b1;
      end

      {L, J}: begin
       Stop       <= 1'b0;
       StuffCount <= 0;
       StuffError <= 0;
       State      <= Idle;
      end
//------------------------------------------------------------------------------

      Transmitting: begin
       ClkCount <= ClkCount + 1'b1;
 
       if(&ClkCount) begin
        // Todo: implement this
       end
      end
//------------------------------------------------------------------------------

      default:;
     endcase
    end else begin
     Valid  <= 1'b0;
    end
   end
//------------------------------------------------------------------------------

   default:;
  endcase
 end
end
//------------------------------------------------------------------------------

reg [3:0]PID;
reg      PID_Error;
reg [3:0]LastToken;

reg [23:0]Shift;
reg [ 4:0]CRC5;
reg [15:0]CRC16;
reg       CRC_Error;

reg   [2:0]RxState;
localparam RxIdle      = 3'd0;
localparam RxToken     = 3'd1;
localparam RxData      = 3'd2;
localparam RxHandshake = 3'd3;
localparam RxError     = 3'd4;

wire [7:0]SoP_1 =        Shift[16:9];
wire [7:0]PID_1 = {Data, Shift[23:17]};

always @(posedge Clk) begin
 if(tReset) begin
  Shift     <= 0;
  RxState   <= RxIdle;
  PID_Error <= 0;
  CRC_Error <= 0;
  LastToken <= 0;
  
 end else if(Valid) begin
  case(RxState)
   RxIdle: begin
    Shift <= {Data, Shift[23:1]};
    CRC5  <= 5'b11111;
    CRC16 <= 16'hFFFF;

    if(SoP_1 == 8'h80) begin
     if(PID_1[7:4] == ~PID_1[3:0]) begin
      PID <= PID_1[3:0];
      case(PID_1[1:0])
       2'b01: RxState <= RxToken;
       2'b11: RxState <= RxData;
       2'b10: RxState <= RxHandshake;
       default:;
      endcase
     end else begin
      PID_Error <= 1'b1;
      RxState   <= RxError;
     end
    end
   end

   RxToken: begin
    if(CRC5[4] ^ Data) CRC5 <= {CRC5[3:0], 1'b0} ^ 5'b00101;
    else               CRC5 <= {CRC5[3:0], 1'b0};

    if(Stop) begin
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
      Shift   <= {24{1'b1}};
      RxState <= RxIdle;

     end else begin
      CRC_Error <= 1'b1;
      RxState   <= RxError;
     end
    end else begin
     Shift <= {Data, Shift[23:1]};
    end
   end

   RxData: begin
    if(CRC16[15] ^ Data) CRC16 <= {CRC16[14:0], 1'b0} ^ 16'h8005;
    else                 CRC16 <= {CRC16[14:0], 1'b0};

    if(Stop) begin
     if(CRC16 == 16'h800D) begin
      Shift   <= {24{1'b1}};
      RxState <= RxIdle;
     end else begin
      CRC_Error <= 1'b1;
      RxState   <= RxError;
     end
    end else begin
     Shift <= {Data, Shift[23:1]};
    end
   end

   RxHandshake: begin
    if(Stop) begin
     Shift   <= {24{1'b1}};
     RxState <= RxIdle;
    end
   end

   RxError: begin
    if(Stop) begin
     PID_Error <= 1'b0;
     CRC_Error <= 1'b0;
     Shift     <= {24{1'b1}};
     RxState   <= RxIdle;
    end
   end

   default:;
  endcase
 end else begin
  if(StuffError | PID_Error | CRC_Error) RxState <= RxError;
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

