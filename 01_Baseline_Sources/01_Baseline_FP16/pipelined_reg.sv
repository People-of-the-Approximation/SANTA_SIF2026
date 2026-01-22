module pipelined_reg #(
    parameter WIDTH = 16,
    parameter DEPTH = 64,
    parameter DELAY = 20,
    parameter COUNTER_BIT=$clog2(DELAY)
)(
    input wire clk,
    input wire rst_n,
    input wire [WIDTH-1:0] x_in [0:DEPTH-1],
    input wire x_in_valid, 
    input wire next_ready,
    output wire x_delayed_ready,
    output wire x_delayed_valid, 
    output wire [WIDTH-1:0] x_delayed [0:DEPTH-1]
);

    wire data_receive;
    wire data_send;
    reg [WIDTH-1:0] x_delayed_reg [0:DEPTH-1];
    reg [COUNTER_BIT:0] counter;
    reg x_delayed_valid_reg;
    integer i;
    
    assign data_receive=x_in_valid & x_delayed_ready;
    assign data_send=x_delayed_valid & next_ready;
    
    always @(posedge clk) begin
        if(!rst_n) begin
            for(i=0; i<DEPTH; i=i+1) x_delayed_reg[i] <= 0;
        end
        else if(data_receive) begin
            for(i=0; i<DEPTH; i=i+1) x_delayed_reg[i] <= x_in[i];
        end
        else if(data_send) begin
            for(i=0; i<DEPTH; i=i+1) x_delayed_reg[i] <= 0;
        end
    end
    
    always @(posedge clk) begin
        if(!rst_n) counter <= 0;
        else if(data_receive) counter <= 1;
        else if(counter > 0 && counter < DELAY-1) counter <= counter+1;
        else if(counter == DELAY-1) counter <= 0;
    end    
    
    always @(posedge clk) begin
        if(!rst_n) x_delayed_valid_reg <= 0;
        else if(data_receive) x_delayed_valid_reg <= 1;
        else if(data_send) x_delayed_valid_reg <= 0;
    end
    
    assign x_delayed_ready = (counter == 0 && x_delayed_valid == 0);
    assign x_delayed_valid = x_delayed_valid_reg;
    genvar j;
    generate
        for (j=0; j<DEPTH; j=j+1) begin
            assign x_delayed[j] = x_delayed_reg[j];
        end
    endgenerate
endmodule