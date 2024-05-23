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

    // case statement: 
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

// reg                         fifo_rden;
// reg         [63:0]          rdata, rdata_n;
// reg         [63:0]          fifo_rdata_0;
// reg         [63:0]          fifo_rdata_1;
// reg         [63:0]          fifo_rdata_2;
// reg         [63:0]          fifo_rdata_3;
// reg         [63:0]          fifo_rdata_4;
// reg         [63:0]          fifo_rdata_5;
// reg         [63:0]          fifo_rdata_6;
// reg         [63:0]          fifo_rdata_7;
// reg         [63:0]          fifo_rdata_0_n;
// reg         [63:0]          fifo_rdata_1_n;
// reg         [63:0]          fifo_rdata_2_n;
// reg         [63:0]          fifo_rdata_3_n;
// reg         [63:0]          fifo_rdata_4_n;
// reg         [63:0]          fifo_rdata_5_n;
// reg         [63:0]          fifo_rdata_6_n;
// reg         [63:0]          fifo_rdata_7_n;
// reg                         rlast;
// reg                         rvalid;
// reg                         start;
// reg         [2:0]           cnt, cnt_n;
// reg         [2:0]           ptr;
// reg         [2:0]           offset, offset_n;
// always_ff @(posedge clk) begin
//     if(!rst_n)begin
//         cnt     <= 'b0;
//         fifo_rdata_0            <= 'b0;
//         fifo_rdata_1            <= 'b0;
//         fifo_rdata_2            <= 'b0;
//         fifo_rdata_3            <= 'b0;
//         fifo_rdata_4            <= 'b0;
//         fifo_rdata_5            <= 'b0;
//         fifo_rdata_6            <= 'b0;
//         fifo_rdata_7            <= 'b0;
//         offset                  <= 'b0;
//     end
//     else begin
//         cnt     <= cnt_n;
//         fifo_rdata_0            <= fifo_rdata_0_n;
//         fifo_rdata_1            <= fifo_rdata_1_n;
//         fifo_rdata_2            <= fifo_rdata_2_n;
//         fifo_rdata_3            <= fifo_rdata_3_n;
//         fifo_rdata_4            <= fifo_rdata_4_n;
//         fifo_rdata_5            <= fifo_rdata_5_n;
//         fifo_rdata_6            <= fifo_rdata_6_n;
//         fifo_rdata_7            <= fifo_rdata_7_n;
//         offset                     <= offset_n;
//     end
// end

// always_comb begin
//     if(!fifo_empty_i) rvalid = 1;
//     else if(fifo_empty_i && !rready_i) rvalid = 0;
//     if(!fifo_empty_i &&rvalid && rready_i && (cnt==0)) fifo_rden = 1'b1;
//     else if((cnt!=0)) fifo_rden = 1'b0;
//     if(fifo_rden)begin
//         fifo_rdata_0_n          = fifo_rdata_i[63:0];
//         fifo_rdata_1_n          = fifo_rdata_i[127:64];
//         fifo_rdata_2_n          = fifo_rdata_i[191:128];
//         fifo_rdata_3_n          = fifo_rdata_i[255:192];
//         fifo_rdata_4_n          = fifo_rdata_i[319:256];
//         fifo_rdata_5_n          = fifo_rdata_i[383:320];
//         fifo_rdata_6_n          = fifo_rdata_i[447:384];
//         fifo_rdata_7_n          = fifo_rdata_i[511:448];
//         offset_n                = fifo_rdata_i[517:515];
//     end
//     else begin
//         fifo_rdata_0_n          = fifo_rdata_0;
//         fifo_rdata_1_n          = fifo_rdata_1;
//         fifo_rdata_2_n          = fifo_rdata_2;
//         fifo_rdata_3_n          = fifo_rdata_3;
//         fifo_rdata_4_n          = fifo_rdata_4;
//         fifo_rdata_5_n          = fifo_rdata_5;
//         fifo_rdata_6_n          = fifo_rdata_6;
//         fifo_rdata_7_n          = fifo_rdata_7;
//         offset_n                = offset;
//     end

//     ptr                     = (offset_n+cnt)%8;
//     if     (ptr==0) rdata = fifo_rdata_0_n;
//     else if(ptr==1) rdata = fifo_rdata_1_n;
//     else if(ptr==2) rdata = fifo_rdata_2_n;
//     else if(ptr==3) rdata = fifo_rdata_3_n;
//     else if(ptr==4) rdata = fifo_rdata_4_n;
//     else if(ptr==5) rdata = fifo_rdata_5_n;
//     else if(ptr==6) rdata = fifo_rdata_6_n;
//     else if(ptr==7) rdata = fifo_rdata_7_n;
//     if(rvalid && rready_i) start ='b1;
//     if(cnt==7) begin
//         cnt_n               = 'd0;
//         rlast             = 1'b1;
//         start               = 1'b0;
//     end
//     else if(start) begin
//         cnt_n               = cnt+1;
//         rlast               = 1'b0;

//     end
//     else begin
//         cnt_n               = cnt;
//         rlast               = 1'b0;
//     end
// end

// assign fifo_rden_o  = fifo_rden;
// assign rdata_o      = rdata;
// assign rlast_o      = rlast;
// assign rvalid_o     = rvalid;

///////////////////////////

// First attempt of code

// reg [5:0]       offset;
// reg [511:0]     data;
// reg [2:0]       burst_active;

// always @(posedge clk or negedge rst_n) begin
//     if (!rst_n) begin
//         offset <= 6'd0;
//         rdata_o <= 64'b0;
//         rlast_o <= 1'b0;
//         rvalid_o <= 1'b0;
//         burst_active <= 1'b0;
//         fifo_rden_o <= 1'b0;
//     end 
//     else begin
//         if (!fifo_empty_i && !burst_active) begin
//             // Start new burst
//             fifo_rden_o <= 1'b1;
//             data <= fifo_rdata_i[511:0];
//             offset <= fifo_rdata_i[517:512];
//             burst_active <= 1'b1;
//         end else if (burst_active) begin
//             // Continue burst
//             rvalid_o <= 1'b1;
//             case (offset)
//                 6'd0:   rdata_o <= data[63:0];
//                 6'd8:   rdata_o <= data[127:64];
//                 6'd16:  rdata_o <= data[191:128];
//                 6'd24:  rdata_o <= data[255:192];
//                 6'd32:  rdata_o <= data[319:256];
//                 6'd40:  rdata_o <= data[383:320];
//                 6'd48:  rdata_o <= data[447:384];
//                 6'd56:  rdata_o <= data[511:448];
//                 default: rdata_o <= 64'b0;
//             endcase

//             if (rvalid_o && rready_i) begin
//                 offset <= (offset + 6'd8) % 6'd64; // Increment offset by 8, wrap around at 64
//                 if (offset == 6'd0) begin
//                     if (burst_active == 3'd7) begin // 8 bursts completed (0 to 7)
//                         rlast_o <= 1'b1;
//                         burst_active <= 1'b0;
//                         fifo_rden_o <= 1'b0;
//                     end else begin
//                         burst_active <= burst_active + 1'd1; // Continue the burst
//                         rlast_o <= 1'b0;
//                     end
//                 end else begin
//                     rlast_o <= 1'b0;
//                 end
//             end

//         end else begin
//             // Idle state
//             rvalid_o <= 1'b0;
//             rlast_o <= 1'b0;
//         end
//     end
// end