module URP_PCIE_ARBITER
#(
    N_MASTER                    = 2,
    DATA_SIZE                   = 224
)
(
    input   wire                clk,
    input   wire                rst_n,  // _n means active low

    // configuration registers
    input   wire                        src_valid_i[N_MASTER],
    output  reg                         src_ready_o[N_MASTER],
    input   wire    [DATA_SIZE-1:0]     src_data_i[N_MASTER],

    output  reg                         dst_valid_o,
    input   wire                        dst_ready_i,
    output  reg     [DATA_SIZE-1:0]     dst_data_o
);

    // Internal signals
    reg [$clog2(N_MASTER)-1:0]  current_master;
    reg                         arbiter_active;
    integer i;
    logic src_ready_o_reg[N_MASTER];
    logic dst_ready_i_prev;
    logic [1:0]round_robin;
    
    logic [DATA_SIZE-1:0]     src_data_i_reg[N_MASTER];
    
    logic [3:0] clk_cnt;
    
    // Reset and initialization
    always @(posedge clk or negedge rst_n) begin //clk is rising_edge, rst_n is falling edge
        if (!rst_n) begin //rst_n is active
            current_master <= 0;
            dst_valid_o <= 0;
            dst_data_o <= 0;
            dst_ready_i_prev <= 0;
            round_robin <= 0;
            clk_cnt <= 0;
            for (i = 0; i < N_MASTER; i = i + 1) begin
                src_ready_o_reg[i] <= 0;
                src_data_i_reg[i] <= 0;
            end
            //reset i to 0, until i is same as N_MASTER, 
        end else begin //if rst_n is not active, means clk process
            //first reset all signal but round_robin, dst_data_o
            for (i = 0; i < N_MASTER; i = i + 1) begin
                src_ready_o_reg[i] <= 0;
            end
            dst_ready_i_prev <= dst_ready_i;
            if(clk_cnt == 10) begin
                clk_cnt <= 0;
                if (dst_ready_i  && !(src_data_i_reg[round_robin] == src_data_i[round_robin])) begin //begin block if dst_ready_i=1
                    // Check current master's validity
                    src_data_i_reg[round_robin] <= src_data_i[round_robin];
                    //if (src_valid_i[round_robin]) begin //is valid data
                        dst_valid_o <= 1;
                        dst_data_o <= src_data_i[round_robin];
                        src_ready_o_reg[round_robin] <= 1;
                        if(round_robin == 2'b01) begin
                            round_robin <= 2'b0;
                        end else begin
                            round_robin <= round_robin + 1;
                        end
                    //end
                end 
            end 
            else begin
            clk_cnt <= clk_cnt +1;
            end   
        end
    end

assign src_ready_o = src_ready_o_reg;

endmodule
