module bin2bcd (
    input  wire [15:0] valor,
    output wire        negativo,
    output wire [3:0]  d4,   // dezena de milhar
    output wire [3:0]  d3,   // milhar
    output wire [3:0]  d2,   // centena
    output wire [3:0]  d1,   // dezena
    output wire [3:0]  d0    // unidade
);

    // Etapa 04: sinal e módulo
    assign negativo = valor[15];
    wire [15:0] modulo = negativo ? (~valor + 16'd1) : valor;

    // Etapa 05: cinco dígitos
    assign d4 = (modulo / 16'd10000) % 16'd10;
    assign d3 = (modulo / 16'd1000)  % 16'd10;
    assign d2 = (modulo / 16'd100)   % 16'd10;
    assign d1 = (modulo / 16'd10)    % 16'd10;
    assign d0 =  modulo              % 16'd10;

endmodule