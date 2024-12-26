module URP_PCIE_CRC32_ENC
#(
    parameter   DATA_WIDTH              = 512,
    parameter   CRC_WIDTH               = 32
)
(
    input   wire                        clk,
    input   wire                        rst_n,

    input   wire                        valid_i,
    input   wire    [DATA_WIDTH-1:0]    data_i,

    output  logic                       valid_o,
    output  logic   [DATA_WIDTH-1:0]    data_o,
    output  logic   [CRC_WIDTH-1:0]     checksum_o
);

    logic           [CRC_WIDTH-1:0]     checksum,       checksum_n;

    // Module for generate CRC checksum.
    URP_PCIE_CRC32_GEN                           u_crc_gen_enc
    (
        .data_i                         (data_i),
        .checksum_o                     (checksum_n)
    );

    always_ff @(posedge clk)
        if (!rst_n) begin
            valid_o                     <= 1'b0;
            checksum                    <= {$bits(checksum_o){1'bx}};
        end
        else begin
            valid_o                     <= valid_i;
            checksum                    <= checksum_n;
        end

    assign  data_o                      = data_i;
    assign  checksum_o                  = checksum;

endmodule