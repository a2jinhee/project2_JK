// Copyright (c) 2022 Sungkyunkwan University

module CC_DATA_REORDER_UNIT
(
    input   wire            clk,
    input   wire            rst_n,

    // AMBA AXI interface between MEM and CC (R channel)
    input   wire    [63:0]  mem_rdata_i,
    input   wire            mem_rlast_i,
    input   wire            mem_rvalid_i,
    output  wire            mem_rready_o,    

    // Hit Flag FIFO write interface
    output  wire            hit_flag_fifo_afull_o,
    input   wire            hit_flag_fifo_wren_i,
    input   wire            hit_flag_fifo_wdata_i,

    // Hit data FIFO write interface
    output  wire            hit_data_fifo_afull_o,
    input   wire            hit_data_fifo_wren_i,
    input   wire    [517:0] hit_data_fifo_wdata_i,

    // AMBA AXI interface between INCT and CC (R channel)
    output  wire    [63:0]  inct_rdata_o,
    output  wire            inct_rlast_o,
    output  wire            inct_rvalid_o,
    input   wire            inct_rready_i
);

    // Fill the code here
    // USER DEFINED

    // CC_FIFO - u_hit_flag_fifo
    reg hit_flag_fifo_afull; 
    reg hit_flag_fifo_empty;
    reg hit_flag_fifo_rden;
    reg hit_flag_fifo_rdata;
    // CC_FIFO - u_hit_data_fifo
    reg hit_data_fifo_afull;
    reg hit_data_fifo_empty;
    wire hit_data_fifo_rden; // IMPORTANT
    reg [517:0]     hit_data_fifo_rdata;
    // CC_SERIALIZER - u_serializer
    reg [63:0]      serializer_rdata;
    reg serializer_rlast, serializer_rlast_n;
    reg serializer_rvalid;
    reg serializer_rready;
    // INCT and CC (R channel)
    reg [63:0] inct_rdata; 
    reg inct_rlast, inct_rlast_n;
    reg inct_rvalid;
    // misc // IMPORTANT
    reg [2:0] cnt, cnt_n;
    reg mem_rready;
    reg mem_rlast, mem_rlast_n; 
    reg hit, hit_n; 


    // code for SELECTOR 
    // Mux between [data from MC R Channel] & [data from Hit Data FIFO]
    // The control signal is the [hit flag from Hit Flag FIFO]

    // (hit flag==0) && (!valid && !last && !ready && !data) : [data from MC R Channel]
    // (hit flag==1) && (valid && last && ready && data) : [data from Hit Data FIFO]

    // State machine flip-flop
    always_ff@(posedge clk) begin
        if(!rst_n) begin
            cnt                 <= 3'b0;
            hit                 <= 1'b0;
            mem_rlast           <= 1'b0;
            serializer_rlast    <= 1'b0;
        end
        else begin
            cnt                 <= cnt_n;
            hit                 <= hit_n;
            mem_rlast           <= mem_rlast_n;
            serializer_rlast    <= serializer_rlast_n;
        end
    end

    // Combinational logic
    always_comb begin
        // Latch problem 
        hit_flag_fifo_rden = 1'b0;
        mem_rready          = 1'b0;
        serializer_rready   = 1'b0;

        mem_rlast_n         = mem_rlast_i;
        cnt_n               = cnt;

        // Determine hit_n
        if (hit_flag_fifo_rden)                 hit_n = hit_flag_fifo_rdata;
        else if (serializer_rlast||mem_rlast)   hit_n = hit_flag_fifo_rdata;
        else                                    hit_n = hit;

        // Determine inct_rvalid = either mem_rvalid, or serializer_rvalid
        inct_rvalid        = (!hit_n&&mem_rvalid_i) || (hit_n&&serializer_rvalid);

        // Determine hit_flag_fifo_rden
        if (!hit_flag_fifo_empty && inct_rready_i 
            && ( (!hit_flag_fifo_rdata&&mem_rvalid_i) || (hit_flag_fifo_rdata && serializer_rvalid) ) 
            && (cnt=='b0))                      hit_flag_fifo_rden  = 1'b1;
        else if ((cnt!=0))                      hit_flag_fifo_rden = 1'b0;

        // Increment cnt for bursting
        if (cnt==7)                                 cnt_n = 'b0;
        else if (inct_rready_i && inct_rvalid)      cnt_n = cnt+1;

        // Determine serializer_rready and mem_rready (output of DATA REORDER UNIT) // IMPORTANT
        if (!hit_flag_fifo_rdata & hit_flag_fifo_rden)      mem_rready          = 1'b1;
        else if (mem_rlast)                                 mem_rready          = 1'b0;
        if (hit_flag_fifo_rdata & hit_flag_fifo_rden)       serializer_rready   = 1'b1;
        else if (serializer_rlast)                          serializer_rready   = 1'b0;

        // Mux between data/last from [MC R Channel] & [Data FIFO]
        if(hit_n)begin 
            inct_rdata = serializer_rdata;
            inct_rlast = serializer_rlast_n;
        end
        else if(!hit_n) begin
            inct_rdata = mem_rdata_i;
            inct_rlast = mem_rlast_i;
        end
        else begin
            inct_rdata = 64'b0;
            inct_rlast = 1'b0;
        end

    end

    CC_FIFO #(.FIFO_DEPTH('d4), .DATA_WIDTH('d1), .AFULL_THRESHOLD('d2)) u_hit_flag_fifo(
        .clk            (clk),
        .rst_n          (rst_n),
        .full_o         (),
        .afull_o        (hit_flag_fifo_afull),                          // USER DEFINED
        .wren_i         (hit_flag_fifo_wren_i),
        .wdata_i        (hit_flag_fifo_wdata_i),
        .empty_o        (hit_flag_fifo_empty),                          // USER DEFINED
        .aempty_o       (),
        .rden_i         ((hit_flag_fifo_rden&!hit_flag_fifo_empty)),    // USER DEFINED, IMPORTANT
        .rdata_o        (hit_flag_fifo_rdata)                           // USER DEFINED
    );

    CC_FIFO #(.FIFO_DEPTH('d2), .DATA_WIDTH('d518), .AFULL_THRESHOLD('d1)) u_hit_data_fifo(
        .clk            (clk),
        .rst_n          (rst_n),
        .full_o         (),
        .afull_o        (hit_data_fifo_afull),                          // USER DEFINED
        .wren_i         (hit_data_fifo_wren_i),
        .wdata_i        (hit_data_fifo_wdata_i),
        .empty_o        (hit_data_fifo_empty),                          // USER DEFINED
        .aempty_o       (),
        .rden_i         (hit_data_fifo_rden&!hit_data_fifo_empty),      // USER DEFINED, IMPORTANT
        .rdata_o        (hit_data_fifo_rdata)                           // USER DEFINED
    );

    CC_SERIALIZER u_serializer(
        .clk            (clk),
        .rst_n          (rst_n),
        .fifo_empty_i   (hit_data_fifo_empty),          // USER DEFINED
        .fifo_aempty_i  (),
        .fifo_rdata_i   (hit_data_fifo_rdata),          // USER DEFINED
        .fifo_rden_o    (hit_data_fifo_rden),           // USER DEFINED
        .rdata_o        (serializer_rdata),             // USER DEFINED
        .rlast_o        (serializer_rlast_n),           // USER DEFINED
        .rvalid_o       (serializer_rvalid),            // USER DEFINED
        .rready_i       (serializer_rready)             // USER DEFINED
    );


    assign mem_rready_o             = mem_rready; 
    assign hit_flag_fifo_afull_o    = hit_flag_fifo_afull;
    assign hit_data_fifo_afull_o    = hit_data_fifo_afull;
    assign inct_rdata_o             = inct_rdata;
    assign inct_rlast_o             = inct_rlast;
    assign inct_rvalid_o            = inct_rvalid;

endmodule
