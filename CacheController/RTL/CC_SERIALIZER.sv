// Copyright (c) 2022 Sungkyunkwan University

module CC_SERIALIZER
(
    input   wire                clk,
    input   wire                rst_n,

    input   wire                fifo_empty_i,
    input   wire                fifo_aempty_i,
    input   wire    [517:0]     fifo_rdata_i,
    output  wire                fifo_rden_o,

    output  wire    [63:0]      rdata_o,
    output  wire                rlast_o,
    output  wire                rvalid_o,
    input   wire                rready_i
);

    // Fill the code here
    // FIFO data that is the input for CC_SERIALIZER 
    // = [target line offset(0~64):full cache line data] = [6b:512b] => 518b
    // ex) critical offset = 16
    //      CC_SERIALIZER output data: 16(64b)->24(64b)->32(64b)->40(64b)->48(64b)->56(64b)->0(64b)->8(64b)->... wrapping

    // if-else statement: 
    // to send the data of critical offset to rdata_o first, then wrapping burst
    // if the fifo is empty, rdata_o is 0, rlast_o is 0, rvalid_o is 0
    // if the fifo is not empty, rdata_o is the data of critical offset, rlast_o is 0, rvalid_o is 1
    // rdata_o then does wrapping burst
    // When wrapping burst ends, rlast_o is 1, rvalid_o is 1

    // increment offset by d'8, if offset is 64, set it to 0, and do wrapping burst. 
    // when 8 bursts ends, set rlast_o to 1

    reg                         fifo_rden;
    reg         [63:0]          rdata, rdata_n;
    reg         [63:0]          fifo_rdata_0, fifo_rdata_0_n;
    reg         [63:0]          fifo_rdata_1, fifo_rdata_1_n;
    reg         [63:0]          fifo_rdata_2, fifo_rdata_2_n;
    reg         [63:0]          fifo_rdata_3, fifo_rdata_3_n;
    reg         [63:0]          fifo_rdata_4, fifo_rdata_4_n;
    reg         [63:0]          fifo_rdata_5, fifo_rdata_5_n;
    reg         [63:0]          fifo_rdata_6, fifo_rdata_6_n;
    reg         [63:0]          fifo_rdata_7, fifo_rdata_7_n;
    reg                         rlast;
    reg                         rvalid;
    reg                         start;
    reg         [2:0]           cnt, cnt_n;
    reg         [2:0]           ptr;
    reg         [2:0]           offset, offset_n;
    always_ff @(posedge clk) begin
        if(!rst_n) begin
            cnt     <= 'b0;
            fifo_rdata_0            <= 'b0;
            fifo_rdata_1            <= 'b0;
            fifo_rdata_2            <= 'b0;
            fifo_rdata_3            <= 'b0;
            fifo_rdata_4            <= 'b0;
            fifo_rdata_5            <= 'b0;
            fifo_rdata_6            <= 'b0;
            fifo_rdata_7            <= 'b0;
            offset                  <= 'b0;
        end
        else begin
            cnt     <= cnt_n;
            fifo_rdata_0            <= fifo_rdata_0_n;
            fifo_rdata_1            <= fifo_rdata_1_n;
            fifo_rdata_2            <= fifo_rdata_2_n;
            fifo_rdata_3            <= fifo_rdata_3_n;
            fifo_rdata_4            <= fifo_rdata_4_n;
            fifo_rdata_5            <= fifo_rdata_5_n;
            fifo_rdata_6            <= fifo_rdata_6_n;
            fifo_rdata_7            <= fifo_rdata_7_n;
            offset                     <= offset_n;
        end
    end

    always_comb begin
        // Determine rvalid output: Serializer -> INTC
        if (!fifo_empty_i) rvalid = 1'b1;
        else if (fifo_empty_i && !rready_i) rvalid = 1'b0;

        // Determine fifo_rden: Serializer -> FIFO
        if (!fifo_empty_i && rvalid && rready_i && (cnt==0)) fifo_rden = 1'b1;
        else if ((cnt!=0)) fifo_rden = 1'b0;

        // Split 512b data to 8 x 64b buffers
        if(fifo_rden)begin
            fifo_rdata_0_n          = fifo_rdata_i[63:0];
            fifo_rdata_1_n          = fifo_rdata_i[127:64];
            fifo_rdata_2_n          = fifo_rdata_i[191:128];
            fifo_rdata_3_n          = fifo_rdata_i[255:192];
            fifo_rdata_4_n          = fifo_rdata_i[319:256];
            fifo_rdata_5_n          = fifo_rdata_i[383:320];
            fifo_rdata_6_n          = fifo_rdata_i[447:384];
            fifo_rdata_7_n          = fifo_rdata_i[511:448];
            offset_n                = fifo_rdata_i[517:515];
        end
        else begin
            fifo_rdata_0_n          = fifo_rdata_0;
            fifo_rdata_1_n          = fifo_rdata_1;
            fifo_rdata_2_n          = fifo_rdata_2;
            fifo_rdata_3_n          = fifo_rdata_3;
            fifo_rdata_4_n          = fifo_rdata_4;
            fifo_rdata_5_n          = fifo_rdata_5;
            fifo_rdata_6_n          = fifo_rdata_6;
            fifo_rdata_7_n          = fifo_rdata_7;
            offset_n                = offset;
        end

        // Determine ptr for selecting which 64b data buffer to send to rdata_o 
        // -> Serializing
        ptr                     = (offset_n+cnt)%8;
        if     (ptr==0) rdata = fifo_rdata_0_n;
        else if(ptr==1) rdata = fifo_rdata_1_n;
        else if(ptr==2) rdata = fifo_rdata_2_n;
        else if(ptr==3) rdata = fifo_rdata_3_n;
        else if(ptr==4) rdata = fifo_rdata_4_n;
        else if(ptr==5) rdata = fifo_rdata_5_n;
        else if(ptr==6) rdata = fifo_rdata_6_n;
        else if(ptr==7) rdata = fifo_rdata_7_n;

        // Determine start signal for wrapping burst (check handshake between INTC and Serializer)
        if (rvalid && rready_i) start = 1'b1;
        // Do wrapping burst
        if (cnt==7) begin
            cnt_n               = 'd0;
            rlast               = 1'b1;
            start               = 1'b0;
        end
        else if (start) begin
            cnt_n               = cnt+1;
            rlast               = 1'b0;

        end
        else begin
            cnt_n               = cnt;
            rlast               = 1'b0;
        end
    end

    assign fifo_rden_o  = fifo_rden;
    assign rdata_o      = rdata;
    assign rlast_o      = rlast;
    assign rvalid_o     = rvalid;

endmodule