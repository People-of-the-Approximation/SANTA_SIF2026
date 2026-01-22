module stage1_log2_approx(
    input clk,
    input en,
    input rst,

    input valid_in,
    input [15:0] in_0,
    input [15:0] in_1,

    output valid_out,
    output [15:0] log_in_0,

    output [15:0] in_0_bypass,
    output [15:0] in_1_bypass
);
    reg [32:0] reg_stg_0;
    reg [36:0] reg_stg_1;
    reg [48:0] reg_stg_2;

    reg [3:0] count;
    reg [5:0] int_part;

    wire [15:0] frac_part;
    wire [15:0] result;

    always @(posedge clk) begin
        if (rst) begin
            reg_stg_0 <= 33'd0;
            reg_stg_1 <= 37'd0;
            reg_stg_2 <= 49'd0;
        end
        else if (en) begin
            reg_stg_0 <= {valid_in, in_1, in_0};
            reg_stg_1 <= {reg_stg_0[32], count, reg_stg_0[31:0]};
            reg_stg_2 <= {reg_stg_1[36], result, reg_stg_1[31:0]};
        end
    end

    always @(*) begin
        casex (reg_stg_0[15:0])
            16'b1xxx_xxxx_xxxx_xxxx: count = 4'b0000;
            16'b01xx_xxxx_xxxx_xxxx: count = 4'b0001;
            16'b001x_xxxx_xxxx_xxxx: count = 4'b0010;
            16'b0001_xxxx_xxxx_xxxx: count = 4'b0011;
            16'b0000_1xxx_xxxx_xxxx: count = 4'b0100;
            16'b0000_01xx_xxxx_xxxx: count = 4'b0101;
            16'b0000_001x_xxxx_xxxx: count = 4'b0110;
            16'b0000_0001_xxxx_xxxx: count = 4'b0111;
            16'b0000_0000_1xxx_xxxx: count = 4'b1000;
            16'b0000_0000_01xx_xxxx: count = 4'b1001;
            16'b0000_0000_001x_xxxx: count = 4'b1010;
            16'b0000_0000_0001_xxxx: count = 4'b1011;
            16'b0000_0000_0000_1xxx: count = 4'b1100;
            16'b0000_0000_0000_01xx: count = 4'b1101;
            16'b0000_0000_0000_001x: count = 4'b1110;
            16'b0000_0000_0000_0001: count = 4'b1111;
        endcase
    end

    always @(*) begin
        case (reg_stg_1[35:32])
            4'b0000: int_part = 6'b00_0101;
            4'b0001: int_part = 6'b00_0100;
            4'b0010: int_part = 6'b00_0011;
            4'b0011: int_part = 6'b00_0010;
            4'b0100: int_part = 6'b00_0001;
            4'b0101: int_part = 6'b00_0000;
            4'b0110: int_part = 6'b11_1111;
            4'b0111: int_part = 6'b11_1110;
            4'b1000: int_part = 6'b11_1101;
            4'b1001: int_part = 6'b11_1100;
            4'b1010: int_part = 6'b11_1011;
            4'b1011: int_part = 6'b11_1010;
            4'b1100: int_part = 6'b11_1001;
            4'b1101: int_part = 6'b11_1000;
            4'b1110: int_part = 6'b11_0111;
            4'b1111: int_part = 6'b11_0110;
        endcase
    end

    assign frac_part = reg_stg_1[15:0] << reg_stg_1[35:32];
    assign result = {int_part, frac_part[14:5]};

    assign valid_out = reg_stg_2[48];
    assign log_in_0 = reg_stg_2[47:32];

    assign in_1_bypass = reg_stg_2[31:16];
    assign in_0_bypass = reg_stg_2[15:0];
endmodule