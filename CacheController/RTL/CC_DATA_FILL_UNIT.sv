// Copyright (c) 2022 Sungkyunkwan University

module CC_DATA_FILL_UNIT
(
    input   wire            clk,
    input   wire            rst_n,
    
    // AMBA AXI interface between MEM and CC (R channel)
    input   wire    [63:0]  mem_rdata_i,
    input   wire            mem_rlast_i,
    input   wire            mem_rvalid_i,
    input   wire            mem_rready_i,

    // Miss Addr FIFO read interface 
    input   wire            miss_addr_fifo_empty_i,
    input   wire    [31:0]  miss_addr_fifo_rdata_i,
    output  wire            miss_addr_fifo_rden_o,

    // SRAM write port interface
    output  wire                wren_o,
    output  wire    [8:0]       waddr_o,
    output  wire    [17:0]      wdata_tag_o,
    output  wire    [511:0]     wdata_data_o   
);

    // Fill the code here
    reg                     miss_addr_fifo_rden, miss_addr_fifo_rden_n;
    reg                     wren;
    reg     [8:0]           waddr, waddr_n;
    reg     [17:0]          wdata_tag, wdata_tag_n;
    reg     [511:0]         wdata_data, wdata_data_n;
    reg     [2:0]           cnt, cnt_n;
    reg     [2:0]           wrptr;
    reg                     enable, enable_n;
    reg     [2:0]           offset, offset_n;

    // State machine flip-flop
    always_ff@(posedge clk)begin
        if(!rst_n)begin
            cnt             <= 3'b0;
            waddr           <= 9'b0;
            wdata_tag       <= 18'b0;
            offset          <= 3'b0;
            miss_addr_fifo_rden <= 1'b0;
            enable          <= 1'b0;
            wdata_data      <= 512'b0;
        end     
        else begin
            cnt             <= cnt_n;
            waddr           <= waddr_n;
            wdata_tag       <= wdata_tag_n;
            offset          <= offset_n;
            miss_addr_fifo_rden <= miss_addr_fifo_rden_n;
            enable          <= enable_n;
            wdata_data      <= wdata_data_n;
        end 
    end 

    // Combinational logic
    always_comb begin
        // Latch problem 
        miss_addr_fifo_rden_n = miss_addr_fifo_rden;
        enable_n = enable;
        wdata_data_n = wdata_data;

        // Determine miss_addr_fifo_rden // IMPORTANT
        if (mem_rvalid_i & mem_rready_i & (cnt=='b0))   miss_addr_fifo_rden_n =1'b1;
        else if ((cnt!=0))                              miss_addr_fifo_rden_n = 1'b0;

        
        // When miss_addr_fifo_rden==1, pop addr data and divide to addr, tag, offset
        if(miss_addr_fifo_rden_n)         waddr_n = miss_addr_fifo_rdata_i[14:6];
        else                            waddr_n = waddr;
        if(miss_addr_fifo_rden_n)         wdata_tag_n = {1'b1,miss_addr_fifo_rdata_i[31:15]};
        else                            wdata_tag_n = wdata_tag;
        if(miss_addr_fifo_rden_n)         offset_n = miss_addr_fifo_rdata_i[5:3];
        else                            offset_n = offset;

        // Increment by cnt: Deserialize the data
        wrptr = (offset_n+cnt) % 8;

        // Choose the data to write: Deserialize the data
        if(wrptr==0)        wdata_data_n[63:0]    = mem_rdata_i;
        else if(wrptr==1)   wdata_data_n[127:64]  = mem_rdata_i;
        else if(wrptr==2)   wdata_data_n[191:128] = mem_rdata_i;
        else if(wrptr==3)   wdata_data_n[255:192] = mem_rdata_i;
        else if(wrptr==4)   wdata_data_n[319:256] = mem_rdata_i;
        else if(wrptr==5)   wdata_data_n[383:320] = mem_rdata_i;
        else if(wrptr==6)   wdata_data_n[447:384] = mem_rdata_i;
        else if(wrptr==7)   wdata_data_n[511:448] = mem_rdata_i;
        
        //miss_addr_fifo_rden = mem_rvalid_i & mem_rready_i; 
        // Determine enable // IMPORTANT
        if (miss_addr_fifo_rden_n)    enable_n = 1'b1;
        else if (cnt==7)          enable_n = 1'b0;
        
        // Increment cnt for bursting: Deserialize the data
        if(cnt==7)begin
            wren    = 'd1;
            cnt_n   = 'd0;
        end
        else if(enable_n)begin
            wren    = 'd0;
            cnt_n   = cnt+1;
        end
        else begin
            wren    = 'd0;
            cnt_n   = cnt;
        end
    end

    assign miss_addr_fifo_rden_o    = miss_addr_fifo_rden_n;
    assign wren_o                   = wren;
    assign waddr_o                  = waddr;
    assign wdata_tag_o              = wdata_tag;
    assign wdata_data_o             = wdata_data_n;


endmodule
