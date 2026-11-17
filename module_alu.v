module module_alu (
    input  wire [2:0]  opcode,
    input  wire [15:0] a,          // valor do reg 1
    input  wire [15:0] b,          // valor do reg 2
    input  wire        imm_sinal,  // 1 -> imediato negativo
    input  wire [5:0]  imm_mod,    // modulo do imediato
    output reg  [15:0] result
);

    wire [15:0] imm_un = {10'b0, imm_mod};
    wire [15:0] imm = imm_sinal ? (~imm_un + 16'd1) : imm_un; 

    always @ (*) begin
        
        case(opcode)
        
            3'b000: result = imm; // LOAD
            3'b001: result = a + b; // ADD
            3'b010: result = a + imm; // ADDI
            3'b011: result = a - b; // SUB
            3'b100: result = a - imm; // SUBI
            3'b101: result = a * imm; // MULT
            3'b110: result = 16'd0; // CLEAR
            3'b111: result = a; // DISPLAY
            default: result = 16'd0;
        
        endcase
    end

endmodule