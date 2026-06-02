module tb_counter;

reg clk;
reg rst = 1;

wire [1:0] cnt;

counter dut(
    .clk(clk),
    .rst(rst),
    .cnt(cnt)
);

always @(posedge clk)
    rst <= 0;

always @(posedge clk)
    assert(cnt != 4);

endmodule