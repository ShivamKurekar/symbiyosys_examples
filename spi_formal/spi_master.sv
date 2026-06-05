// spi_master.sv

module spi_master (
    input        clk,
    input        start,
    input        reset,
    input  [7:0] din,
    input  [1:0] mode,
    
    output reg   SCLK,
    input        MISO,
    output reg   MOSI,
    output reg   SS,

    output [2:0] o_state
);

/*
SPI MODE
mode[1] = CPOL  -> Clock polarity
mode[0] = CPHA  -> Clock phase
Mode | CPOL | CPHA
-------------------
  0  |  0   |  0
  1  |  0   |  1
  2  |  1   |  0
  3  |  1   |  1
*/

reg [2:0] state;
assign o_state = state;

parameter S0 = 0,   // Idle state
          S1 = 1,   // Load data and enable slave
          S2 = 2,   // Generate leading edge of SCLK
          S3 = 3,   // Generate trailing edge of SCLK
          S4 = 4,   // End transaction and release SS
          S5 = 5,   // Reset/default initialization
          S6 = 6;   // to test the cover statement

reg [7:0] memory;   // Shift register for SPI transfer
reg [2:0] count;    // Counts transmitted bits

always @(posedge clk)
begin

    if (reset == 1) begin
        state <= S5;
        SCLK <= 0;
        MOSI <= 0;
        SS <= 1;
        
    end else begin
        case (state)

            S0 :
            begin
                // Wait for transfer request
                if (start == 1)
                    state <= S1;
                else
                    state <= S0;

                MOSI  = 1'b0; // High impedance when idle
                count = 0;
            end

            S1 :
            begin
                state <= S2;

                // Load parallel input data
                memory = din;

                // Send first bit
                MOSI = memory[0];

                // Enable slave (active low)
                SS = 0;
            end

            S2 :
            begin
                state <= S3;

                // Generate leading edge depending on CPOL
                if (mode[1] == 0)
                    SCLK = 1;
                else
                    SCLK = 0;
                
                if (mode[0] == 0) // CPHA = 0 Sample incoming MISO data
                    memory = {MISO, memory[7:1]};
                else // CPHA = 1 Drive outgoing MOSI data
                    MOSI = memory[0];
            end

            S3 :
            begin

                // Check if 8 bits transferred
                if (count == 7)
                    state <= S4;
                else
                begin
                    state <= S2;
                    count <= count + 1;
                end

                // Generate trailing edge depending on CPOL
                if (mode[1] == 1)
                    SCLK = 1;
                else
                    SCLK = 0;

                if (mode[0] == 1) // CPHA = 1 Sample incoming MISO data
                    memory = {MISO, memory[7:1]};
                else // CPHA = 0 Drive outgoing MOSI data
                    MOSI = memory[0];

            end

            S4 :
            begin
                state <= S0;

                // Disable slave
                SS = 1;

                // Release MOSI line
                MOSI = 1'b0;
            end

            S5 :
            begin
                state <= S0;

                // Set idle clock polarity
                if (mode[1] == 0)
                    SCLK = 0;
                else
                    SCLK = 1;

                MOSI  = 1'b0;
                SS    = 1;
                count = 0;
            end

            default :
                state <= S0;

        endcase
    end
end


// `ifdef FORMAL
//     always@(*)
//         cover(state != 8);
// `endif

endmodule