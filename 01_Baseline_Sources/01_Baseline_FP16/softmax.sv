module softmax #(
    parameter N = 64
)(
    input wire clk,
    input wire rst_n,

    input wire [3:0]  i_length_mode,
    input wire [N*16-1:0]  x_in,
    input wire x_in_valid,
    output wire softmax_ready,

    input wire next_ready,
    output wire softmax_valid,
    output wire [N*16-1:0] softmax
);

    wire max_valid;
    wire max_ready_all;
    wire [15:0] max;

    wire [N-1:0] subexp_a_ready;
    wire [N-1:0] subexp_b_ready;
    wire subexp_a_ready_all;
    wire subexp_b_ready_all;

    wire [N-1:0] subexp_valid;
    wire [15:0] subexp [0:N-1];
    wire [N*16-1:0] subexp_flatten;
    wire subexp_valids;

    wire sum_ready_all;
    wire sum_valid;
    wire [15:0] sum;

    wire recip_ready;
    wire recip_valid;
    wire [15:0] recip;

    wire [N-1:0] mult_a_ready;
    wire [N-1:0] mult_b_ready;
    wire mult_a_ready_all;
    wire mult_b_ready_all;

    wire [N-1:0] mult_valid;
    wire [15:0] mult [0:N-1];
    wire [N*16-1:0] mult_flatten;
    wire mult_valids;

    wire [3:0] x_delayed_ready;
    wire [3:0] x_delayed_valid;
    wire [15:0] x_delayed [0:3][0:N-1];

    wire max_delay_ready_all;
    wire modified_x_in_valid;
    wire modified_x_delayed_valid0;
    wire modified_max_valid;

    wire sum_delay_ready;
    wire modified_sum_delay_ready;

    wire modified_x_delayed_valid3;
    wire modified_recip_valid;

    wire [15:0] x_lanes [0:N-1];

    genvar i;
    generate
        for (i = 0; i < N; i = i + 1) begin
            assign x_lanes[i] = x_in[i*16 +: 16];
        end
    endgenerate

    assign max_delay_ready_all = max_ready_all & x_delayed_ready[0];
    assign softmax_ready = max_delay_ready_all;
    assign modified_x_in_valid = x_in_valid & softmax_ready;

    pipelined_reg #(.WIDTH(16), .DEPTH(64), .DELAY(10)) u_pr0 (
        .clk(clk),
        .rst_n(rst_n),
        .x_in(x_lanes),
        .x_in_valid(modified_x_in_valid),
        .next_ready(subexp_a_ready_all),
        .x_delayed_ready(x_delayed_ready[0]),
        .x_delayed_valid(x_delayed_valid[0]),
        .x_delayed(x_delayed[0])
    );

    FP16_max64 u_max64 (
        .clk(clk),
        .rst_n(rst_n),
        .x(x_in),
        .x_valid(modified_x_in_valid),
        .max_ready_all(max_ready_all),
        .next_ready(subexp_b_ready_all),
        .max_valid(max_valid),
        .max(max)
    );

    assign subexp_a_ready_all = &subexp_a_ready;
    assign subexp_b_ready_all = &subexp_b_ready;
    assign modified_x_delayed_valid0 = x_delayed_valid[0] & subexp_a_ready_all;
    assign modified_max_valid = max_valid & subexp_b_ready_all;

    generate
        for (i = 0; i < N; i = i + 1) begin : G_SUBEXP
            FP16_subexp u_subexp(
                .clk(clk),
                .rst_n(rst_n),
                .a(x_delayed[0][i]),
                .b(max),
                .a_valid(modified_x_delayed_valid0),
                .b_valid(modified_max_valid),
                .a_ready(subexp_a_ready[i]),
                .b_ready(subexp_b_ready[i]),
                .next_ready(modified_sum_delay_ready),
                .subexp_valid(subexp_valid[i]),
                .subexp(subexp[i])
            );
        end
    endgenerate

    generate
        for (i = 0; i < N; i = i + 1) begin
            assign subexp_flatten[i*16 +: 16] = subexp[i];
        end
    endgenerate

    assign subexp_valids = &subexp_valid;
    assign sum_delay_ready = sum_ready_all & x_delayed_ready[1];
    assign modified_sum_delay_ready = sum_delay_ready & subexp_valids;

    wire modified_subexp_valid = subexp_valids & sum_delay_ready;

    pipelined_reg #(.WIDTH(16), .DEPTH(64), .DELAY(15)) u_pr1 (
        .clk(clk),
        .rst_n(rst_n),
        .x_in(subexp),
        .x_in_valid(modified_subexp_valid),
        .next_ready(x_delayed_ready[2]),
        .x_delayed_ready(x_delayed_ready[1]),
        .x_delayed_valid(x_delayed_valid[1]),
        .x_delayed(x_delayed[1])
    );

    pipelined_reg #(.WIDTH(16), .DEPTH(64), .DELAY(15)) u_pr2 (
        .clk(clk),
        .rst_n(rst_n),
        .x_in(x_delayed[1]),
        .x_in_valid(x_delayed_valid[1]),
        .next_ready(x_delayed_ready[3]),
        .x_delayed_ready(x_delayed_ready[2]),
        .x_delayed_valid(x_delayed_valid[2]),
        .x_delayed(x_delayed[2])
    );

    pipelined_reg #(.WIDTH(16), .DEPTH(64), .DELAY(15)) u_pr3 (
        .clk(clk),
        .rst_n(rst_n),
        .x_in(x_delayed[2]),
        .x_in_valid(x_delayed_valid[2]),
        .next_ready(mult_a_ready_all),
        .x_delayed_ready(x_delayed_ready[3]),
        .x_delayed_valid(x_delayed_valid[3]),
        .x_delayed(x_delayed[3])
    );

    FP16_add64 u_add64 (
        .clk(clk),
        .rst_n(rst_n),
        .x(subexp_flatten),
        .x_valid(modified_subexp_valid),
        .sum_ready_all(sum_ready_all),
        .next_ready(recip_ready),
        .sum_valid(sum_valid),
        .sum(sum)
    );

    FP16_recip u_recip (
        .aclk(clk),
        .aresetn(rst_n),
        .s_axis_a_tvalid(sum_valid),
        .s_axis_a_tready(recip_ready),
        .s_axis_a_tdata(sum),
        .m_axis_result_tvalid(recip_valid),
        .m_axis_result_tready(mult_b_ready_all),
        .m_axis_result_tdata(recip)
    );

    assign mult_a_ready_all = &mult_a_ready;
    assign mult_b_ready_all = &mult_b_ready;
    assign modified_x_delayed_valid3 = x_delayed_valid[3] & mult_a_ready_all;
    assign modified_recip_valid = recip_valid & mult_b_ready_all;

    generate
        for (i = 0; i < N; i = i + 1) begin : G_MULT
            FP16_mult u_mult (
                .aclk(clk),
                .aresetn(rst_n),
                .s_axis_a_tvalid(modified_x_delayed_valid3),
                .s_axis_a_tready(mult_a_ready[i]),
                .s_axis_a_tdata(x_delayed[3][i]),
                .s_axis_b_tvalid(modified_recip_valid),
                .s_axis_b_tready(mult_b_ready[i]),
                .s_axis_b_tdata(recip),
                .m_axis_result_tvalid(mult_valid[i]),
                .m_axis_result_tready(next_ready),
                .m_axis_result_tdata(mult[i])
            );
        end
    endgenerate

    generate
        for (i = 0; i < N; i = i + 1) begin
            assign mult_flatten[i*16 +: 16] = mult[i];
        end
    endgenerate

    assign mult_valids = &mult_valid;

    assign softmax_valid = mult_valids;
    assign softmax = mult_flatten;

endmodule