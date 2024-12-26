module URP_PCIE_TX_TRANSACTION_LAYER (
    input   logic                   clk,
    input   logic                   rst_n,

    input   logic   [127:0]         payload_i,
    input   logic   [31:0]          addr_i,
    input   logic   [2:0]           header_fmt_i,
    input   logic   [4:0]           header_type_i,
    input   logic   [2:0]           header_tc_i,
    input   logic   [9:0]           header_length_i,
    input   logic   [15:0]          header_requestID_i,
    input   logic   [15:0]          header_completID_i,

    output  logic   [223:0]         tlp_o,
    output  logic                   tlp_valid_o,
    input   logic                   tlp_ready_i
    
);

    // -------------------------------
    //  내부 신호
    // -------------------------------
    logic [223:0] tlp_packet_reg, tlp_packet, tlp_packet_reg_sub;   // tlp_packet을 레지스터화하여 사용
    logic packet_valid_memory;
    logic packet_valid_completion;

    logic         packet_valid;           // 패킷이 유효한지 나타내는 신호
    logic         packet_valid_d;         // packet_valid의 딜레이 버전
    logic [31:0]  fifo1_data, fifo2_data; // FIFO1과 FIFO2에서 출력되는 데이터
    logic         fifo1_valid, fifo2_valid; // FIFO1과 FIFO2 데이터 유효 신호
    logic         fifo1_rden, fifo2_rden;   // FIFO1과 FIFO2 읽기 활성화 신호
    logic [223:0] arb_data;               // Arbiter에서 선택된 데이터
    logic         arb_valid;              // Arbiter 데이터 유효 신호
    
    logic         current_fifo;            // Round Robin 방식 사용 여부 플래그
    logic         src_ready_array[2];     // Arbiter에서 보내는 FIFO 읽기 준비 신호를 저장하는 배열

    logic [2:0]   tlp_chunk_count;        // Counter for TLP chunks (0-6)
    logic [2:0]   tlp_chunk_count_read;        // Counter for TLP chunks (0-6)
    logic         store_word;             // 저장 상태 신호
    logic         read_word;              // 읽기 상태 신호.
    logic [31:0]  tlp_chunks [6:0];       // TLP divided into 7 chunks
    
    // FIFO Status Signals
    logic fifo1_full, fifo1_empty;        // FIFO1 상태: 가득 참(full), 비어 있음(empty)
    logic fifo2_full, fifo2_empty;        // FIFO2 상태: 가득 참(full), 비어 있음(empty)
    logic fifo1_wren, fifo2_wren;         // FIFO1, FIFO2 쓰기 활성화 신호
    logic [31:0] fifo1_wdata, fifo2_wdata;       // FIFO1, FIFO2로 쓰여질 데이터

    //logic fifo1_rden_ready = src_ready_array[0]; // FIFO1 제어 신호
    //logic fifo2_rden_ready = src_ready_array[1]; // FIFO2 제어 신호
    
    // -------------------------------
    // 1. Packetizer
    // -------------------------------
    always_comb begin
        // 기본 초기화
        packet_valid = 0;
        packet_valid_memory = 0;
        packet_valid_completion = 0;

        // header_type_i를 기반으로 조건문 작성
        if (header_type_i == 5'b00000 || header_type_i == 5'b00001) begin
        // Memory Request
        tlp_packet = {
            header_fmt_i,        // 3 bits
            header_type_i,       // 5 bits
            header_tc_i,         // 3 bits        VC arbitar 우선순위 체크 파트.
            header_length_i,     // 10 bits
            11'd0,               // 8 bits        header frame 참고 length 10bit이기 때문에 1bit 줄여 8비트
            header_requestID_i,  // 16 bits
            addr_i,              // 32 bits
            16'd0,               // 16 bits
            payload_i            // 128 bits
        };
            packet_valid = 1;
            packet_valid_memory = 1; // Memory Request 유효
            
        end else if (header_type_i == 5'b01010 || header_type_i == 5'b01011) begin
        // Completion Request
        tlp_packet = {
            header_fmt_i,        // 3 bits
            header_type_i,       // 5 bits
            header_tc_i,         // 3 bits        VC arbitar 우선순위 체크 파트.
            header_length_i,     // 10 bits
            11'd0,                // 8 bits        header frame 참고 length 10bit이기 때문에 1bit 줄여 8비트
            header_requestID_i,  // 16 bits
            header_completID_i,  // 16 bits
            addr_i,              // 32 bits
            payload_i            // 128 bits
        };
            packet_valid = 1;
            packet_valid_completion = 1; // Completion Request 유효
            
        end else begin
            packet_valid = 0;
            packet_valid_memory = 0;
            packet_valid_completion = 0;
        end
    end

    // tlp_packet_reg와 packet_valid_d 레지스터화
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tlp_packet_reg <= 0;
            packet_valid_d <= 0;
        end else begin
            tlp_packet_reg <= tlp_packet; // tlp_packet_reg를 여기서 할당 //////////////
            packet_valid_d <= packet_valid;
        end
    end

    // Divide 224-bit TLP into 7 chunks of 32 bits
    always_comb begin
        tlp_chunks[0] = tlp_packet_reg[223:192];
        tlp_chunks[1] = tlp_packet_reg[191:160];
        tlp_chunks[2] = tlp_packet_reg[159:128];
        tlp_chunks[3] = tlp_packet_reg[127:96];
        tlp_chunks[4] = tlp_packet_reg[95:64];
        tlp_chunks[5] = tlp_packet_reg[63:32];
        tlp_chunks[6] = tlp_packet_reg[31:0];
    end

    // -------------------------------
    // 2. Arbiter Instantiation
    // -------------------------------
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
        .dst_ready_i(tlp_ready_i),
        .dst_data_o(arb_data)
    );

    // -------------------------------
    // 3. FIFO Instantiations
    // -------------------------------
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

    // -------------------------------
    // 4. FIFO Write logic
    // -------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset 상태: 초기화
            current_fifo <= 0;
            tlp_chunk_count <= 3'd0;
            fifo1_wren <= 1'b0;
            fifo2_wren <= 1'b0;
            store_word <= 1'b0;
            tlp_packet_reg_sub <= 1'b0;
        end else begin
            if (tlp_chunk_count <= 3'd7) begin
                // packet_valid가 상승 에지일 때 저장을 시작
                if (tlp_chunk_count == 3'd0 && packet_valid && !(tlp_packet_reg == tlp_packet_reg_sub)) begin
                    tlp_packet_reg_sub <= tlp_packet_reg;
                    store_word <= 1'b1;
                end

                // 저장 중이면 계속 진행
                if (store_word) begin
                    if (!current_fifo && !fifo1_full) begin
                        fifo1_wren <= 1'b1;
                        fifo1_wdata <= tlp_chunks[tlp_chunk_count];
                    end else if (current_fifo && !fifo2_full) begin
                        fifo2_wren <= 1'b1;
                        fifo2_wdata <= tlp_chunks[tlp_chunk_count];
                    end

                    // 마지막 데이터 저장 후 상태 초기화
                    if (tlp_chunk_count == 3'd7) begin // 인덱스는 0부터 7까지
                        current_fifo <= ~current_fifo;
                        tlp_chunk_count <= 3'd0;
                        fifo1_wren <= 1'b0;
                        fifo2_wren <= 1'b0;
                        store_word <= 1'b0; // 저장 종료
                    end else begin
                        tlp_chunk_count <= tlp_chunk_count + 3'd1;
                    end
                end else begin
                    fifo1_wren <= 1'b0;
                    fifo2_wren <= 1'b0;
                end
            end else begin
                // 저장 종료 시 모든 신호 초기화
                fifo1_wren <= 1'b0;
                fifo2_wren <= 1'b0;
                store_word <= 1'b0;
            end
        end
    end

    // -------------------------------
    // 5. FIFO Read logic
    // -------------------------------
    logic [223: 0] tlp_reg1, tlp_reg2, tlp_reg_stored1, tlp_reg_stored2;
    logic [4: 0] clk_cnt1, clk_cnt2, read1, read2;
    logic fifo1_rden_ready_prev, fifo2_rden_ready_prev;
    typedef enum logic [1:0] {
    RESET_STATE = 2'b00,
    READ_STATE  = 2'b01,
    IDLE_STATE  = 2'b10
    } state_t;
    state_t state1, state2;
    
    
    //FIFO1
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset 상태: 초기화
            tlp_reg1 <= 224'b0;
            clk_cnt1 <= 0;
            read1 <= 3'd0;
            fifo1_rden_ready_prev <= 0;
            state1 <= RESET_STATE;
        end else begin

        
        case(state1)
            RESET_STATE:begin
                clk_cnt1 <= clk_cnt1 + 1;
                if(clk_cnt1 == 11) begin
                    state1 <= READ_STATE;
                end
            end
         
            READ_STATE: begin
                if (read1 < 5'd7) begin
                    if (!fifo1_empty) begin
                        fifo1_rden <= 1'b1; // FIFO1에서 읽기 활성화
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
                    tlp_reg1[31:0]   <= fifo1_data;
                    fifo1_rden <= 1'b0;
                    read1 <= 3'd0;
                    clk_cnt1 <= 5'd0;
                    state1 <= IDLE_STATE;
                end
            end
           
            
            IDLE_STATE: begin
                if(src_ready_array[0] && !fifo1_rden_ready_prev)begin
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


//FIFO2
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset 상태: 초기화
            tlp_reg2 <= 224'b0;
            clk_cnt2 <= 0;
            read2 <= 3'd0;
            fifo2_rden_ready_prev <= 0;
            state2 <= RESET_STATE;
        end else begin

        
        case(state2)
            RESET_STATE:begin
                clk_cnt2 <= clk_cnt2 + 1;
                if(clk_cnt2 == 21) begin
                    state2 <= READ_STATE;
                end
            end
         
            READ_STATE: begin
                if (read2 < 5'd7) begin
                    if (!fifo2_empty) begin
                        fifo2_rden <= 1'b1; // FIFO1에서 읽기 활성화
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
                    tlp_reg2[31:0]   <= fifo2_data;
                    fifo2_rden <= 1'b0;
                    read2 <= 3'd0;
                    clk_cnt2 <= 5'd0;
                    state2 <= IDLE_STATE;
                end
            end
                        
            IDLE_STATE: begin
                if(src_ready_array[1] && !fifo2_rden_ready_prev)begin
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


    // -------------------------------
    // 6. Output Assignments
    // -------------------------------
    assign tlp_o = arb_data;         // 선택된 TLP를 출력으로 전달
    assign tlp_valid_o = arb_valid;  // 출력의 유효 신호


endmodule
