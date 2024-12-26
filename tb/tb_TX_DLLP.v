`timescale 1ns / 1ps

module tb_URP_PCIE_TOP;

    // Parameters for clock generation
    parameter CLK_PERIOD = 10;
    
function automatic void extract_tlp_fields(
    input logic [223:0]  tlp_test,
    output logic [2:0]   header_fmt_o,
    output logic [4:0]   header_type_o,
    output logic [2:0]   header_tc_o,
    output logic [9:0]   header_length_o,
    output logic [15:0]  header_requestID_o,
    output logic [31:0]  addr_o,
    output logic [127:0] payload_o
);
    header_fmt_o       = tlp_test[223:221];
    header_type_o      = 5'b00000;       // Memory Request �⺻��
    header_tc_o        = tlp_test[215:213];
    header_length_o    = tlp_test[212:203];
    // tlp_test[202:192]�� zero field
    header_requestID_o = tlp_test[191:176];
    addr_o             = tlp_test[175:144];
    // tlp_test[143:128]�� zero field
    payload_o          = tlp_test[127:0];
endfunction



    // DUT (Device Under Test) Inputs
    reg                   clk;
    reg                   rst_n;
    reg   [127:0]         payload_i;
    reg   [31:0]          addr_i;
    reg   [2:0]           header_fmt_i;
    reg   [4:0]           header_type_i;
    reg   [2:0]           header_tc_i;
    reg   [9:0]           header_length_i;
    reg   [15:0]          header_requestID_i;
    reg   [15:0]          header_completID_i;

    // DUT Outputs
    wire  [127:0]         payload_o;
    wire  [31:0]          addr_o;
    wire  [2:0]           header_fmt_o;
    wire  [4:0]           header_type_o;
    wire  [2:0]           header_tc_o;
    wire  [9:0]           header_length_o;
    wire  [15:0]          header_requestID_o;
    wire  [15:0]          header_completID_o;


    // Declare integer 'i' at module level
    integer i;
    reg   [223:0]         tlp_test; // New reg for `tlp_test`


    // Instantiate the DUT
    URP_PCIE_TOP uut (
        .clk                    (clk),
        .rst_n                  (rst_n),

        // Software interface - TX
        .payload_i              (payload_i),
        .addr_i                 (addr_i),
        .header_fmt_i           (header_fmt_i),
        .header_type_i          (header_type_i),
        .header_tc_i            (header_tc_i),
        .header_length_i        (header_length_i),
        .header_requestID_i     (header_requestID_i),
        .header_completID_i     (header_completID_i),

        // Software interface - RX
        .payload_o              (payload_o),
        .addr_o                 (addr_o),
        .header_fmt_o           (header_fmt_o),
        .header_type_o          (header_type_o),
        .header_tc_o            (header_tc_o),
        .header_length_o        (header_length_o),
        .header_requestID_o     (header_requestID_o),
        .header_completID_o     (header_completID_o)
    );


    // Clock Generation
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD / 2) clk = ~clk; // 50% duty cycle clock
    end

    // Reset Generation
    initial begin
        rst_n = 1'b0;
        #(CLK_PERIOD * 2);
        rst_n = 1'b1;
    end

    // Stimulus
    initial begin
        // Wait for reset to de-assert
        @(posedge rst_n);

        // Initialize inputs
        payload_i          = 128'd0;
        addr_i             = 32'd0;
        header_fmt_i       = 3'd0;
        header_type_i      = 5'd0;
        header_tc_i        = 3'd0;
        header_length_i    = 10'd0;
        header_requestID_i = 16'd0;
        header_completID_i = 16'd0;
        tlp_test           = 224'd0;





tlp_test = 224'h20983746251094672839104827563290174582937462109874562310; // 
extract_tlp_fields(tlp_test, header_fmt_i, header_type_i, header_tc_i, header_length_i, header_requestID_i, addr_i, payload_i);
#100;
#10;

tlp_test = 224'h20472890365721093847562193847102945876432918765432198765; // 
extract_tlp_fields(tlp_test, header_fmt_i, header_type_i, header_tc_i, header_length_i, header_requestID_i, addr_i, payload_i);
#100;
#10;

tlp_test = 224'h20820365491287645903281746509827136459028376459012837645; // 
extract_tlp_fields(tlp_test, header_fmt_i, header_type_i, header_tc_i, header_length_i, header_requestID_i, addr_i, payload_i);
#100;
#10;

tlp_test = 224'h20564738291065473829105846720394871203958476213058467203; // 
extract_tlp_fields(tlp_test, header_fmt_i, header_type_i, header_tc_i, header_length_i, header_requestID_i, addr_i, payload_i);
#100;
#10       

tlp_test = 224'h26109238746592083746502983746582093746502837465209384765; // 
extract_tlp_fields(tlp_test, header_fmt_i, header_type_i, header_tc_i, header_length_i, header_requestID_i, addr_i, payload_i);
#100;
#10


tlp_test = 224'h20582093746502938746592837460582937465092837465028374650; // 
extract_tlp_fields(tlp_test, header_fmt_i, header_type_i, header_tc_i, header_length_i, header_requestID_i, addr_i, payload_i);
#100;
#10

tlp_test = 224'h20340958762103948756203948750239485720394857203948756203; // 
extract_tlp_fields(tlp_test, header_fmt_i, header_type_i, header_tc_i, header_length_i, header_requestID_i, addr_i, payload_i);
#100;
#10


tlp_test = 224'h20208394756203948750394857602394857203948756203948750394; // 
extract_tlp_fields(tlp_test, header_fmt_i, header_type_i, header_tc_i, header_length_i, header_requestID_i, addr_i, payload_i);
#100;
#10


tlp_test = 224'h20837465092837465098237465092837465092837465092837465098; // 
extract_tlp_fields(tlp_test, header_fmt_i, header_type_i, header_tc_i, header_length_i, header_requestID_i, addr_i, payload_i);
#100;
#10


tlp_test = 224'h20294857203948750293847562093847562098347560293847502938; // 
extract_tlp_fields(tlp_test, header_fmt_i, header_type_i, header_tc_i, header_length_i, header_requestID_i, addr_i, payload_i);
#100;
#10


tlp_test = 224'h20293847560293847560294857602938475602394875602394875602; // 
extract_tlp_fields(tlp_test, header_fmt_i, header_type_i, header_tc_i, header_length_i, header_requestID_i, addr_i, payload_i);
#100;
#10



tlp_test = 224'h20820394857203948750239487562394857602394875602394875620; // 
extract_tlp_fields(tlp_test, header_fmt_i, header_type_i, header_tc_i, header_length_i, header_requestID_i, addr_i, payload_i);
#100;
#10



tlp_test = 224'h20392847560294857602394857602394857620394857602394857620; // 
extract_tlp_fields(tlp_test, header_fmt_i, header_type_i, header_tc_i, header_length_i, header_requestID_i, addr_i, payload_i);
#100;
#10


tlp_test = 224'h26983746251094672839104827563290174582937462109874562310; // 
extract_tlp_fields(tlp_test, header_fmt_i, header_type_i, header_tc_i, header_length_i, header_requestID_i, addr_i, payload_i);
#100;
#10


tlp_test = 224'h20472890365721093847562193847102945876432918765432198765; // 
extract_tlp_fields(tlp_test, header_fmt_i, header_type_i, header_tc_i, header_length_i, header_requestID_i, addr_i, payload_i);
#100;
#10



tlp_test = 224'h20820365491287645903281746509827136459028376459012837645; // 
extract_tlp_fields(tlp_test, header_fmt_i, header_type_i, header_tc_i, header_length_i, header_requestID_i, addr_i, payload_i);
#100;
#10


tlp_test = 224'h20564738291065473829105846720394871203958476213058467203; // 
extract_tlp_fields(tlp_test, header_fmt_i, header_type_i, header_tc_i, header_length_i, header_requestID_i, addr_i, payload_i);
#100;
#10


tlp_test = 224'h20109238746592083746502983746582093746502837465209384765; // 
extract_tlp_fields(tlp_test, header_fmt_i, header_type_i, header_tc_i, header_length_i, header_requestID_i, addr_i, payload_i);
#100;
#10



tlp_test = 224'h20582093746502938746592837460582937465092837465028374650; // 
extract_tlp_fields(tlp_test, header_fmt_i, header_type_i, header_tc_i, header_length_i, header_requestID_i, addr_i, payload_i);
#100;
#10       


tlp_test = 224'h20340958762103948756203948750239485720394857203948756203; // 
extract_tlp_fields(tlp_test, header_fmt_i, header_type_i, header_tc_i, header_length_i, header_requestID_i, addr_i, payload_i);
#100;
#10


tlp_test = 224'h20392847560294857602394857602394857620394857602394857620; // 
extract_tlp_fields(tlp_test, header_fmt_i, header_type_i, header_tc_i, header_length_i, header_requestID_i, addr_i, payload_i);
#100;
#10


tlp_test = 224'h20564829375649283756429387564298375642983756429837564298; // 
extract_tlp_fields(tlp_test, header_fmt_i, header_type_i, header_tc_i, header_length_i, header_requestID_i, addr_i, payload_i);
#100;
#10



tlp_test = 224'h20382094875623948756029384750293847560293847502938475602; // 
extract_tlp_fields(tlp_test, header_fmt_i, header_type_i, header_tc_i, header_length_i, header_requestID_i, addr_i, payload_i);
#100;
#10


tlp_test = 224'h20520394857602394857602394857602394875602938475602938475; // 
extract_tlp_fields(tlp_test, header_fmt_i, header_type_i, header_tc_i, header_length_i, header_requestID_i, addr_i, payload_i);
#100;
#10



tlp_test = 224'h20203948756023948756203948750239847562394857620394875602; // 
extract_tlp_fields(tlp_test, header_fmt_i, header_type_i, header_tc_i, header_length_i, header_requestID_i, addr_i, payload_i);
#100;
#10


#100;



        // Finish simulation after some time
        #(CLK_PERIOD * 100);

        $stop;
    end

endmodule