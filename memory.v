module memory (
    input  wire        clk,
    input  wire        clr,       // pulso: zera as 16 posicoes na proxima borda
    input  wire        we,        // pulso: grava data_in em addr_w na proxima borda
    input  wire [3:0]  addr_w,
    input  wire [15:0] data_in,
    input  wire [3:0]  addr_a,    // endereco da leitura A
    input  wire [3:0]  addr_b,    // endereco da leitura B
    output wire [15:0] data_a,
    output wire [15:0] data_b
);

    // 16 palavras de 16 bits
    reg [15:0] mem [0:15];

    // Enderecos de leitura registrados (um por porta de leitura)
    reg [3:0] addr_a_q = 4'd0;
    reg [3:0] addr_b_q = 4'd0;

    integer i;

    // Todas as posicoes nascem zeradas
    initial begin
        for (i = 0; i < 16; i = i + 1)
            mem[i] = 16'd0;
    end

    // Escrita e zeramento. Prioridade: clr, depois we.
    always @(posedge clk) begin
        if (clr) begin
            for (i = 0; i < 16; i = i + 1)
                mem[i] <= 16'd0;
        end else if (we) begin
            mem[addr_w] <= data_in;
        end
    end

    // Registro dos enderecos de leitura: acontece em toda borda
    always @(posedge clk) begin
        addr_a_q <= addr_a;
        addr_b_q <= addr_b;
    end

    // Leitura usando os enderecos registrados
    assign data_a = mem[addr_a_q];
    assign data_b = mem[addr_b_q];

endmodule
