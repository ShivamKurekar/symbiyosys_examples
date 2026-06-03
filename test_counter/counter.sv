module counter (
    input clk,
    input rst,
    output reg [1:0] cnt
);

always @(posedge clk) begin
    if (rst)
        cnt <= 0;
    else
        cnt <= cnt + 1;
end

`ifdef FORMAL

reg f_past_valid;

initial f_past_valid = 0;

always @(posedge clk)
begin
    f_past_valid <= 1;

    if (f_past_valid) begin

        // Check reset behavior
        if ($past(rst))
            assert(cnt == 0);

        // Check counting behavior
        if (!$past(rst))
            assert(
                (($past(cnt) != 3) && (cnt == $past(cnt)+1))
                ||
                (($past(cnt) == 3) && (cnt == 0))
            );
    end
end

`endif

endmodule