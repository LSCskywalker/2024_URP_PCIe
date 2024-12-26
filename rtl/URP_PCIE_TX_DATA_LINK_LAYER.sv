module URP_TX_DATA_LINK_LAYER
(
    input   logic                   clk,               // 클럭 신호
    input   logic                   rst_n,             // 비동기 리셋 신호 (Active Low)

    // Transaction layer interface
    input   logic [223:0]           tlp_data_i,        // Transaction Layer Packet (TLP) 데이터 입력
    input   logic                   tlp_data_valid_i,  // TLP 데이터 유효 신호 (입력 유효 상태)
    output  logic                   tlp_data_ready_o,  // 송신부가 TLP 데이터를 받을 준비가 되었음을 나타냄

    // RX interface
    output  logic [267:0]           tlp_data_o,        // 송신부가 출력하는 패킷 (Sequence Number + TLP + LCRC)
    output  logic                   tlp_data_valid_o,  // 송신부의 출력 데이터가 유효함을 나타내는 신호
    input   logic                   tlp_data_ready_i,   // 수신부가 데이터를 받을 준비가 되었음을 나타내는 신호
    input   logic [31:0]            dllp_i,
    output  logic                   dllp_ready_o,
    input   logic                   dllp_valid_i  
);

    // --------------------------------
    // Internal Signals
    // --------------------------------
    logic [11:0] sequence_num;       // 12-bit Sequence Number (0~4095까지 순환)
    logic [31:0] lcrc;               // 32-bit Link CRC (패킷의 무결성을 확인하기 위한 CRC 값)
    logic [267:0] retry_buffer[0:15];// Retry Buffer (16개의 268비트 엔트리로 구성된 2차원 배열)
    logic [3:0]   retry_buffer_head; // Retry Buffer 읽기 포인터 (0~15까지 순환)
    logic [3:0]   retry_buffer_tail; // Retry Buffer 쓰기 포인터 (0~15까지 순환)
    logic         retry_buffer_empty;// Retry Buffer 비어 있는 상태 플래그
    logic         retry_buffer_full; // Retry Buffer 가득 찬 상태 플래그
    logic [267:0] packet;            // 최종 구성된 패킷 (Sequence Number + TLP + LCRC)
    logic         packet_valid;      // 패킷 유효 신호 (TLP 유효 여부 기반)
    logic [3:0]   replay_index;      // DLLP로부터 전달된 시퀀스 넘버에 해당하는 Replay Buffer 인덱스
    logic         sequence_found;    // DLLP에서 전달된 시퀀스 넘버와 일치하는 패킷 여부 플래그
    logic [11:0]  dllp_sequence;     // DLLP에서 전달받은 input의 sequence number.
    logic [223:0] tlp_data_i_reg;   //중복 방지 검사
    logic [3:0] ack_num;
    
    // --------------------------------
    // Sequence Number Logic
    // --------------------------------
    
    logic update;
    logic update_reg;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sequence_num <= 12'd4095;  // 리셋 시 Sequence Number 초기화
            tlp_data_i_reg <= 224'd0;
        end else if (tlp_data_valid_i && !(tlp_data_i == tlp_data_i_reg)) begin
            tlp_data_i_reg <= tlp_data_i;
            update <= 1;
            if (sequence_num == 12'd4095) begin
                sequence_num <= 12'd0;  // Sequence Number가 4095일 경우 0으로 롤오버
            end else begin
                sequence_num <= sequence_num + 12'd1;  // 유효한 TLP가 전송될 때 Sequence Number 증가
            end
        end else begin
                update_reg <= 0;
                tlp_data_i_reg <= tlp_data_i;
        end
    end

    // --------------------------------
    // LCRC Generation (CRC32 모듈 사용)
    // --------------------------------
    // 입력 데이터 (Sequence Number + TLP)에서 32비트 LCRC 값을 계산
    URP_PCIE_CRC32_GEN #(
        .DATA_WIDTH(236),  // 입력 데이터 폭: 236비트 (Sequence Number 12비트 + TLP 224비트)
        .CRC_WIDTH(32)     // 출력 CRC 폭: 32비트
    ) lcrc_gen (
        .data_i({sequence_num, tlp_data_i}), // CRC 계산에 사용될 데이터 (Sequence + TLP)
        .checksum_o(lcrc)                    // LCRC 출력
    );

    // --------------------------------
    // Packet Construction
    // --------------------------------
    
    logic  [267:0]  packet_reg;
    
    always_comb begin
        packet = {sequence_num, tlp_data_i, lcrc};  // 최종 패킷 구성: Sequence + TLP + LCRC
    end
    
    always_ff @(posedge clk or negedge rst_n) begin
        if(update && !(update_reg) && |packet) begin
            update_reg <= update;
            packet_reg <= packet;
        end
    end
    // --------------------------------
    // DLLP Sequence Number Extraction
    // --------------------------------
    always_comb begin
        dllp_sequence = dllp_i[11:0]; // DLLP의 시퀀스 번호 추출
    end

    // --------------------------------
    // Find Replay Buffer Index for DLLP Sequence Number
    // --------------------------------
    task automatic find_replay_index(
        input logic [11:0] seq_num,
        output logic [3:0] index,
        output logic seq_found
    );
        integer i;
        seq_found = 1'b0;
        index = 4'd0;

        for (i = 0; i < 16; i = i + 1) begin
            if (retry_buffer[i][267:256] == seq_num) begin
                index = i[3:0];
                seq_found = 1'b1;
                disable find_replay_index; // 일치하는 시퀀스 번호를 찾으면 종료
            end
        end
    endtask

    // --------------------------------
    // DLLP ACK/NAK 처리
    // --------------------------------
    
    logic dllp_valid_i_reg;
    logic [31:0] dllp_i_reg;
    logic ack_on;
    logic [4: 0] cnt_ack;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            retry_buffer_tail <= 4'd15;
            dllp_valid_i_reg <= 1'b0;
            dllp_i_reg <= 32'b0;
            cnt_ack <= 5'd0;
            ack_on <= 1;
        end 
        
        else if (!(dllp_i == dllp_i_reg)) begin
            find_replay_index(dllp_sequence, replay_index, sequence_found); // task 호출
            if (sequence_found) begin
                if (dllp_i[28] && 1'b1) begin // NAK 처리
                    retry_buffer_head <= replay_index; // NAK된 데이터로 읽기 포인터 이동 (재전송)
                    ack_on <= 0;
                    end
                end else if (!(dllp_i[28])) begin // ACK 처리
                   retry_buffer[replay_index+1] <= 268'd0; // ACK된 데이터 제거
                   ack_on <= 1;
                    if (retry_buffer_head == replay_index) begin
                        retry_buffer_head <= retry_buffer_head + 4'd1; // 읽기 포인터 이동
                end
            end
        end        
        
        
        if(ack_on) begin
            cnt_ack <= cnt_ack +1;
            if((cnt_ack >= 3) && (dllp_i == dllp_i_reg)) begin
                retry_buffer[replay_index] <= 268'd0; // ACK된 데이터 제거
                cnt_ack <= 0;
            end
        end
        
        
        
    // --------------------------------
    // DLLP 읽기 처리
    // --------------------------------
        if (tlp_data_valid_i && !retry_buffer_full && !(tlp_data_i == tlp_data_i_reg)) begin
            retry_buffer[retry_buffer_tail] <= packet_reg; // 패킷 저장
            retry_buffer_tail <= retry_buffer_tail + 4'd1;
        end
        
        
        dllp_valid_i_reg <= dllp_valid_i;
        
        dllp_i_reg <= dllp_i;
        
    end

    // --------------------------------
    // Retry Buffer Read Logic
    // --------------------------------
    
    logic [5:0] cnt_read;
    logic [267: 0] retry_buffer_reg;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            retry_buffer_head <= 4'd15;
            cnt_read <= 5'd0;
        end else if (!retry_buffer_empty) begin
            if(cnt_read >= 10) begin
                if((tlp_data_ready_i)&&(dllp_i == dllp_i_reg)) begin
                    retry_buffer_head <= retry_buffer_head + 4'd1; // 읽기 포인터를 다음 위치로 이동
                    cnt_read <= 5'd0;
                    retry_buffer_reg <= retry_buffer[retry_buffer_head];
                end
            end else if (dllp_i == dllp_i_reg) begin
                cnt_read <= cnt_read + 1;
            end
        end
    end

    // --------------------------------
    // Retry Buffer Status Flags
    // --------------------------------
    assign retry_buffer_empty = (retry_buffer_head == retry_buffer_tail);
    assign retry_buffer_full = ((retry_buffer_tail + 4'd1) == retry_buffer_head);

    // --------------------------------
    // Output Logic
    // --------------------------------
    assign tlp_data_o = retry_buffer_reg;; // 버퍼에서 읽은 데이터를 출력으로 전달
    assign tlp_data_valid_o = ((|retry_buffer[retry_buffer_head])&&(tlp_data_ready_i));       // 버퍼가 비어 있지 않으면 데이터 유효
    assign tlp_data_ready_o = !(retry_buffer_full);        // 버퍼가 가득 차지 않으면 준비 상태
    assign dllp_ready_o = 1'b1;    // DLLP 신호가 유효하고 해당 시퀀스 번호를 찾았을 때만 처리 가능

endmodule
