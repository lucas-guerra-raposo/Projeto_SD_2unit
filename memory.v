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

reg [15:0] ram [15:0];
// declaracao da memoria RAM

// registrador para armazenar o endereço de leitura
reg [3:0] addr_a_reg;
reg [3:0] addr_b_reg;  // 2^4 = 16 posicoes de memoria

//inicializacao da memoria
initial begin 
    ram[0] <= 16'd0;
    ram[1] <= 16'd0;
    ram[2] <= 16'd0;
    ram[3] <= 16'd0;
    ram[4] <= 16'd0;
    ram[5] <= 16'd0;
    ram[6] <= 16'd0;
    ram[7] <= 16'd0;
    ram[8] <= 16'd0;
    ram[9] <= 16'd0;
    ram[10] <= 16'd0;
    ram[11] <= 16'd0;
    ram[12] <= 16'd0;
    ram[13] <= 16'd0;
    ram[14] <= 16'd0;
    ram[15] <= 16'd0;
end

always @(posedge clk) begin
    // escrita na memoria
    if (we)
        ram[addr_w] <= data_in;

    addr_a_reg <= addr_a;
    addr_b_reg <= addr_b;
end

// leitura assincrona com base no endereco registrado
assign data_a = ram[addr_a_reg];
assign data_b = ram[addr_b_reg];

endmodule


