// ---------------------------------------------------------------------------
// Testbench do sistema completo: module_mini_cpu com todos os modulos reais.
//
// A placa parte dos valores iniciais (o projeto nao tem reset) e a tela e
// lida por um modelo simples do controlador HD44780 do LCD.
//
// Cobre:
//   - os 19 passos do roteiro de teste na placa (Roteiro 5);
//   - os exemplos do PDF de especificacao (codificacao das instrucoes,
//     telas do LCD e o exemplo da secao "Registradores e Memoria");
//   - CLEAR e desligar zerando os 16 registradores;
//   - mexer nos switches sem enviar e segurar o botao de envio.
//
// Para a simulacao andar rapido, a espera por byte do lcd_display (1 ms na
// placa) e reduzida com defparam. A inicializacao do LCD roda com os tempos
// reais (cerca de 17 ms simulados).
//
// Rodar (Icarus Verilog), de dentro desta pasta:
//   iverilog -g2005 -o sim tb_module_mini_cpu.v ../module_mini_cpu.v ../memory.v \
//            ../module_alu.v ../bin2bcd.v ../lcd_display.v ../lcd_init_hd44780.v
//   vvp sim
// ---------------------------------------------------------------------------
`timescale 1ns/1ps
module tb_module_mini_cpu;
    reg         clk = 0;
    reg  [3:2]  KEY = 2'b11;        // botoes soltos (valem 0 quando apertados)
    reg  [17:0] SW  = 18'd0;
    wire [7:0]  LCD_DATA;
    wire        LCD_RS, LCD_RW, LCD_EN, LCD_ON, LCD_BLON;
    integer     erros = 0;

    module_mini_cpu dut (.CLOCK_50(clk), .KEY(KEY), .SW(SW),
                         .LCD_DATA(LCD_DATA), .LCD_RS(LCD_RS), .LCD_RW(LCD_RW),
                         .LCD_EN(LCD_EN), .LCD_ON(LCD_ON), .LCD_BLON(LCD_BLON));

    defparam dut.u_lcd.DELAY_WRITE = 100;

    always #10 clk = ~clk;          // 50 MHz

    // -----------------------------------------------------------------------
    // Modelo do HD44780: registra o byte na descida do Enable
    // -----------------------------------------------------------------------
    reg [7:0] ddram [0:127];
    reg [6:0] ac;
    integer   k;

    initial begin
        for (k = 0; k < 128; k = k + 1) ddram[k] = " ";
        ac = 0;
    end

    always @(negedge LCD_EN) begin
        if ($time > 0 && !LCD_RW) begin
            if (LCD_RS) begin
                ddram[ac] = LCD_DATA;                       // caractere
                ac = ac + 1;
            end else if (LCD_DATA[7]) begin
                ac = LCD_DATA[6:0];                         // posiciona o cursor
            end else if (LCD_DATA == 8'h01) begin
                for (k = 0; k < 128; k = k + 1) ddram[k] = " ";
                ac = 0;                                     // limpa a tela
            end
        end
    end

    // -----------------------------------------------------------------------
    // Codificacao das instrucoes (tabela de formato do Roteiro 0)
    // -----------------------------------------------------------------------
    function [17:0] rr;   // ADD, SUB
        input [2:0] op; input [3:0] d, o1, o2;
        rr = {op, d, o1, o2, 3'b000};
    endfunction
    function [17:0] ri;   // ADDI, SUBI, MUL
        input [2:0] op; input [3:0] d, o1; input sg; input [5:0] md;
        ri = {op, d, o1, sg, md};
    endfunction
    function [17:0] ld;   // LOAD
        input [3:0] d; input sg; input [5:0] md;
        ld = {3'b000, d, sg, md, 4'b0000};
    endfunction
    function [17:0] dpl;  // DISPLAY
        input [3:0] r;
        dpl = {3'b111, r, 11'd0};
    endfunction
    localparam [17:0] CLR = {3'b110, 15'd0};

    // -----------------------------------------------------------------------
    // Acoes e conferencias
    // -----------------------------------------------------------------------
    task soltar(input integer b);   // aperta, segura e solta o botao b
        begin
            KEY[b] = 1'b0;
            repeat (20) @(posedge clk);
            KEY[b] = 1'b1;
            repeat (20000) @(posedge clk);
        end
    endtask

    task executa(input [17:0] instr);
        begin
            SW = instr;
            repeat (5) @(posedge clk);
            soltar(2);                // KEY[2] = enviar
        end
    endtask

    task confere(input [8*12-1:0] nome, input [8*16-1:0] l1, input [8*16-1:0] l2);
        reg [8*16-1:0] t1, t2;
        integer c;
        begin
            for (c = 0; c < 16; c = c + 1) begin
                t1[8*(15-c) +: 8] = ddram[c];
                t2[8*(15-c) +: 8] = ddram[64 + c];
            end
            if (t1 === l1 && t2 === l2)
                $display("%s ok    |%s|  |%s|", nome, t1, t2);
            else begin
                $display("%s ERRO  |%s|  |%s|   esperado |%s|  |%s|", nome, t1, t2, l1, l2);
                erros = erros + 1;
            end
        end
    endtask

    task confere_reg(input [3:0] r, input [15:0] esperado);
        begin
            if (dut.u_mem.mem[r] !== esperado) begin
                $display("  ERRO: R%0d = %h (esperado %h)", r, dut.u_mem.mem[r], esperado);
                erros = erros + 1;
            end
        end
    endtask

    task confere_tudo_zero(input [8*20-1:0] quando);
        integer r, nz;
        begin
            nz = 0;
            for (r = 0; r < 16; r = r + 1)
                if (dut.u_mem.mem[r] !== 16'd0) nz = nz + 1;
            if (nz == 0) $display("  ok: 16 registradores zerados %s", quando);
            else begin
                $display("  ERRO: %0d registrador(es) diferente(s) de zero %s", nz, quando);
                erros = erros + 1;
            end
        end
    endtask

    localparam [8*16-1:0] VAZIO = "                ";

    initial begin
        // ------------------------------------------------------------------
        // Codificacao: exemplos do PDF
        // ------------------------------------------------------------------
        $display("== Codificacao das instrucoes (exemplos do PDF) ==");
        if (rr(3'b001, 4'd6, 4'd7, 4'd8) !== 18'b001_0110_0111_1000_000) begin
            $display("  ERRO: ADD R6, R7, R8"); erros = erros + 1;
        end else $display("  ok: ADD R6, R7, R8 -> 001_0110_0111_1000 em SW17..SW3");
        if (dpl(4'd2) !== {7'b111_0010, 11'd0}) begin
            $display("  ERRO: DISPLAY 02"); erros = erros + 1;
        end else $display("  ok: DISPLAY 02 -> 111_0010 em SW17..SW11");

        // ------------------------------------------------------------------
        // Roteiro 5: 19 passos (a placa acabou de ser gravada, sem reset)
        // ------------------------------------------------------------------
        $display("== Roteiro 5 ==");
        repeat (900_000) @(posedge clk);                    // inicializacao do LCD
        confere("Passo  1   ", VAZIO, VAZIO);              // comeca desligado e apagado
        if (dut.state !== 4'd0) begin
            $display("  ERRO: estado inicial %0d (esperado desligado)", dut.state); erros = erros + 1;
        end
        soltar(2);
        confere("Passo  2   ", VAZIO, VAZIO);              // enviar com sistema desligado
        soltar(3);
        confere("Passo  3   ", "----      [----]", "          +00000");

        executa(ld(4'd2, 1'b0, 6'd12));
        confere("Passo  4   ", "LOAD      [0010]", "          +00012");
        executa(rr(3'b001, 4'd1, 4'd0, 4'd2));
        confere("Passo  5   ", "ADD       [0001]", "          +00012");   // foto do PDF
        executa(ri(3'b010, 4'd1, 4'd0, 1'b0, 6'd12));
        confere("Passo  6   ", "ADDI      [0001]", "          +00012");   // foto do PDF
        executa(dpl(4'd2));
        confere("Passo  7   ", "DPL       [0010]", "          +00012");   // foto do PDF
        executa(ri(3'b100, 4'd3, 4'd2, 1'b0, 6'd5));
        confere("Passo  8   ", "SUBI      [0011]", "          +00007");
        executa(rr(3'b011, 4'd5, 4'd3, 4'd2));
        confere("Passo  9   ", "SUB       [0101]", "          -00005");
        executa(ri(3'b101, 4'd4, 4'd2, 1'b1, 6'd3));
        confere("Passo 10   ", "MUL       [0100]", "          -00036");
        executa(ld(4'd15, 1'b1, 6'd63));
        confere("Passo 11   ", "LOAD      [1111]", "          -00063");
        executa(ri(3'b101, 4'd6, 4'd15, 1'b0, 6'd63));
        confere("Passo 12   ", "MUL       [0110]", "          -03969");
        executa(ri(3'b101, 4'd7, 4'd6, 1'b0, 6'd63));
        confere("Passo 13   ", "MUL       [0111]", "          +12097");   // estouro cortado em 16 bits

        // Banco de registradores depois dos passos 4 a 13
        confere_reg(4'd1, 16'd12);   confere_reg(4'd2, 16'd12);
        confere_reg(4'd3, 16'd7);    confere_reg(4'd4, -16'sd36);
        confere_reg(4'd5, -16'sd5);  confere_reg(4'd6, -16'sd3969);
        confere_reg(4'd7, 16'd12097); confere_reg(4'd15, -16'sd63);
        confere_reg(4'd0, 16'd0);
        $display("  conferido o banco de registradores apos o passo 13");

        executa(CLR);
        confere("Passo 14   ", "CLR             ", VAZIO);               // so o nome
        confere_tudo_zero("apos CLEAR");
        executa(dpl(4'd2));
        confere("Passo 15   ", "DPL       [0010]", "          +00000");
        executa(ld(4'd2, 1'b0, 6'd12));
        confere("Passo 16   ", "LOAD      [0010]", "          +00012");
        soltar(3);
        confere("Passo 17   ", VAZIO, VAZIO);                            // desligar apaga
        confere_tudo_zero("apos desligar");
        soltar(3);
        confere("Passo 18   ", "----      [----]", "          +00000");
        executa(dpl(4'd2));
        confere("Passo 19   ", "DPL       [0010]", "          +00000");

        // ------------------------------------------------------------------
        // Extras do Roteiro 5
        // ------------------------------------------------------------------
        $display("== Testes extras ==");
        SW = ld(4'd9, 1'b0, 6'd33);                         // mexe sem enviar
        repeat (20000) @(posedge clk);
        confere("Switches   ", "DPL       [0010]", "          +00000");
        KEY[2] = 1'b0;                                      // segura enviar
        repeat (20000) @(posedge clk);
        confere("Segurando  ", "DPL       [0010]", "          +00000");
        KEY[2] = 1'b1;                                      // solta: executa
        repeat (20000) @(posedge clk);
        confere("Soltando   ", "LOAD      [1001]", "          +00033");

        // ------------------------------------------------------------------
        // Exemplo da secao "Registradores e Memoria" do PDF
        // ------------------------------------------------------------------
        $display("== Exemplo de memoria do PDF ==");
        soltar(3); soltar(3);                               // desliga e religa (memoria zerada)
        executa(ld(4'd1, 1'b0, 6'd10));                     // LOAD R1, 10
        confere("LOAD R1,10 ", "LOAD      [0001]", "          +00010");
        confere_reg(4'd1, 16'b0000_0000_0000_1010);
        executa(ri(3'b010, 4'd2, 4'd1, 1'b0, 6'd5));        // ADDI R2, R1, 5
        confere("ADDI R2,R1,5", "ADDI      [0010]", "          +00015");
        confere_reg(4'd1, 16'b0000_0000_0000_1010);
        confere_reg(4'd2, 16'b0000_0000_0000_1111);
        $display("  conferidos R1 = 0000 0000 0000 1010 e R2 = 0000 0000 0000 1111");

        if (erros == 0) $display("tb_module_mini_cpu: TODOS OS TESTES OK");
        else            $display("tb_module_mini_cpu: %0d ERRO(S)", erros);
        $finish;
    end
endmodule
