module URP_PCIE_RX_TRANSACTION_LAYER (
    input   logic                   clk,
    input   logic                   rst_n,
    
    // Data link layer interface
    input   logic   [223:0]         tlp_data_i,
    input   logic                   tlp_data_valid_i,
    output  logic                   tlp_data_ready_o,
    
    output  logic   [127:0]         payload_o,
    output  logic   [31:0]          addr_o,
    output  logic   [2:0]           header_fmt_o,
    output  logic   [4:0]           header_type_o,
    output  logic   [2:0]           header_tc_o,
    output  logic   [9:0]		    header_length_o,
    output  logic   [15:0]          header_requestID_o,
    output  logic   [15:0]          header_completID_o
); 
    logic [223:0] tlp_packet, tlp_packet_sub;
    
    //arbiter
    logic         arb_valid;
    logic src_ready_array[2];
    logic fifo1_full, fifo1_empty; 
    logic fifo2_full, fifo2_empty;
    logic [223: 0] tlp_reg1, tlp_reg2, tlp_reg_stored1, tlp_reg_stored2;

    URP_PCIE_ARBITER #(
        .N_MASTER(2),
        .DATA_SIZE(224)
    ) arbiter (
        .clk(clk),
        .rst_n(rst_n),

        // Inputs from FIFOs
        .src_valid_i({!fifo1_empty, !fifo2_empty}),
        .src_ready_o(src_ready_array),
        .src_data_i({tlp_reg_stored1, tlp_reg_stored2}),

        // Outputs to downstream logic
        .dst_valid_o(arb_valid),
        .dst_ready_i(tlp_data_valid_i),
        .dst_data_o(tlp_packet)
    );

    
    //fifo ins//
    logic [31:0]  fifo1_data, fifo2_data;
    logic         fifo1_valid, fifo2_valid;
    logic         fifo1_rden, fifo2_rden;

    logic fifo1_wren, fifo2_wren;
    logic [31:0] fifo1_wdata, fifo2_wdata;

    
    URP_PCIE_FIFO #(
        .DEPTH_LG2(4),
        .DATA_WIDTH(32)
    ) fifo1 (
        .clk(clk),
        .rst_n(rst_n),
        .wren_i(fifo1_wren),
        .wdata_i(fifo1_wdata),
        .full_o(fifo1_full),
        .empty_o(fifo1_empty),
        .rden_i(fifo1_rden),
        .rdata_o(fifo1_data)
    );

    URP_PCIE_FIFO #(
        .DEPTH_LG2(4),
        .DATA_WIDTH(32)
    ) fifo2 (
        .clk(clk),
        .rst_n(rst_n),
        .wren_i(fifo2_wren),
        .wdata_i(fifo2_wdata),
        .full_o(fifo2_full),
        .empty_o(fifo2_empty),
        .rden_i(fifo2_rden),
        .rdata_o(fifo2_data)
    );
   
    
    //fifo write logic//
    logic         current_fifo;
    logic [2:0]   tlp_chunk_count;
    logic         store_word;
    
    logic [31:0]  tlp_chunks [6:0];
    always_comb begin
        tlp_chunks[0] = tlp_data_i[223:192];
        tlp_chunks[1] = tlp_data_i[191:160];
        tlp_chunks[2] = tlp_data_i[159:128];
        tlp_chunks[3] = tlp_data_i[127:96];
        tlp_chunks[4] = tlp_data_i[95:64];
        tlp_chunks[5] = tlp_data_i[63:32];
        tlp_chunks[6] = tlp_data_i[31:0];
    end
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_fifo <= 0;
            tlp_chunk_count <= 3'd0;
            fifo1_wren <= 1'b0;
            fifo2_wren <= 1'b0;
            store_word <= 1'b0;
            tlp_packet_sub <= 1'b0;
        end else begin
            if (tlp_chunk_count <= 3'd7) begin
                if (tlp_chunk_count == 3'd0 && tlp_data_valid_i && !(tlp_data_i == tlp_packet_sub)) begin
                    tlp_packet_sub <= tlp_data_i;
                    store_word <= 1'b1;
                end
            
                if (store_word) begin
                    if (!current_fifo && !fifo1_full) begin
                        fifo1_wren <= 1'b1;
                        fifo1_wdata <= tlp_chunks[tlp_chunk_count];
                    end else if (current_fifo && !fifo2_full) begin
                        fifo2_wren <= 1'b1;
                        fifo2_wdata <= tlp_chunks[tlp_chunk_count];
                    end
                
                    if (tlp_chunk_count == 3'd7) begin
                       current_fifo <= ~current_fifo;
                       tlp_chunk_count <= 3'd0;
                       fifo1_wren <= 1'b0;
                       fifo2_wren <= 1'b0;
                       store_word <= 1'b0;
                    end else begin
                        tlp_chunk_count <= tlp_chunk_count + 3'd1;
                    end
                end else begin
                    fifo1_wren <= 1'b0;
                    fifo2_wren <= 1'b0;
                end
            end else begin
                fifo1_wren <= 1'b0;
                fifo2_wren <= 1'b0;
                store_word <= 1'b0;
            end 
        end
    end
       
 
    //fifo read logic//
    logic [4: 0] clk_cnt1, clk_cnt2, read1, read2;
    logic fifo1_rden_ready_prev, fifo2_rden_ready_prev;

    
    typedef enum logic [1:0] {
    RESET_STATE = 2'b00,
    READ_STATE  = 2'b01,
    IDLE_STATE  = 2'b10
    } state_t;
    state_t state1, state2;
    
    //fifo1//
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tlp_reg1 <= 224'b0;
            clk_cnt1 <= 0;
            read1 <= 3'd0;
            fifo1_rden_ready_prev <= 0;
            state1 <= RESET_STATE;
        end else begin
        
        case(state1)
            RESET_STATE:begin
                clk_cnt1 <= clk_cnt1 + 1;
                if (clk_cnt1 == 11) begin
                    state1 <= READ_STATE;
                end
            end
            
            READ_STATE : begin
                if (read1 < 5'd7) begin
                    if (!fifo1_empty) begin
                        fifo1_rden <= 1'b1;
                        case (read1)
                            3'd1: tlp_reg1[223:192] <= fifo1_data;
                            3'd2: tlp_reg1[191:160] <= fifo1_data;
                            3'd3: tlp_reg1[159:128] <= fifo1_data;
                            3'd4: tlp_reg1[127:96]  <= fifo1_data;
                            3'd5: tlp_reg1[95:64]   <= fifo1_data;
                            3'd6: tlp_reg1[63:32]   <= fifo1_data;
                        endcase
                        read1 <= read1 + 3'd1;
                    end
                end else begin
                    tlp_reg1[31:0] <= fifo1_data;
                    fifo1_rden <= 1'b0;
                    read1 <= 3'd0;
                    clk_cnt1 <= 5'd0;
                    state1 <= IDLE_STATE;
                end
            end
            
            IDLE_STATE: begin
                if(src_ready_array[0] && !fifo1_rden_ready_prev) begin
                    state1 <= READ_STATE;
                end
                else begin
                    tlp_reg_stored1 <= tlp_reg1;
                end
                fifo1_rden_ready_prev <= src_ready_array[0];
                end
            endcase
        end
    end
              
              
    //fifo2 read
        always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tlp_reg2 <= 224'b0;
            clk_cnt2 <= 0;
            read2 <= 3'd0;
            fifo2_rden_ready_prev <= 0;
            state2 <= RESET_STATE;
        end else begin
        
        case(state2)
            RESET_STATE:begin
                clk_cnt2 <= clk_cnt2 + 1;
                if (clk_cnt2 == 21) begin
                    state2 <= READ_STATE;
                end
            end
            
            READ_STATE : begin
                if (read2 < 5'd7) begin
                    if (!fifo2_empty) begin
                        fifo2_rden <= 1'b1;
                        case (read2)
                            3'd1: tlp_reg2[223:192] <= fifo2_data;
                            3'd2: tlp_reg2[191:160] <= fifo2_data;
                            3'd3: tlp_reg2[159:128] <= fifo2_data;
                            3'd4: tlp_reg2[127:96]  <= fifo2_data;
                            3'd5: tlp_reg2[95:64]   <= fifo2_data;
                            3'd6: tlp_reg2[63:32]   <= fifo2_data;
                        endcase
                        read2 <= read2 + 3'd1;
                    end
                end else begin
                    tlp_reg2[31:0] <= fifo2_data;
                    fifo2_rden <= 1'b0;
                    read2 <= 3'd0;
                    clk_cnt2 <= 5'd0;
                    state2 <= IDLE_STATE;
                end
            end
            
            IDLE_STATE: begin
                if(src_ready_array[1] && !fifo2_rden_ready_prev) begin
                    state2 <= READ_STATE;
                end
                else begin
                    tlp_reg_stored2 <= tlp_reg2;
                end
                fifo2_rden_ready_prev <= src_ready_array[1];
                end
            endcase
        end
    end
    
    
         
    //-----------------------------------------
    // 4. Depacketizer
    //-----------------------------------------
    always_comb begin
    
    // �ʱ�ȭ
    header_fmt_o         = 3'b0;
    header_type_o        = 5'b0;
    header_tc_o          = 3'b0;
    header_length_o      = 10'b0;
    header_requestID_o   = 16'b0;
    header_completID_o   = 16'b0;
    addr_o               = 32'b0;
    payload_o            = 128'b0;
    tlp_data_ready_o     = 0;

    if (tlp_packet[220:216] == 5'b00000 || tlp_packet[220:216] == 5'b00001) begin
    //Memory request
        header_fmt_o         = tlp_packet[223:221];
        header_type_o        = tlp_packet[220:216];
        header_tc_o          = tlp_packet[215:213];
        header_length_o      = tlp_packet[212:203];
        header_requestID_o   = tlp_packet[191:176];
        header_completID_o   = tlp_packet[175:160];
        addr_o               = tlp_packet[175:144];
        payload_o            = tlp_packet[127:0];
        tlp_data_ready_o     = 1;
    
    end else if (tlp_packet[220:216] == 5'b01010 || tlp_packet[220:216] == 5'b01011) begin
        header_fmt_o         = tlp_packet[223:221];
        header_type_o        = tlp_packet[220:216];
        header_tc_o          = tlp_packet[215:213];
        header_length_o      = tlp_packet[212:203];
        header_requestID_o   = tlp_packet[191:176];
        header_completID_o   = tlp_packet[175:160];
        addr_o               = tlp_packet[159:128];
        payload_o            = tlp_packet[127:0];
        tlp_data_ready_o     = 1;
    end 

end

endmodule