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
reg start_done;
logic transaction_active;

always_ff @(posedge clk or posedge reset) begin
    if (reset) past_valid <= 1'b0;
    else       past_valid <= 1'b1;
end

always_ff @(posedge clk or posedge reset) begin
    if (reset)       start_done <= 1'b0;
    else if (start)  start_done <= 1'b1;
    else if (ss)     start_done <= 1'b0;   // transaction ended, allow next start
end

assign transaction_active = start_done;

always @(posedge clk) begin
    if (past_valid) begin

        assume(!reset);

        if (reset)
            assume (start == 1'b0);    // no start during reset

        if (!reset && !start_done)
            assume (start == 1'b1);    // force start HIGH until it fires once

        if (!reset && start_done)
            assume (start == 1'b0);    // hold start LOW after pulse

        assume(miso == $past(miso));

        // if ($rose(start))
        //     assume(din != $past(din) &&  din != 0);
        // else
        //     assume(din == $past(din));

        assume(din == 8'd129);

        assume(mode == 1);
    end
end

always @(posedge clk) begin
    if (past_valid) begin
        assert(state != 3'd6);
        cover(state == 3'd5);
    end
end

reg [1:0] sample_posedge;
reg [1:0] sample_negedge;

always_ff @(posedge clk) begin
    if (past_valid) begin
        if($rose(sclk) || $fell(ss))
            sample_posedge = {mosi, miso};

        if($fell(sclk) || $fell(ss))
            sample_negedge = {mosi, miso};        
    end
end

always_ff @(posedge clk) begin
    if (past_valid) begin
        if ($fell(sclk) && (mode == 1 || mode == 2) && !ss)
            assert(sample_posedge == {mosi, miso});

        if ($rose(sclk) && (mode == 0 || mode == 3) && !ss)
            assert(sample_negedge == {mosi, miso});
    end
end



endmodule