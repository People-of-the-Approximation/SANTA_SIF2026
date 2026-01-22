module FP16_add64(
    input wire clk,
    input wire rst_n,
    input wire [64*16-1:0] x,
    input wire x_valid,
    output wire sum_ready_all, 
    input wire next_ready,
    output wire sum_valid, 
    output wire [15:0] sum
    );
    
    wire [63:0] level0_ready;
    
    wire level0_valid[0:31], level1_ready[0:31];
    wire [15:0] level0_sum [0:31];
    wire level1_valid[0:15], level2_ready[0:15];
    wire [15:0] level1_sum [0:15];
    wire level2_valid[0:7], level3_ready[0:7];
    wire [15:0] level2_sum [0:7];
    wire level3_valid[0:3], level4_ready[0:3];
    wire [15:0] level3_sum [0:3];
    wire level4_valid[0:1], level5_ready[0:1];
    wire [15:0] level4_sum [0:1];

    assign sum_ready_all=&level0_ready;
    
    genvar i;
    generate 
        for(i=0;i<32;i=i+1) begin: u_level0
            FP16_add2 u_level0 (
                .aclk(clk),        
                .aresetn(rst_n),                       
                .s_axis_a_tvalid(x_valid),            
                .s_axis_a_tready(level0_ready[i]),           
                .s_axis_a_tdata(x[i*16 +: 16]),              
                .s_axis_b_tvalid(x_valid),          
                .s_axis_b_tready(level0_ready[i+32]),           
                .s_axis_b_tdata(x[(i+32)*16 +: 16]),           
                .m_axis_result_tvalid(level0_valid[i]),  
                .m_axis_result_tready(level1_ready[i]),
                .m_axis_result_tdata(level0_sum[i]) 
            );
        end
    endgenerate
    
    generate 
        for(i=0;i<16;i=i+1) begin: u_level1
            FP16_add2 u_level1 (
                .aclk(clk),          
                .aresetn(rst_n),                     
                .s_axis_a_tvalid(level0_valid[i]),            
                .s_axis_a_tready(level1_ready[i]),           
                .s_axis_a_tdata(level0_sum[i]),              
                .s_axis_b_tvalid(level0_valid[i+16]),          
                .s_axis_b_tready(level1_ready[i+16]),           
                .s_axis_b_tdata(level0_sum[i+16]),           
                .m_axis_result_tvalid(level1_valid[i]),  
                .m_axis_result_tready(level2_ready[i]),
                .m_axis_result_tdata(level1_sum[i]) 
            );
        end
    endgenerate
 
    generate 
        for(i=0;i<8;i=i+1) begin: u_level2
            FP16_add2 u_level2 (
                .aclk(clk),       
                .aresetn(rst_n),                        
                .s_axis_a_tvalid(level1_valid[i]),            
                .s_axis_a_tready(level2_ready[i]),           
                .s_axis_a_tdata(level1_sum[i]),              
                .s_axis_b_tvalid(level1_valid[i+8]),          
                .s_axis_b_tready(level2_ready[i+8]),           
                .s_axis_b_tdata(level1_sum[i+8]),           
                .m_axis_result_tvalid(level2_valid[i]),  
                .m_axis_result_tready(level3_ready[i]),
                .m_axis_result_tdata(level2_sum[i]) 
            );
        end
    endgenerate 
    
    generate 
        for(i=0;i<4;i=i+1) begin: u_level3
            FP16_add2 u_level3 (
                .aclk(clk),       
                .aresetn(rst_n),                        
                .s_axis_a_tvalid(level2_valid[i]),            
                .s_axis_a_tready(level3_ready[i]),           
                .s_axis_a_tdata(level2_sum[i]),              
                .s_axis_b_tvalid(level2_valid[i+4]),          
                .s_axis_b_tready(level3_ready[i+4]),           
                .s_axis_b_tdata(level2_sum[i+4]),           
                .m_axis_result_tvalid(level3_valid[i]),  
                .m_axis_result_tready(level4_ready[i]),
                .m_axis_result_tdata(level3_sum[i]) 
            );
        end
    endgenerate 
    
    generate 
        for(i=0;i<2;i=i+1) begin: u_level4
            FP16_add2 u_level4 (
                .aclk(clk),    
                .aresetn(rst_n),                           
                .s_axis_a_tvalid(level3_valid[i]),            
                .s_axis_a_tready(level4_ready[i]),           
                .s_axis_a_tdata(level3_sum[i]),              
                .s_axis_b_tvalid(level3_valid[i+2]),          
                .s_axis_b_tready(level4_ready[i+2]),           
                .s_axis_b_tdata(level3_sum[i+2]),           
                .m_axis_result_tvalid(level4_valid[i]),  
                .m_axis_result_tready(level5_ready[i]),
                .m_axis_result_tdata(level4_sum[i]) 
            );
        end
    endgenerate  
    
    FP16_add2 u_level5 (
        .aclk(clk),     
        .aresetn(rst_n),                           
        .s_axis_a_tvalid(level4_valid[0]),            
        .s_axis_a_tready(level5_ready[0]),           
        .s_axis_a_tdata(level4_sum[0]),              
        .s_axis_b_tvalid(level4_valid[1]),          
        .s_axis_b_tready(level5_ready[1]),           
        .s_axis_b_tdata(level4_sum[1]),           
        .m_axis_result_tvalid(sum_valid),  
        .m_axis_result_tready(next_ready),
        .m_axis_result_tdata(sum) 
    );  
endmodule
