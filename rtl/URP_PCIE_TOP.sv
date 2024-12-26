module URP_PCIE_TOP
(
    input                           clk,
    input                           rst_n,

    // Software interface - TX
    input   logic   [127:0]         payload_i,
    input   logic   [31:0]          addr_i,
    input   logic   [2:0]           header_fmt_i,
    input   logic   [4:0]           header_type_i,
    input   logic   [2:0]           header_tc_i,
    input   logic   [9:0]		    header_length_i,
    input   logic   [15:0]          header_requestID_i,
    input   logic   [15:0]          header_completID_i,

    // Software interface - RX
    output  logic   [127:0]         payload_o,
    output  logic   [31:0]          addr_o,
    output  logic   [2:0]           header_fmt_o,
    output  logic   [4:0]           header_type_o,
    output  logic   [2:0]           header_tc_o,
    input   logic   [9:0]		    header_length_o,
    output  logic   [15:0]          header_requestID_o,
    output  logic   [15:0]          header_completID_o
);

    //  Tx ~ RX internal signals
    logic   [267:0]                 out_TX_to_RX;
    logic                           out_TX_to_RX_valid;
    logic                           in_RX_to_TX_ready;

    logic   [31:0]                  dllp;
    logic                           dllp_valid;
    logic                           dllp_ready;

    URP_PCIE_TX                     u_tx
    (
        .clk                        (clk),
        .rst_n                      (rst_n),

        // Transaction layer interface
        .payload_i                  (payload_i),
        .addr_i                     (addr_i),
        .header_fmt_i               (header_fmt_i),
        .header_type_i              (header_type_i),
        .header_tc_i                (header_tc_i),
        .header_length_i            (header_length_i),
        .header_requestID_i         (header_requestID_i),
        .header_completID_i         (header_completID_i),

        // Data link layer interface
        .rx_tlp_data_o              (out_TX_to_RX),
        .rx_tlp_valid_o             (out_TX_to_RX_valid),
        .rx_tlp_ready_i             (in_RX_to_TX_ready),

        .dllp_i                     (dllp),
        .dllp_valid_i               (dllp_valid),
        .dllp_ready_o               (dllp_ready)
    );

    URP_PCIE_RX                     u_rx
    (
        .clk                        (clk),
        .rst_n                      (rst_n),

        // Data link layer interface 
        .rx_tlp_data_i              (out_TX_to_RX),
        .rx_tlp_valid_i             (out_TX_to_RX_valid),
        .rx_tlp_ready_o             (in_RX_to_TX_ready),

        .dllp                       (dllp),
        .dllp_valid_o               (dllp_valid),
        .dllp_read_i               (dllp_ready),

        // Transaction layer interface
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
    