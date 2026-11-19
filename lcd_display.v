module lcd_display (
    input  wire       clk,
    input  wire       start,
    input  wire [1:0] modo,
    input  wire [2:0] opcode,
    input  wire [3:0] reg_num,
    input  wire       negativo,
    input  wire [3:0] d4,
    input  wire [3:0] d3,
    input  wire [3:0] d2,
    input  wire [3:0] d1,
    input  wire [3:0] d0,
    output wire       busy,
    output wire [7:0] lcd_data,
    output wire       lcd_rs,
    output wire       lcd_rw,
    output wire       lcd_e
);

    localparam [1:0]
        M_APAGADO  = 2'b00,
        M_INICIAL  = 2'b01,
        M_COMPLETO = 2'b10,
        M_SO_NOME  = 2'b11;

    localparam [2:0]
        OP_LOAD    = 3'b000,
        OP_ADD     = 3'b001,
        OP_ADDI    = 3'b010,
        OP_SUB     = 3'b011,
        OP_SUBI    = 3'b100,
        OP_MUL     = 3'b101,
        OP_CLEAR   = 3'b110,
        OP_DISPLAY = 3'b111;

    wire [7:0] init_data;
    wire       init_rs;
    wire       init_rw;
    wire       init_e;
    wire       init_done;

    reg        start_init;

    reg  [7:0] wr_data;
    reg        wr_rs;
    reg        wr_rw;
    reg        wr_e;

    lcd_init_hd44780 lcd_init (
        .clk      (clk),
        .rst      (1'b0),          
        .start    (start_init),
        .done     (init_done),
        .lcd_data (init_data),
        .lcd_rs   (init_rs),
        .lcd_rw   (init_rw),
        .lcd_e    (init_e)
    );

    wire controller_mode = init_done;
    assign lcd_data = (controller_mode == 1'b0) ? init_data : wr_data;
    assign lcd_rs   = (controller_mode == 1'b0) ? init_rs   : wr_rs;
    assign lcd_rw   = (controller_mode == 1'b0) ? init_rw   : wr_rw;
    assign lcd_e    = (controller_mode == 1'b0) ? init_e    : wr_e;

    localparam integer MSG_LEN = 34;

    parameter  [31:0] DELAY_WRITE = 32'd50000;
    localparam [31:0] DELAY_PULSE = 32'd50;

    localparam [2:0]
        S_WAIT_INIT = 3'd0,
        S_PREPARE   = 3'd1,
        S_PULSE_E   = 3'd2,
        S_WAIT      = 3'd3,
        S_IDLE      = 3'd4;

    reg [2:0]  state     = S_WAIT_INIT, next_state;
    reg [31:0] delay_cnt = 32'd0,       next_delay_cnt;
    reg [5:0]  msg_index = 6'd0,        next_msg_index;

    assign busy = (state != S_IDLE);

    wire is_cmd = (msg_index == 6'd0) || (msg_index == 6'd17);

    wire       linha2 = (msg_index >= 6'd18);
    wire [5:0] col_full = linha2 ? (msg_index - 6'd18) : (msg_index - 6'd1);
    wire [3:0] col = col_full[3:0];

    reg [31:0] mnem;
    reg [7:0]  mnem_char;
    reg [7:0]  msg_byte;

    always @(*) begin
        case (opcode)
            OP_LOAD:    mnem = "LOAD";
            OP_ADD:     mnem = "ADD ";
            OP_ADDI:    mnem = "ADDI";
            OP_SUB:     mnem = "SUB ";
            OP_SUBI:    mnem = "SUBI";
            OP_MUL:     mnem = "MUL ";
            OP_CLEAR:   mnem = "CLR ";
            OP_DISPLAY: mnem = "DPL ";
            default:    mnem = "    ";
        endcase

        case (col[1:0])
            2'd0:    mnem_char = mnem[31:24];
            2'd1:    mnem_char = mnem[23:16];
            2'd2:    mnem_char = mnem[15:8];
            default: mnem_char = mnem[7:0];
        endcase
    end

    always @(*) begin
        msg_byte = 8'h20;

        if (msg_index == 6'd0) begin
            msg_byte = 8'h80;
        end else if (msg_index == 6'd17) begin
            msg_byte = 8'hC0;
        end else begin
            case (modo)
                M_INICIAL: begin
                    if (!linha2) begin
                        if (col <= 4'd3)
                            msg_byte = "-";
                        else if (col == 4'd10)
                            msg_byte = "[";
                        else if (col >= 4'd11 && col <= 4'd14)
                            msg_byte = "-";
                        else if (col == 4'd15)
                            msg_byte = "]";
                    end else begin
                        if (col == 4'd10)
                            msg_byte = "+";
                        else if (col >= 4'd11)
                            msg_byte = "0";
                    end
                end

                M_COMPLETO: begin
                    if (!linha2) begin
                        if (col <= 4'd3)
                            msg_byte = mnem_char;
                        else begin
                            case (col)
                                4'd10: msg_byte = "[";
                                4'd11: msg_byte = 8'h30 + reg_num[3];
                                4'd12: msg_byte = 8'h30 + reg_num[2];
                                4'd13: msg_byte = 8'h30 + reg_num[1];
                                4'd14: msg_byte = 8'h30 + reg_num[0];
                                4'd15: msg_byte = "]";
                                default: msg_byte = 8'h20;
                            endcase
                        end
                    end else begin
                        case (col)
                            4'd10: msg_byte = negativo ? "-" : "+";
                            4'd11: msg_byte = 8'h30 + d4;
                            4'd12: msg_byte = 8'h30 + d3;
                            4'd13: msg_byte = 8'h30 + d2;
                            4'd14: msg_byte = 8'h30 + d1;
                            4'd15: msg_byte = 8'h30 + d0;
                            default: msg_byte = 8'h20;
                        endcase
                    end
                end

                M_SO_NOME: begin
                    if (!linha2 && col <= 4'd3)
                        msg_byte = mnem_char;
                end

                default: begin
                    msg_byte = 8'h20;
                end
            endcase
        end
    end

    always @(posedge clk) begin
        state     <= next_state;
        delay_cnt <= next_delay_cnt;
        msg_index <= next_msg_index;
    end

    always @(*) begin
        next_state     = state;
        next_delay_cnt = delay_cnt;
        next_msg_index = msg_index;

        case (state)
            S_WAIT_INIT: begin
                if (init_done)
                    next_state = S_IDLE;
            end

            S_IDLE: begin
                if (start) begin
                    next_state     = S_PREPARE;
                    next_msg_index = 6'd0;
                end
            end

            S_PREPARE: begin
                next_state     = S_PULSE_E;
                next_delay_cnt = DELAY_PULSE;
            end

            S_PULSE_E: begin
                if (delay_cnt > 0) begin
                    next_delay_cnt = delay_cnt - 1;
                end else begin
                    next_state     = S_WAIT;
                    next_delay_cnt = DELAY_WRITE;
                end
            end

            S_WAIT: begin
                if (delay_cnt > 0) begin
                    next_delay_cnt = delay_cnt - 1;
                end else begin
                    if (msg_index == (MSG_LEN - 1)) begin
                        next_state = S_IDLE;
                    end else begin
                        next_msg_index = msg_index + 1;
                        next_state     = S_PREPARE;
                    end
                end
            end

            default: begin
                next_state     = S_WAIT_INIT;
                next_delay_cnt = 32'd0;
                next_msg_index = 6'd0;
            end
        endcase
    end

    always @(*) begin
        start_init = (state == S_WAIT_INIT) ? 1'b1 : 1'b0;

        wr_data = 8'h00;
        wr_rs   = 1'b0;
        wr_rw   = 1'b0;
        wr_e    = 1'b0;

        case (state)
            S_PREPARE: begin
                wr_data = msg_byte;
                wr_rs   = ~is_cmd;
            end

            S_PULSE_E: begin
                wr_data = msg_byte;
                wr_rs   = ~is_cmd;
                wr_e    = 1'b1;
            end

            S_WAIT: begin
                wr_data = msg_byte;
                wr_rs   = ~is_cmd;
            end

            default: begin
            end
        endcase
    end

endmodule
