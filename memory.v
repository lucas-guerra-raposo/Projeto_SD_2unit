module memory (
    input  wire        clk,
    input  wire        rst,       // zera as 16 posicoes, assincrono
    input  wire        clr,       // pulso: zera as 16 posicoes na proxima borda
    input  wire        we,        // pulso: grava data_in em addr_w na proxima borda
    input  wire [3:0]  addr_w,
    input  wire [15:0] data_in,
    input  wire [3:0]  addr_a,    // endereco da leitura A
    input  wire [3:0]  addr_b,    // endereco da leitura B
    output wire [15:0] data_a,
    output wire [15:0] data_b
);

