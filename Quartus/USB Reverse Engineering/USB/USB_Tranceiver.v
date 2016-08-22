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
//------------------------------------------------------------------------------

// NRZI Receiver

localparam J = 2'b10; // D+ D- -- also the "Idle" state
localparam K = 2'b01;
localparam H = 2'b11;
localparam L = 2'b00;
//------------------------------------------------------------------------------

reg [6:0]L_Count; // Used to detect bus reset

reg [1:0]Symbol;
reg [1:0]Symbol_1;
reg [1:0]Symbol_4;
reg [1:0]ClkCount;
reg [2:0]StuffCount;
reg      StuffError;

reg      RxData;
reg      RxStop;
reg      RxValid;

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

  RxValid <= 0;
  State   <= Idle;
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
    RxData   <= 1'b0;
    Symbol_4 <= Symbol;
    ClkCount <= 2'd0;

    if({Symbol_1, Symbol} == {K, K}) begin
     RxValid <= 1'b1;
     State   <= Receiving;

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

      {J, L}, {K, L}: begin // Receiving a Stop / EOP
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
        // Todo: implement this
       end
      end
//------------------------------------------------------------------------------

      default:;
     endcase
    end else begin
     RxValid  <= 1'b0;
    end
   end
//------------------------------------------------------------------------------

   default:;
  endcase
 end
end
//------------------------------------------------------------------------------

// This prevents Quartus from removing the nodes

assign In_ClkEnable = 
 RxData        |
 RxStop        |
 RxValid       |
 StuffError    |
 Reset_Request ;
endmodule
//------------------------------------------------------------------------------

