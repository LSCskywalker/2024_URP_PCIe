module URP_PCIE_TX
(
    input   logic                   clk,
    input   logic                   rst_n,

    // Transaction layer interface
    input   logic   [127:0]         payload_i,
    input   logic   [31:0]          addr_i,
    input   logic   [2:0]           header_fmt_i,
    input   logic   [4:0]           header_type_i,
    input   logic   [2:0]           header_tc_i,
    input   logic   [9:0]           header_length_i,
    input   logic   [15:0]          header_requestID_i,
    input   logic   [15:0]          header_completID_i,
    
    
    // Data link layer interface 
    output  logic   [267:0]         rx_tlp_data_o,
    output  logic                   rx_tlp_valid_o,
    output  logic                   rx_tlp_ready_i,

    input   logic   [31:0]          dllp_i,
    input   logic                   dllp_valid_i,
    output  logic                   dllp_ready_o
);

    logic   [223:0]                 out_data_trans;
    logic                           out_valid_trans;
    logic                           in_ready_trans;

    URP_PCIE_TX_TRANSACTION_LAYER        u_trans_layer
    (
        .clk                        (clk),
        .rst_n                      (rst_n),

        .payload_i                  (payload_i),
        .addr_i                     (addr_i),
        .header_fmt_i               (header_fmt_i),
        .header_type_i              (header_type_i),
        .header_tc_i                (header_tc_i),
        .header_length_i            (header_length_i),
        .header_requestID_i         (header_requestID_i),
        .header_completID_i         (header_completID_i),

        // Data link layer interface
        .tlp_o                      (out_data_trans),
        .tlp_valid_o                (out_valid_trans),
        .tlp_ready_i                (in_ready_trans)
        
    );

    URP_TX_DATA_LINK_LAYER          u_dll_layer
    (
        .clk                        (clk),
        .rst_n                      (rst_n),

        // Transaction layer interface
        .tlp_data_i                 (out_data_trans),
        .tlp_data_valid_i           (out_valid_trans),
        .tlp_data_ready_o           (in_ready_trans),

        // RX interface
        .tlp_data_o                 (rx_tlp_data_o),
        .tlp_data_valid_o           (rx_tlp_valid_o),
        .tlp_data_ready_i           (rx_tlp_ready_i),
        .dllp_i                     (dllp_i),
        .dllp_ready_o               (dllp_ready_o),
        .dllp_valid_i               (dllp_valid_i)
    );

endmodule