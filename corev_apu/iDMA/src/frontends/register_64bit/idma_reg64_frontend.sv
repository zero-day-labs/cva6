// Copyright 2022 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Michael Rogenmoser <michaero@ethz.ch>
//
// Description: DMA frontend module that includes 64bit config and status reg handling

module idma_reg64_frontend #(
    /// register_interface request type
    parameter type          dma_regs_req_t   = logic,
    /// register_interface response type
    parameter type          dma_regs_rsp_t   = logic,
    /// dma burst request type
    parameter type          burst_req_t      = logic,
    /// Device ID
    parameter logic [23:0]  DEVICE_ID        = 24'd1,
    /// Process ID
    parameter logic [19:0]  PROCESS_ID       = 20'd1,
    /// AXI ID width
    parameter int unsigned  AxiIdWidth       = 32'd0,
    /// AXI AxID
    parameter logic [(AxiIdWidth-1):0] AxID  = 0
) (
    input  logic          clk_i,
    input  logic          rst_ni,
    /// register interface control slave
    input  dma_regs_req_t dma_ctrl_req_i,
    output dma_regs_rsp_t dma_ctrl_rsp_o,
    /// DMA backend signals
    output burst_req_t    burst_req_o,
    output logic          valid_o,
    input  logic          ready_i,
    input  logic          backend_idle_i,
    input  logic          trans_complete_i,

    output logic [1:0]    ttype_o,
    output logic [63:0]   wdata_o,
    input  logic [63:0]   rdata_i,
    input  logic          rdata_valid_i
);

    localparam int unsigned DmaRegisterWidth = 64;

    typedef enum logic [1:0] { 
        IDLE    = 2'b00,
        COUNT   = 2'b01,
        WAIT    = 2'b10
    } idma_state_t;
    idma_state_t state_q, state_n;

    logic [63:0]    transf_counter_q, transf_counter_n;
    logic [63:0]    transf_offset_q, transf_offset_n;

    /*
     * Signal and register definitions
     */
    idma_reg64_frontend_reg_pkg::idma_reg64_frontend_reg2hw_t dma_reg2hw;
    idma_reg64_frontend_reg_pkg::idma_reg64_frontend_hw2reg_t dma_hw2reg;

    // transaction id
    logic [DmaRegisterWidth-1:0] next_id, done_id;
    logic issue;
    logic trans_complete;

    dma_regs_rsp_t dma_ctrl_rsp_tmp;

    /*
     * DMA registers
     */
    idma_reg64_frontend_reg_top #(
        .reg_req_t( dma_regs_req_t ),
        .reg_rsp_t( dma_regs_rsp_t )
    ) i_dma_conf_regs (
        .clk_i,
        .rst_ni,
        .reg_req_i ( dma_ctrl_req_i   ),
        .reg_rsp_o ( dma_ctrl_rsp_tmp ),
        .reg2hw    ( dma_reg2hw       ),
        .hw2reg    ( dma_hw2reg       ),
        .devmode_i ( 1'b0             ) // if 1, explicit error return for unmapped register access
    );

    always_comb begin

        /*** TRANSFER PARAMETERS ***/
        burst_req_o                     = '0;

        burst_req_o.length              = dma_reg2hw.num_bytes.q;
        burst_req_o.src_addr            = dma_reg2hw.src_addr.q;
        burst_req_o.dst_addr            = dma_reg2hw.dst_addr.q;

        ttype_o                         = dma_reg2hw.conf.ttype.q;
        wdata_o                         = dma_reg2hw.wdata.q;

            // Current backend only supports one ID
        burst_req_o.opt.axi_id             = AxID;
            // Device ID
        burst_req_o.opt.device_id          = DEVICE_ID;
            // Process ID
        burst_req_o.opt.pv                 = dma_reg2hw.conf.pv.q;
        burst_req_o.opt.process_id         = (dma_reg2hw.conf.pv.q) ? 
                                             (PROCESS_ID) : 
                                             ('0);
            // DMA only supports incremental burst
        burst_req_o.opt.src.burst          = axi_pkg::BURST_INCR;
            // this frontend currently does not support cache variations
        burst_req_o.opt.src.cache          = dma_reg2hw.conf.cache.q;
            // AXI4 does not support locked transactions, use atomics
        burst_req_o.opt.src.lock           = '0;
            // unpriviledged, secure, data access
        burst_req_o.opt.src.prot           = '0;
            // not participating in qos
        burst_req_o.opt.src.qos            = '0;
            // only one region
        burst_req_o.opt.src.region         = '0;
            // DMA only supports incremental burst
        burst_req_o.opt.dst.burst          = axi_pkg::BURST_INCR;
            // this frontend currently does not support cache variations
        burst_req_o.opt.dst.cache          = dma_reg2hw.conf.cache.q;
            // AXI4 does not support locked transactions, use atomics
        burst_req_o.opt.dst.lock           = '0;
            // unpriviledged, secure, data access
        burst_req_o.opt.dst.prot           = '0;
            // not participating in qos
        burst_req_o.opt.dst.qos            = '0;
            // only one region in system
        burst_req_o.opt.dst.region         = '0;
            // ensure coupled AW to avoid deadlocks
        burst_req_o.opt.beo.decouple_aw    = '0;
        burst_req_o.opt.beo.decouple_rw    = dma_reg2hw.conf.decouple.q;
            // this frontend currently only supports completely debursting
        burst_req_o.opt.beo.src_max_llen   = '0;
            // this frontend currently only supports completely debursting
        burst_req_o.opt.beo.dst_max_llen   = '0;
        burst_req_o.opt.beo.src_reduce_len = dma_reg2hw.conf.deburst.q;
        burst_req_o.opt.beo.dst_reduce_len = dma_reg2hw.conf.deburst.q;

            // serialization no longer supported
        // burst_req_o.serialize   = dma_reg2hw.conf.serialize.q;

        /*** TRANSFER CONTROL ***/
        // reset state
        valid_o              = '0;
        dma_hw2reg.next_id.d = '0;
        dma_hw2reg.done.d    = '0;
        dma_hw2reg.status.d  = ~backend_idle_i;

        dma_ctrl_rsp_o = dma_ctrl_rsp_tmp;

        // use full width id from generator
        dma_hw2reg.done.d = done_id;

        dma_hw2reg.rdata.de = rdata_valid_i;
        dma_hw2reg.rdata.d  = rdata_i;

        issue           = 1'b0;
        trans_complete  = 1'b0;

        // Counter data
        transf_counter_n  = transf_counter_q;
        transf_offset_n   = transf_offset_q;
        state_n           = state_q;

        unique case (state_q)

            IDLE: begin
            
                // start transaction upon next_id read (and having a valid config)
                if (dma_reg2hw.next_id.re) begin
                    if (dma_reg2hw.num_bytes.q != '0) begin
                        
                        issue = 1'b1;
                        dma_hw2reg.next_id.d = next_id;
                        dma_ctrl_rsp_o.ready = ready_i;

                        transf_counter_n = dma_reg2hw.n_trans.q;
                        transf_offset_n  = '0;
                        state_n          = COUNT;
                    end
                end
            end

            COUNT: begin
            
                // Send request to FIFO
                valid_o              = 1'b1;

                burst_req_o.src_addr = dma_reg2hw.src_addr.q + transf_offset_q;
                burst_req_o.dst_addr = dma_reg2hw.dst_addr.q + transf_offset_q;

                if (ready_i) begin

                    state_n          = WAIT;
                    transf_counter_n = transf_counter_q - 1;
                    transf_offset_n  = transf_offset_q + 13'h1000;
                end
            end

            WAIT: begin
                
                if (trans_complete_i) begin
                    if ((transf_counter_q == '0) || 
                            (dma_reg2hw.conf.ttype.q == idma_pkg::DEFAULT)) begin
                        trans_complete = 1'b1;
                        state_n = IDLE;
                    end

                    else begin
                        state_n = COUNT;
                    end
                end
            end

            default: begin
                state_n = IDLE;
            end
        endcase
    end

    // transfer id generator
    idma_transfer_id_gen #(
        .IdWidth      ( DmaRegisterWidth  )
    ) i_idma_transfer_id_gen (
        .clk_i,
        .rst_ni,
        .issue_i      ( issue             ),
        .retire_i     ( trans_complete    ),
        .next_o       ( next_id           ),
        .completed_o  ( done_id           )
    );

    `FF(state_q,            state_n,            IDLE,   clk_i, rst_ni)
    `FF(transf_counter_q,   transf_counter_n,   '0,     clk_i, rst_ni)
    `FF(transf_offset_q,    transf_offset_n,    '0,     clk_i, rst_ni)

endmodule : idma_reg64_frontend
