module USB_Tranceiver(
  input Clk,
  input Reset,

  inout reg D_P, D_N,

  output Output
);
//------------------------------------------------------------------------------

// Physical:
// - Catch the reset condition: SE0 >= 2.5 μs)
// - Clock-recover (as below)
// - Decode the NRZI and remove stuff bits (as below)
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

reg [1:0]D_P_1;
reg      D_N_1;
reg [1:0]ClkCount;

reg Prev;
reg Data;
reg Stop;
reg Valid;
reg Error;
reg [2:0]StuffCount;

reg [31:0]Shift;
reg [ 3:0]PID;
reg [ 6:0]Address;
reg [ 3:0]Endpoint;
reg [ 4:0]CRC5;
reg [15:0]HeaderCount;

reg   [1:0]State;
localparam Idle = 2'd0;
localparam Rx   = 2'd1;

reg tReset;
always @(posedge Clk) begin
 tReset <= Reset; // Pipeline the reset

 D_P_1 <= {D_P_1[0], D_P};
 D_N_1 <=            D_N ;

 if(tReset) begin
  D_P <= 1'bZ;
  D_N <= 1'bZ;

  Valid <= 0;
  Error <= 0;
  State <= Idle;

  HeaderCount <= 0;

 end else if(^D_P_1) begin
  Valid    <= 1'b0;
  ClkCount <= 2'd3;

 end else begin
  if(&ClkCount) begin
   Data  <= ~(D_P_1[0] ^ Prev);
   Prev  <=   D_P_1[0];
   Stop  <=  (D_P_1[0] == D_N_1);

   case(State)
    Idle: begin
     if(~D_P_1[0] && D_N_1) begin
      Valid <= 1'b1;
      Error <= 1'b0;
      State <= Rx;
     end else begin
      Valid <= 1'b0;
     end
    end

    Rx: begin
     if(D_P_1[0] ^ Prev) begin // receiving a 0
      if(StuffCount != 3'd6) Valid <= 1'b1; // Ignore stuff bit
      StuffCount <= 0;
     end else begin // Receiving a 1
      if(StuffCount == 3'd6) Error <= 1'b1; // Bit stuff violation
      StuffCount <= StuffCount + 1'b1;
      Valid      <= 1'b1;
     end
     
     if(D_P_1[0] == D_N_1) State <= Idle;
    end

    default:;
   endcase
  end else begin
   Valid <= 1'b0;
  end
  ClkCount <= ClkCount + 1'b1;
 end

 if(Valid) begin
  if(Stop) begin
   HeaderCount <= 0;

  end else begin
   Shift <= {Data, Shift[31:1]};
   if(HeaderCount == 16'd31) begin
    PID      <=        Shift[12: 9];
    Address  <=        Shift[23:17];
    Endpoint <=        Shift[27:24];
    CRC5     <= {Data, Shift[31:28]};
   end
   HeaderCount <= HeaderCount + 1'b1;
  end
 end
end
//------------------------------------------------------------------------------

assign Output = Data 
              | Stop 
              | Valid 
              | Error 
              | &Shift 
              | &PID
              | &Address
              | &Endpoint
              | &CRC5;
endmodule
//------------------------------------------------------------------------------

