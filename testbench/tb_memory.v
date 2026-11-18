// Testbench do memory - passos do Roteiro 1, Etapa 04 (versao sem reset:
// o passo 1 confere os valores iniciais)
`timescale 1ns/1ps
module tb_memory;
    reg         clk = 0;
    reg         clr = 0, we = 0;
    reg  [3:0]  addr_w = 0, addr_a = 0, addr_b = 0;
    reg  [15:0] data_in = 0;
    wire [15:0] data_a, data_b;
    integer erros = 0;

    memory dut (.clk(clk), .clr(clr), .we(we), .addr_w(addr_w),
                .data_in(data_in), .addr_a(addr_a), .addr_b(addr_b),
                .data_a(data_a), .data_b(data_b));

    always #10 clk = ~clk;

    task escreve(input [3:0] ad, input [15:0] v);
        begin
            @(negedge clk); addr_w = ad; data_in = v; we = 1;
            @(negedge clk); we = 0;
        end
    endtask

    // apresenta os enderecos, espera uma borda e compara
    task le(input [3:0] aa, input [3:0] ab, input [15:0] ea, input [15:0] eb, input integer passo);
        begin
            @(negedge clk); addr_a = aa; addr_b = ab;
            @(negedge clk);
            if (data_a !== ea || data_b !== eb) begin
                $display("Passo %0d ERRO: A[%0d]=%h (esperado %h)  B[%0d]=%h (esperado %h)",
                         passo, aa, data_a, ea, ab, data_b, eb);
                erros = erros + 1;
            end else
                $display("Passo %0d ok: A[%0d]=%h  B[%0d]=%h", passo, aa, data_a, ab, data_b);
        end
    endtask

    initial begin
        // 1) valores iniciais: leitura de 0, 7 e 15
        le(4'd0, 4'd7, 16'h0000, 16'h0000, 1);
        le(4'd15, 4'd15, 16'h0000, 16'h0000, 1);
        // 2) escreve 10 no endereco 1
        escreve(4'd1, 16'd10);
        le(4'd1, 4'd0, 16'd10, 16'd0, 2);
        // 3) escreve -5 no endereco 15; le 1 em A e 15 em B
        escreve(4'd15, 16'hFFFB);
        le(4'd1, 4'd15, 16'd10, 16'hFFFB, 3);
        // 4) muda data_in com we = 0: nada muda
        @(negedge clk); addr_w = 4'd1; data_in = 16'h1234;
        repeat (3) @(negedge clk);
        le(4'd1, 4'd15, 16'd10, 16'hFFFB, 4);
        // 5) pulso de clr
        @(negedge clk); clr = 1; @(negedge clk); clr = 0;
        le(4'd1, 4'd15, 16'h0000, 16'h0000, 5);
        // 6) clr e we no mesmo ciclo: vale o clr
        @(negedge clk); addr_w = 4'd3; data_in = 16'd99; we = 1; clr = 1;
        @(negedge clk); we = 0; clr = 0;
        le(4'd3, 4'd0, 16'h0000, 16'h0000, 6);

        if (erros == 0) $display("tb_memory: TODOS OS PASSOS OK");
        else            $display("tb_memory: %0d ERRO(S)", erros);
        $finish;
    end
endmodule
