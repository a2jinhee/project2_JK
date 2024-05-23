// Copyright (c) 2022 Sungkyunkwan University

module CC_TAG_COMPARATOR
(
    input   wire            clk,
    input   wire            rst_n,

    input   wire    [16:0]  tag_i,
    input   wire    [8:0]   index_i,
    input   wire    [5:0]   offset_i,
    output  wire    [16:0]  tag_delayed_o,
    output  wire    [8:0]   index_delayed_o,
    output  wire    [5:0]   offset_delayed_o,

    input   wire            hs_pulse_i,

    input   wire    [17:0]  rdata_tag_i,

    output  wire            hit_o,
    output  wire            miss_o
);

    // Fill the code here
    
    // Delay the tag, index, offset, hs_pulse by one clock cycle
    reg [16:0]  tag_delayed, tag_delayed_n;
    reg [8:0]   index_delayed, index_delayed_n;
    reg [5:0]   offset_delayed, offset_delayed_n;
    reg         hs_pulse_delayed, hs_pulse_delayed_n;

    // State machine Flip-Flop
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            tag_delayed <= 0;
            index_delayed <= 0;
            offset_delayed <= 0;
            hs_pulse_delayed <= 0;
        end
        else begin
            tag_delayed <= tag_delayed_n;
            index_delayed <= index_delayed_n;
            offset_delayed <= offset_delayed_n;
            hs_pulse_delayed <= hs_pulse_delayed_n;
        end
    end

    always_comb begin
        tag_delayed_n       = tag_i;
        index_delayed_n     = index_i;
        offset_delayed_n    = offset_i;
        hs_pulse_delayed_n  = hs_pulse_i;
        // hit                 = 1'b0;
        // miss                = 1'b0;
        // if (hs_pulse && (rdata_tag_i[16:0] == tag_delayed) && rdata_tag_i[17]) hit = 1'b1;
        // else if (hs_pulse) miss = 1'b1;
    end

    assign tag_delayed_o = tag_delayed;
    assign index_delayed_o = index_delayed;
    assign offset_delayed_o = offset_delayed;

    // Compare the tag with the tag from the SRAM
    assign hit_o    = (hs_pulse_delayed && (rdata_tag_i[16:0] == tag_delayed) && rdata_tag_i[17]) ? 1'b1 : 1'b0;
    assign miss_o   = (hs_pulse_delayed && !hit_o) ? 1'b1 : 1'b0; 

endmodule

    // reg     [16:0]      tag_delayed, tag_delayed_n;
    // reg     [8:0]       index_delayed,  index_delayed_n;
    // reg     [5:0]       offset_delayed, offset_delayed_n;
    // reg                 hs_pulse, hs_pulse_n;
    // reg                 hit;
    // reg                 miss;

    // always_ff @(posedge clk) begin
    //     if(!rst_n) begin
    //         tag_delayed     <=  17'b0;
    //         index_delayed   <=  9'b0;
    //         offset_delayed  <=  6'b0;
    //         hs_pulse        <=  1'b0;
    //     end
    //     else begin
    //         tag_delayed     <= tag_delayed_n;
    //         index_delayed   <= index_delayed_n;
    //         offset_delayed  <= offset_delayed_n;
    //         hs_pulse        <= hs_pulse_n;
    //     end
    // end
    
    // always_comb begin
    //     tag_delayed_n       = tag_i;
    //     index_delayed_n     = index_i;
    //     offset_delayed_n    = offset_i;
    //     hs_pulse_n          = hs_pulse_i;
    //     hit                 = 1'b0;
    //     miss                = 1'b0;
    //     if (hs_pulse && (rdata_tag_i[16:0] == tag_delayed) && rdata_tag_i[17]) hit = 1'b1;
    //     else if (hs_pulse) miss = 1'b1;
    // end
    
    // assign tag_delayed_o    = tag_delayed;
    // assign index_delayed_o  = index_delayed;
    // assign offset_delayed_o = offset_delayed;
    // assign hit_o            = hit;
    // assign miss_o           = miss;