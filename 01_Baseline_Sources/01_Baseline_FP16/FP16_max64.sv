module FP16_max64(
    input wire clk,
    input wire rst_n,
    input wire [64*16-1:0] x,
    input wire x_valid, 
    output wire max_ready_all,
    input wire next_ready,
    output wire max_valid, 
    output wire [15:0] max
    );

    wire [63:0] level0_ready;
    
    wire level0_valid[0:31], level1_ready[0:31];
    wire [15:0] level0_max [0:31];
    wire level1_valid[0:15], level2_ready[0:15];
    wire [15:0] level1_max [0:15];
    wire level2_valid[0:7], level3_ready[0:7];
    wire [15:0] level2_max [0:7];
    wire level3_valid[0:3], level4_ready[0:3];
    wire [15:0] level3_max [0:3];
    wire level4_valid[0:1], level5_ready[0:1];
    wire [15:0] level4_max [0:1];
    
    assign max_ready_all=&level0_ready;
    
    genvar i;
    generate 
        for(i=0;i<32;i=i+1) begin: u_level0
            FP16_max2 u_level0 (
                .clk(clk),
                .rst_n(rst_n),
                .a_tdata(x[i*16 +: 16]),
                .b_tdata(x[(i+32)*16 +: 16]),
                .a_tvalid(x_valid),
                .b_tvalid(x_valid), 
                .a_tready(level0_ready[i]), 
                .b_tready(level0_ready[i+32]),
                .result_tvalid(level0_valid[i]),
                .result_tready(level1_ready[i]), 
                .max(level0_max[i])
            );
        end
    endgenerate
    
    generate 
        for(i=0;i<16;i=i+1) begin: u_level1
            FP16_max2 u_level1 (
                .clk(clk),
                .rst_n(rst_n),
                .a_tdata(level0_max[i]),
                .b_tdata(level0_max[i+16]),
                .a_tvalid(level0_valid[i]),
                .b_tvalid(level0_valid[i+16]), 
                .a_tready(level1_ready[i]), 
                .b_tready(level1_ready[i+16]),
                .result_tvalid(level1_valid[i]),
                .result_tready(level2_ready[i]), 
                .max(level1_max[i])
            );
        end
    endgenerate
 
    generate 
        for(i=0;i<8;i=i+1) begin: u_level2
            FP16_max2 u_level2 (
                .clk(clk),
                .rst_n(rst_n),
                .a_tdata(level1_max[i]),
                .b_tdata(level1_max[i+8]),
                .a_tvalid(level1_valid[i]),
                .b_tvalid(level1_valid[i+8]), 
                .a_tready(level2_ready[i]), 
                .b_tready(level2_ready[i+8]),
                .result_tvalid(level2_valid[i]),
                .result_tready(level3_ready[i]), 
                .max(level2_max[i])
            );
        end
    endgenerate 
    
    generate 
        for(i=0;i<4;i=i+1) begin: u_level3
            FP16_max2 u_level3 (
                .clk(clk),
                .rst_n(rst_n),
                .a_tdata(level2_max[i]),
                .b_tdata(level2_max[i+4]),
                .a_tvalid(level2_valid[i]),
                .b_tvalid(level2_valid[i+4]), 
                .a_tready(level3_ready[i]), 
                .b_tready(level3_ready[i+4]),
                .result_tvalid(level3_valid[i]),
                .result_tready(level4_ready[i]), 
                .max(level3_max[i])
            );
        end
    endgenerate 
    
    generate 
        for(i=0;i<2;i=i+1) begin: u_level4
            FP16_max2 u_level4 (
                .clk(clk),
                .rst_n(rst_n),
                .a_tdata(level3_max[i]),
                .b_tdata(level3_max[i+2]),
                .a_tvalid(level3_valid[i]),
                .b_tvalid(level3_valid[i+2]), 
                .a_tready(level4_ready[i]), 
                .b_tready(level4_ready[i+2]),
                .result_tvalid(level4_valid[i]),
                .result_tready(level5_ready[i]), 
                .max(level4_max[i])
            );
        end
    endgenerate  
    
    FP16_max2 u_level5 (
        .clk(clk),
        .rst_n(rst_n),
        .a_tdata(level4_max[0]),
        .b_tdata(level4_max[1]),
        .a_tvalid(level4_valid[0]),
        .b_tvalid(level4_valid[1]), 
        .a_tready(level5_ready[0]), 
        .b_tready(level5_ready[1]),
        .result_tvalid(max_valid),
        .result_tready(next_ready), 
        .max(max)
    );  
endmodule
