module FP16_subexp(
    input wire clk,
    input wire rst_n,
    input wire [15:0] a,
    input wire [15:0] b,
    input wire a_valid,
    input wire b_valid,
    output wire a_ready,
    output wire b_ready,
    output wire subexp_valid,
    input wire next_ready,
    output wire [15:0] subexp
);
    wire sub_valid;
    wire sub_ready;
    wire [15:0] sub;
    
    FP16_sub u_fp_sub00 (
        .aclk(clk),
        .aresetn(rst_n),
        .s_axis_a_tvalid(a_valid),
        .s_axis_a_tready(a_ready),
        .s_axis_a_tdata(a),
        .s_axis_b_tvalid(b_valid),
        .s_axis_b_tready(b_ready),
        .s_axis_b_tdata(b),
        .m_axis_result_tvalid(sub_valid),
        .m_axis_result_tready(sub_ready), 
        .m_axis_result_tdata(sub)
    );

    FP16_exp u_fp_exp00 (
        .aclk(clk),
        .aresetn(rst_n),
        .s_axis_a_tvalid(sub_valid),
        .s_axis_a_tready(sub_ready),
        .s_axis_a_tdata(sub),
        .m_axis_result_tvalid(subexp_valid),
        .m_axis_result_tready(next_ready), 
        .m_axis_result_tdata(subexp)
    );
    
endmodule
