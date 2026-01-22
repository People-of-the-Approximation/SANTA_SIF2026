module max_tree #(
    parameter N = 8
)(
    input clk,
    input en,
    input rst,

    input [N-1:0] valid_in,
    input [N*16-1:0] in_flat,

    output valid_MAX_out,
    output [15:0] MAX,

    output [N-1:0] valid_bypass_out,
    output [N*16-1:0] in_bypass
);

    localparam STAGE = $clog2(N);

    wire [N-1:0] stage_valid [0:STAGE];
    wire [15:0] stage_data [0:STAGE][0:N-1];

    reg [N-1:0] reg_valid_bypass [0:STAGE-1];
    reg [N*16-1:0] reg_bypass [0:STAGE-1];

    integer k;
    always @(posedge clk) begin
        if (rst) begin
            for (k = 0; k <= STAGE-1; k = k + 1) begin
                reg_valid_bypass[k] <= {N{1'b0}};
                reg_bypass[k] <= {N{16'd0}};
            end
        end
        else if (en) begin
            reg_valid_bypass[0] <= valid_in;
            reg_bypass[0] <= in_flat;
            for (k = 0; k <= STAGE-2; k = k + 1) begin
                reg_valid_bypass[k+1] <= reg_valid_bypass[k];
                reg_bypass[k+1] <= reg_bypass[k];
            end
        end
    end

    assign stage_valid[0] = valid_in;

    genvar i, j;
    generate
        for (i = 0; i < N; i = i + 1) begin
            assign stage_data[0][i] = in_flat[i*16 +: 16];
        end
    endgenerate
    
    generate
        for (j = 0; j < STAGE; j = j + 1) begin : stages
            for (i = 0; i < (N >> (j+1)); i = i + 1) begin : comps
                max_comparator MAX(
                    .clk(clk),
                    .en(en),
                    .rst(rst),

                    .valid_A_in(stage_valid[j][2*i]),
                    .A_in(stage_data[j][2*i]),

                    .valid_B_in(stage_valid[j][2*i+1]),
                    .B_in(stage_data[j][2*i+1]),

                    .valid_out(stage_valid[j+1][i]),
                    .MAX_out(stage_data[j+1][i])
                );
            end
        end
    endgenerate

    assign valid_MAX_out = stage_valid[STAGE][0];
    assign MAX = stage_data[STAGE][0];

    assign valid_bypass_out = reg_valid_bypass[STAGE-1];
    assign in_bypass = reg_bypass[STAGE-1];

endmodule

module max_comparator (
    input clk,
    input en,
    input rst,

    input valid_A_in,
    input signed [15:0] A_in,

    input valid_B_in,
    input signed [15:0] B_in,

    output reg valid_out,
    output reg signed [15:0] MAX_out
);

    always @(posedge clk) begin
        if (rst) begin
            MAX_out <= 16'd0;
            valid_out <= 1'b0;
        end 
        else if (en) begin
            MAX_out <= (A_in > B_in) ? A_in : B_in;
            valid_out <= valid_A_in & valid_B_in;
        end
    end
endmodule