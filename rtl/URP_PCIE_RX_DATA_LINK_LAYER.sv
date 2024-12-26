module URP_PCIE_RX_DATA_LINK_LAYER (
    input   logic                   clk,
    input   logic                   rst_n,

    // TX interface     
    input   logic   [267:0]         tlp_data_i, // 입력 tlp 데이터(LCRC 포함)
    input   logic                   tlp_data_valid_i, // 입력 데이터가 유효함을 알리는 신호
    output  logic                   tlp_data_ready_o, // tlp 준비 완료 신호를 상위 계층에 알리는 신호

    output  logic   [31:0]          dllp_o, // 생성된 dllp 출력 데이터
    output  logic                   dllp_valid_o, // dllp 데이터가 유효함을 알리는 신호
    input   logic                   dllp_read_i, // dllp를 읽었다고 상위 계층에 알리는 신호

    // Transaction layer interface
    output  logic   [223:0]         tlp_data_o, // 처리된 tlp 데이터
    output  logic                   tlp_data_valid_o, // 처리된 tlp 데이터가 유효함을 알리는 신호
    input   logic                   tlp_data_ready_i // 상위 계층에서 출력 tlp 데이터를 받을 준비가 되었음을 알리는 신호
);

    // Internal signals
    logic [31:0]                lcrc_computed;      // tlp 데이터를 기반으로 계산된 LCRC값
    logic [31:0]                lcrc_received;      // 입력 tlp에 포함된 LCRC값
    logic                       lcrc_valid;         // 계산된 LCRC와 받은 LCRC 비교 결과

    logic [11:0]                sequence_number;    // 입력 tlp에서 추출된 Sequence number 
    logic [11:0]                sequence_expected;  // 다음으로 예상되는 sequence number
    logic                       nak_scheduled_flag; 
    logic                       ack_scheduled_flag;
    logic [31:0]                dllp_data_gen;      // 생성된 dllp 데이터

    // LCRC Check(URP_PCIE_CRC32_ENC 모듈 사용)
    logic lcrc_valid_o;
    logic [267:0] tlp_data_with_crc;
    logic [235:0] tlp_data_no_crc;
    logic [223:0] tlp_data_reg;
    logic valid;

    URP_PCIE_CRC32_GEN #(
        .DATA_WIDTH(236),  // 입력 데이터 폭: 236비트 (Sequence Number 12비트 + TLP 224비트)
        .CRC_WIDTH(32)     // 출력 CRC 폭: 32비트
    ) lcrc_gen (
        .data_i(tlp_data_i[267:32]), // CRC 계산에 사용될 데이터 (Sequence + TLP)
        .checksum_o(lcrc_computed)                    // LCRC 출력
    );


    /*URP_PCIE_CRC32_ENC #(
        .DATA_WIDTH(236), // TLP 데이터 크기 (268비트 중 상위 236비트만 사용)
        .CRC_WIDTH(32)
    ) lcrc_enc (
        .clk(clk),
        .rst_n(rst_n),
        .valid_i(tlp_data_valid_i),
        .data_i(tlp_data_i[267:32]), // tlp_data_i[267:32]는 LCRC 32비트를 제외한 tlp의 나머지 상위 236비트
        .valid_o(lcrc_valid_o),
        .data_o(tlp_data_no_crc),
        .checksum_o(lcrc_computed) // 계산된 LCRC값이 lcrc_computed에 저장
        // lcrc_computed는 checksum_o와 연결되어 이 값을 통해 외부 모듈로 계산된 LCRC를 전달
    );*/
    
    always_comb begin
        lcrc_valid = 1'b1;
        lcrc_received = tlp_data_i[31:0];  // 입력 tlp에서 받은 LCRC 추출
        // tlp_data_i[31:0]는 tx에서 계산되어 패킷의 끝에 포함된 값으로 rx에서는 이 값을 분리하여 재계산한 lcrc_computed와 비교
        if (lcrc_computed == lcrc_received) begin
            lcrc_valid = 1'b1; // 계산된 lcrc_computed와 추출한 lcrc_received 비교
        end else begin
            lcrc_valid = 1'b0;
        end
    end

    // Sequence Number Check
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sequence_expected <= 12'b0;  // 리셋 시 sequence number를 초기화
            ack_scheduled_flag <= 1'b0; // 리셋 시 ack flag를 초기화
            nak_scheduled_flag <= 1'b0; // 리셋 시 nak flag를 초기화
            tlp_data_reg <= 223'b0;
            valid <= 1'b0;
            dllp_data_gen <= 32'd0;
            dllp_valid_o <= 1'b0;
            sequence_number <= 12'b0;
        end else if ( tlp_data_valid_i == lcrc_valid ) begin
            sequence_number = tlp_data_i[267:256]; // 입력 tlp에서 sequence number 추출
            // 대소 비교하여(sequence_number vs sequence_expected) scheduled_flag 설정
            if (sequence_number > sequence_expected) begin
                nak_scheduled_flag <= 1'b1;  // nak 상태이므로 nak 플래그 설정
                ack_scheduled_flag <= 1'b0;  // ack 플래그는 비활성화
                valid <= 1'b0;
            end else if (sequence_number < sequence_expected) begin
                nak_scheduled_flag <= 1'b0;  // nak 플래그 비활성화
                ack_scheduled_flag <= 1'b1;  // ack 상태이므로 ack 플래그 설정
                valid <= 1'b1;
            end else if(sequence_number == sequence_expected) begin // sequence_number = sequence_expected
                //nak_scheduled_flag <= 1'b0;  // nak 플래그 비활성화
                //ack_scheduled_flag <= 1'b1;   // ack 상태이므로 ack 플래그 설정
                tlp_data_reg <= tlp_data_i[255:32];
                valid <= 1'b1;
                sequence_expected <= sequence_expected + 1; // 다음 예상값을 1 증가

            end
        end
    end
    
    
    // DLLP Generation
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dllp_data_gen <= 32'd0;
            dllp_valid_o <= 1'b0;
        end else if (tlp_data_valid_i && lcrc_valid) begin
            if (ack_scheduled_flag) begin // ack인 경우
                dllp_data_gen <= {20'b0,sequence_expected-1}; // dllp 데이터 생성
                dllp_valid_o <= 1'b1; // dllp 데이터 유효
            end else if (nak_scheduled_flag) begin // nak인 경우
                dllp_data_gen <= {3'b0, 1'b1, 16'b0, sequence_expected}; // dllp 데이터 생성
                dllp_valid_o <= 1'b1; // dllp 데이터 유효
            end else begin // ack도 nak도 아닌 경우
                dllp_valid_o <= 1'b0; // dllp 데이터 유효하지 않음
            end
        end
        
    end

    assign tlp_data_o = tlp_data_reg;  // 처리된 tlp 데이터(header와 payload) 전달
    assign tlp_data_valid_o = tlp_data_valid_i && lcrc_valid && valid; // LCRC와 sequence number 검증이 완료된 데이터만 유효 신호를 출력
    assign tlp_data_ready_o = tlp_data_ready_i; // 입력 신호를 그대로 출력 신호로 전달
    assign dllp_o = dllp_data_gen;
endmodule