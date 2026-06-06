module spi_fv;

reg clk;
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
    if (reset) past_valid <= 1'b0;
    else       past_valid <= 1'b1;
end

// start_done: tracks active transaction via SS
reg start_done;
always_ff @(posedge clk) begin
    if (reset)          start_done <= 1'b0;
    else if ($fell(ss)) start_done <= 1'b1;  // SS asserted → in flight
    else if ($rose(ss)) start_done <= 1'b0;  // SS deasserted → done
end

// on the first SCLK edge of a transaction (SCLK idles low for mode 0/3,
// so first event is a rise; sample_negedge would be uninitialized without this)
reg sclk_fell_seen;
always_ff @(posedge clk) begin
    if (reset)                    sclk_fell_seen <= 1'b0;
    else if ($fell(sclk) && !ss)  sclk_fell_seen <= 1'b1;
    else if ($rose(ss))           sclk_fell_seen <= 1'b0;
end

reg sclk_rose_seen;
always_ff @(posedge clk) begin
    if (reset)                    sclk_rose_seen <= 1'b0;
    else if ($rose(sclk) && !ss)  sclk_rose_seen <= 1'b1;
    else if ($rose(ss))           sclk_rose_seen <= 1'b0;
end

// Input Constraints
always_ff @(posedge clk) begin
    if (past_valid) begin
        if (start_done || $past(start))
            assume ($stable(mode));
    end
end

always_ff @(posedge clk) begin
    if (past_valid) begin

        assume (!reset);

        // start illegal while transaction in flight
        if (!ss)
            assume (start == 1'b0);

        // single-cycle pulse
        if ($past(start))
            assume (start == 1'b0);

        // one idle cycle required after SS deasserts (CS recovery time)
        if ($rose(ss))
            assume (start == 1'b1);

        // lock din and miso stable during transaction
        if (start_done) begin
            assume ($stable(din));
            assume ($stable(miso));
        end

    end
end

always_ff @(posedge clk) begin
    if (past_valid) begin
        assert (state != 3'd6);
        cover  (state == 3'd4);
    end
end

reg [1:0] sample_posedge_r;
reg [1:0] sample_negedge_r;

always_ff @(posedge clk) begin
    if (past_valid) begin
        if ($rose(sclk) || $fell(ss))
            sample_posedge_r <= {mosi, miso};

        if ($fell(sclk) || $fell(ss))
            sample_negedge_r <= {mosi, miso};
    end
end

// Stability Assertions
always_ff @(posedge clk) begin
    if (past_valid) begin

        // Mode 1/2 (CPHA=1): sample on falling SCLK
        if ($fell(sclk) && (mode == 2'd1 || mode == 2'd2) && !ss && sclk_rose_seen)
            assert (sample_posedge_r == {mosi, miso});

        // Mode 0/3 (CPHA=0): sample on rising SCLK
        if ($rose(sclk) && (mode == 2'd0 || mode == 2'd3) && !ss && sclk_fell_seen)
            assert (sample_negedge_r == {mosi, miso});

    end
end

endmodule