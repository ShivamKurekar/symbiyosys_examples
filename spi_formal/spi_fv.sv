module spi_fv;

reg clk;

// combinational — reset is 1 at step 0, 0 forever after
wire reset = $initstate;

(* anyseq *) reg       start;
(* anyseq *) reg [7:0] din;
(* anyseq *) reg       miso;
(* anyseq *) reg [1:0] mode;

wire sclk, mosi, ss;
wire [2:0] state;

spi_master master (
    .clk    (clk),
    .start  (start),
    .reset  (reset),
    .din    (din),
    .mode   (mode),
    .SCLK   (sclk),
    .MISO   (miso),
    .MOSI   (mosi),
    .SS     (ss),
    .o_state(state)
);

reg past_valid;

always_ff @(posedge clk) begin
    past_valid <= (reset)? 0: 1; 
end

always @(posedge clk) begin
    if (past_valid) begin
        assume(!reset);
    end
end

always @(posedge clk) begin
    if (past_valid) begin
        assert(state != 3'd6);
        cover(state == 3'd5);
    end
end

endmodule