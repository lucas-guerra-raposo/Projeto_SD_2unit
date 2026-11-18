// Testbench do module_alu - tabela do Roteiro 2, Etapa 03
`timescale 1ns/1ps
module tb_module_alu;
    reg  [2:0]  opcode;
    reg  [15:0] a, b;
    reg         imm_sinal;
    reg  [5:0]  imm_mod;
    wire [15:0] result;
    integer erros = 0;

    module_alu dut (.opcode(opcode), .a(a), .b(b), .imm_sinal(imm_sinal),
                    .imm_mod(imm_mod), .result(result));

    task testa(input [2:0] op, input [15:0] va, input [15:0] vb,
               input sg, input [5:0] md, input [15:0] esperado);
        begin
            opcode = op; a = va; b = vb; imm_sinal = sg; imm_mod = md;
            #10;
            if (result !== esperado) begin
                $display("ERRO: op=%b a=%0d b=%0d imm=%s%0d -> %h (esperado %h)",
                         op, $signed(va), $signed(vb), sg ? "-" : "+", md, result, esperado);
                erros = erros + 1;
            end else
                $display("ok:   op=%b a=%0d b=%0d imm=%s%0d -> %0d (%h)",
                         op, $signed(va), $signed(vb), sg ? "-" : "+", md, $signed(result), result);
        end
    endtask

    initial begin
        testa(3'b000, 16'd0,     16'd0,  0, 6'd25, 16'd25);    // LOAD +25
        testa(3'b000, 16'd0,     16'd0,  1, 6'd25, 16'hFFE7);  // LOAD -25
        testa(3'b001, 16'd10,    16'd5,  0, 6'd0,  16'd15);    // ADD 10 + 5
        testa(3'b001, 16'd32767, 16'd1,  0, 6'd0,  16'h8000);  // ADD estouro
        testa(3'b011, 16'd5,     16'd10, 0, 6'd0,  16'hFFFB);  // SUB 5 - 10
        testa(3'b010, 16'd10,    16'd0,  1, 6'd3,  16'd7);     // ADDI 10 + (-3)
        testa(3'b100, 16'd10,    16'd0,  1, 6'd3,  16'd13);    // SUBI 10 - (-3)
        testa(3'b101, 16'd12,    16'd0,  1, 6'd3,  16'hFFDC);  // MUL 12 * (-3)
        testa(3'b101, 16'd1000,  16'd0,  0, 6'd63, 16'hF618);  // MUL estouro
        testa(3'b110, 16'd1234,  16'd99, 0, 6'd5,  16'd0);     // CLEAR
        testa(3'b111, 16'd1234,  16'd99, 0, 6'd5,  16'd1234);  // DISPLAY
        testa(3'b000, 16'd0,     16'd0,  1, 6'd0,  16'd0);     // extra: -0 = 0

        if (erros == 0) $display("tb_module_alu: TODOS OS CASOS OK");
        else            $display("tb_module_alu: %0d ERRO(S)", erros);
        $finish;
    end
endmodule
