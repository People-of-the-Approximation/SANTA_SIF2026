module FP16_max2( 
    input wire clk,
    input wire rst_n,

    input wire a_tvalid,
    output wire a_tready,
    input wire [15:0] a_tdata,

    input wire b_tvalid,
    output wire b_tready,
    input wire [15:0] b_tdata,

    output wire result_tvalid,
    input wire result_tready,
    output wire [15:0] max
);

    wire [7:0] result_tdata;

    reg [15:0] a;
    reg [15:0] b;
    
    FP16_comp_ge u_fp_ge00 (
        .aclk(clk),
        .aresetn(rst_n),

        .s_axis_a_tvalid(a_tvalid),
        .s_axis_a_tready(a_tready),
        .s_axis_a_tdata(a_tdata),

        .s_axis_b_tvalid(b_tvalid),
        .s_axis_b_tready(b_tready),
        .s_axis_b_tdata(b_tdata),

        .m_axis_result_tvalid(result_tvalid),
        .m_axis_result_tready(result_tready), 
        .m_axis_result_tdata(result_tdata)
    );
    
    always @(posedge clk) begin
        if (!rst_n) begin
            a <= 0;
        end
        else if (a_tvalid) begin
            a <= a_tdata;
        end
    end
    
    always @(posedge clk) begin
        if (!rst_n) begin 
            b <= 0;
        end
        else if (b_tvalid) begin 
            b <= b_tdata;
        end
    end
    
    assign max = result_tdata[0] ? a : b;

endmodule
