module module_mini_cpu (
    input  wire        CLOCK_50,
    input  wire [3:2]  KEY,        // KEY[3] ligar/desligar, KEY[2] enviar
    input  wire [17:0] SW,
    output wire [7:0]  LCD_DATA,
    output wire        LCD_RS,
    output wire        LCD_RW,
    output wire        LCD_EN,
    output wire        LCD_ON,
    output wire        LCD_BLON
);

    wire clk = CLOCK_50;
    assign LCD_ON   = 1'b1;
    assign LCD_BLON = 1'b1;

    localparam [2:0]
        OP_LOAD    = 3'b000,
        OP_ADD     = 3'b001,
        OP_ADDI    = 3'b010,
        OP_SUB     = 3'b011,
        OP_SUBI    = 3'b100,
        OP_MUL     = 3'b101,
        OP_CLEAR   = 3'b110,
        OP_DISPLAY = 3'b111;

    localparam [1:0]
        M_APAGADO  = 2'b00,
        M_INICIAL  = 2'b01,
        M_COMPLETO = 2'b10,
        M_SO_NOME  = 2'b11;

    reg [2:0] sr_ligar  = 3'b111;
    reg [2:0] sr_enviar = 3'b111;

    always @(posedge clk) begin
        sr_ligar  <= {sr_ligar[1:0],  KEY[3]};
        sr_enviar <= {sr_enviar[1:0], KEY[2]};
    end

    wire ligar_solto  = sr_ligar[1]  & ~sr_ligar[2];
    wire enviar_solto = sr_enviar[1] & ~sr_enviar[2];

    reg  [17:0] ir       = 18'd0;
    reg  [15:0] res_reg  = 16'd0;
    reg  [1:0]  lcd_modo = M_APAGADO;
    reg         dest_off = 1'b0;

    wire [2:0] opcode  = ir[17:15];
    wire [3:0] addr_w  = ir[14:11];
    wire [3:0] reg_num = ir[14:11];
    wire [3:0] addr_a  = (opcode == OP_DISPLAY) ? ir[14:11] : ir[10:7];
    wire [3:0] addr_b  = ir[6:3];
    wire       imm_sinal = (opcode == OP_LOAD) ? ir[10]  : ir[6];
    wire [5:0] imm_mod   = (opcode == OP_LOAD) ? ir[9:4] : ir[5:0];

    reg  we;
    reg  clr;
    reg  lcd_start;

    wire [15:0] data_a;
    wire [15:0] data_b;
    wire [15:0] alu_result;
    wire        negativo;
    wire [3:0]  d4, d3, d2, d1, d0;
    wire        lcd_busy;

    memory u_mem (
        .clk     (clk),
        .clr     (clr),
        .we      (we),
        .addr_w  (addr_w),
        .data_in (res_reg),
        .addr_a  (addr_a),
        .addr_b  (addr_b),
        .data_a  (data_a),
        .data_b  (data_b)
    );

    module_alu u_alu (
        .opcode    (opcode),
        .a         (data_a),
        .b         (data_b),
        .imm_sinal (imm_sinal),
        .imm_mod   (imm_mod),
        .result    (alu_result)
    );

    bin2bcd u_bcd (
        .valor    (res_reg),
        .negativo (negativo),
        .d4       (d4),
        .d3       (d3),
        .d2       (d2),
        .d1       (d1),
        .d0       (d0)
    );

    lcd_display u_lcd (
        .clk      (clk),
        .start    (lcd_start),
        .modo     (lcd_modo),
        .opcode   (opcode),
        .reg_num  (reg_num),
        .negativo (negativo),
        .d4       (d4),
        .d3       (d3),
        .d2       (d2),
        .d1       (d1),
        .d0       (d0),
        .busy     (lcd_busy),
        .lcd_data (LCD_DATA),
        .lcd_rs   (LCD_RS),
        .lcd_rw   (LCD_RW),
        .lcd_e    (LCD_EN)
    );

    localparam [3:0]
        S_DESLIGADO = 4'd0,
        S_INI_TELA  = 4'd1,
        S_PRONTO    = 4'd2,
        S_BUSCA     = 4'd3,
        S_LEITURA   = 4'd4,
        S_EXECUCAO  = 4'd5,
        S_ESCRITA   = 4'd6,
        S_MOSTRAR   = 4'd7,
        S_DESLIGAR  = 4'd8,
        S_ESP_SOBE  = 4'd9,
        S_ESP_DESCE = 4'd10;

    reg [3:0]  state = S_DESLIGADO, next_state;
    reg [17:0] next_ir;
    reg [15:0] next_res;
    reg [1:0]  next_modo;
    reg        next_off;

    always @(posedge clk) begin
        state    <= next_state;
        ir       <= next_ir;
        res_reg  <= next_res;
        lcd_modo <= next_modo;
        dest_off <= next_off;
    end

    always @(*) begin
        next_state = state;
        next_ir    = ir;
        next_res   = res_reg;
        next_modo  = lcd_modo;
        next_off   = dest_off;

        case (state)
            S_DESLIGADO: begin
                if (ligar_solto)
                    next_state = S_INI_TELA;
            end

            S_INI_TELA: begin
                if (!lcd_busy) begin
                    next_modo  = M_INICIAL;
                    next_off   = 1'b0;
                    next_state = S_ESP_SOBE;
                end
            end

            S_PRONTO: begin
                if (enviar_solto)
                    next_state = S_BUSCA;
                else if (ligar_solto)
                    next_state = S_DESLIGAR;
            end

            S_BUSCA: begin
                next_ir    = SW;
                next_state = S_LEITURA;
            end

            S_LEITURA: begin
                next_state = S_EXECUCAO;
            end

            S_EXECUCAO: begin
                next_res   = alu_result;
                next_state = S_ESCRITA;
            end

            S_ESCRITA: begin
                next_state = S_MOSTRAR;
            end

            S_MOSTRAR: begin
                if (!lcd_busy) begin
                    next_modo  = (opcode == OP_CLEAR) ? M_SO_NOME : M_COMPLETO;
                    next_off   = 1'b0;
                    next_state = S_ESP_SOBE;
                end
            end

            S_DESLIGAR: begin
                if (!lcd_busy) begin
                    next_modo  = M_APAGADO;
                    next_off   = 1'b1;
                    next_state = S_ESP_SOBE;
                end
            end

            S_ESP_SOBE: begin
                next_state = S_ESP_DESCE;
            end

            S_ESP_DESCE: begin
                if (!lcd_busy)
                    next_state = dest_off ? S_DESLIGADO : S_PRONTO;
            end

            default: begin
                next_state = S_DESLIGADO;
            end
        endcase
    end

    always @(*) begin
        we        = 1'b0;
        clr       = 1'b0;
        lcd_start = 1'b0;

        case (state)
            S_INI_TELA: begin
                lcd_start = ~lcd_busy;
            end

            S_ESCRITA: begin
                if (opcode == OP_CLEAR)
                    clr = 1'b1;
                else if (opcode != OP_DISPLAY)
                    we = 1'b1;
            end

            S_MOSTRAR: begin
                lcd_start = ~lcd_busy;
            end

            S_DESLIGAR: begin
                lcd_start = ~lcd_busy;
                clr       = ~lcd_busy;
            end

            default: begin
            end
        endcase
    end

endmodule
