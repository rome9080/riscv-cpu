module alu(
  input  [31:0] a, b,
  input  [3:0]  op,
  output reg [31:0] result,
  output zero
  //these are my two inputs, one ouput and selector bit and my flag bit
);
  always @(*) begin
    case (op)
      4'b0000: result = a + b;
      4'b0001: result = a - b;
      4'b0010: result = a & b;
      4'b0011: result = a | b;
      4'b0100: result = a ^ b;
      4'b0101: result = a << b[4:0];
      4'b0110: result = a >> b[4:0];
      4'b0111: result = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;
      default: result = 32'd0;
      //the meaning behind each selector value is defined here
    endcase
  end
  assign zero = (result == 32'd0);
  //zero flag that is one when result is all zeros
endmodule