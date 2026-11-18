// Testbench do bin2bcd - tabela do Roteiro 2, Etapa 06, mais uma varredura
// de todos os 65536 valores comparada com a conta de referencia.
`timescale 1ns/1ps
module tb_bin2bcd;
    reg  [15:0] valor;
    wire        negativo;
    wire [3:0]  d4, d3, d2, d1, d0;
    integer erros = 0;
    integer v, m;

    bin2bcd dut (.valor(valor), .negativo(negativo),
                 .d4(d4), .d3(d3), .d2(d2), .d1(d1), .d0(d0));

    task testa(input [15:0] x, input en, input [3:0] e4, e3, e2, e1, e0);
        begin
            valor = x; #10;
            if ({negativo, d4, d3, d2, d1, d0} !== {en, e4, e3, e2, e1, e0}) begin
                $display("ERRO: %h -> %s%0d%0d%0d%0d%0d", x, negativo ? "-" : "+", d4, d3, d2, d1, d0);
                erros = erros + 1;
            end else
                $display("ok:   %h -> %s%0d%0d%0d%0d%0d", x, negativo ? "-" : "+", d4, d3, d2, d1, d0);
        end
    endtask

    initial begin
        testa(16'd0,     0, 0,0,0,0,0);
        testa(16'd12,    0, 0,0,0,1,2);
        testa(16'd9999,  0, 0,9,9,9,9);
        testa(16'd10000, 0, 1,0,0,0,0);
        testa(16'd32767, 0, 3,2,7,6,7);
        testa(16'hFFFF,  1, 0,0,0,0,1);
        testa(16'hFFFB,  1, 0,0,0,0,5);
        testa(16'h8000,  1, 3,2,7,6,8);

        // Varredura completa
        for (v = 0; v < 65536; v = v + 1) begin
            valor = v; #1;
            m = (v >= 32768) ? (65536 - v) : v;
            if (negativo !== (v >= 32768) ||
                d4 !== (m / 10000) % 10 || d3 !== (m / 1000) % 10 ||
                d2 !== (m / 100) % 10   || d1 !== (m / 10) % 10   || d0 !== m % 10) begin
                if (erros < 10) $display("ERRO na varredura: %h", v);
                erros = erros + 1;
            end
        end

        if (erros == 0) $display("tb_bin2bcd: TODOS OS CASOS OK (inclusive os 65536 valores)");
        else            $display("tb_bin2bcd: %0d ERRO(S)", erros);
        $finish;
    end
endmodule
