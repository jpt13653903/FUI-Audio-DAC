module Repeater(
 input  Clk, // 50 MHz
 input  Input,
 output Output
);
//------------------------------------------------------------------------------

reg [25:0]Count;
reg       Gate;
//------------------------------------------------------------------------------

always @(posedge Clk) begin
 Output <= Input & Gate;
    
 if(~Input) begin
  Gate  <= 1'b1;
  Count <= 26'd_49_999_999;

 end else if(|Count) begin
  Count <= Count - 1'b1;

 end else begin
  Gate  <= ~Gate;
  Count <= 26'd_499_999; // Once key-press every 20 ms
 end
end
//------------------------------------------------------------------------------

endmodule
//------------------------------------------------------------------------------

