module Debounce #(
 parameter N = 20 // Size of the dead-time counter
)(
 input  Clk, // 50 MHz
 input  Input,
 output Output
);
//------------------------------------------------------------------------------

reg [N-1:0]Count; // 21 ms
reg        Input_1;

always @(posedge Clk) begin
 Input_1 <= Input;

 if(|Count) begin
  Count <= Count - 1'b1;

 end else begin
  if(Output ^ Input_1) begin
   Output <= Input_1;
   Count  <= {N{1'b1}};
  end
 end
end
//------------------------------------------------------------------------------

endmodule
//------------------------------------------------------------------------------

