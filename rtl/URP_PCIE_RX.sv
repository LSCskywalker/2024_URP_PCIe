module URP_PCIE_RX ( 
    input   logic                   clk,
    input   logic                   rst_n,
 
    // Data link layer interface
    input   logic   [267:0]         rx_tlp_data_i,
    input   logic                   rx_tlp_valid_i,
    output  logic                   rx_tlp_ready_o,

    output  logic   [31:0]          dllp,
    output  logic                   dllp_valid_o,
    input   logic                   dllp_read_i,

    // Transaction layer interface
    output  logic   [127:0]         payload_o,
    output  logic   [31:0]          addr_o,
    output  logic   [2:0]           header_fmt_o,
    output  logic   [4:0]           header_type_o,
    output  logic   [2:0]           header_tc_o,
    output  logic   [9:0]		    header_length_o,
    output  logic   [15:0]          header_requestID_o,
    output  logic   [15:0]          header_completID_o
);

    logic   [223:0]                 out_data_dll;
    logic                           out_valid_dll;
    logic                           in_ready_dll;

    URP_PCIE_RX_DATA_LINK_LAYER     u_rx_dll_layer
    (
        .clk                        (clk),
        .rst_n                      (rst_n),

        // TX interface
        .tlp_data_i                 (rx_tlp_data_i),
        .tlp_data_valid_i           (rx_tlp_valid_i),
        .tlp_data_ready_o           (rx_tlp_ready_o),

        .dllp_o                     (dllp),
        .dllp_valid_o               (dllp_valid_o),
        .dllp_read_i                (dllp_read_i),

        // Transaction layer interface
        .tlp_data_o                 (out_data_dll),
        .tlp_data_valid_o           (out_valid_dll),
        .tlp_data_ready_i           (in_ready_dll)
    );

    URP_PCIE_RX_TRANSACTION_LAYER   u_rx_trans_layer
    (
        .clk                        (clk),
        .rst_n                      (rst_n),

        // Data link layer interface 
        .tlp_data_i                 (out_data_dll),
        .tlp_data_valid_i           (out_valid_dll),
        .tlp_data_ready_o           (in_ready_dll),
        
        .payload_o                  (payload_o),
        .addr_o                     (addr_o),
        .header_fmt_o               (header_fmt_o),
        .header_type_o              (header_type_o),
        .header_tc_o                (header_tc_o),
        .header_length_o            (header_length_o),
        .header_requestID_o         (header_requestID_o),
        .header_completID_o         (header_completID_o)                   
    );

endmodule