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
    parameter type          burst_req_t      = logic
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
    input  logic          r_done_i,
    input  logic          w_done_i,

    output logic [1:0]    irq_o
);

    localparam int unsigned DmaRegisterWidth = 64;

    /*
     * Signal and register definitions
     */
    idma_reg64_frontend_reg_pkg::idma_reg64_frontend_reg2hw_t dma_reg2hw;
    idma_reg64_frontend_reg_pkg::idma_reg64_frontend_hw2reg_t dma_hw2reg;

    // transaction id
    logic [DmaRegisterWidth-1:0] next_id, done_id;
    logic issue;

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

    /*
     * DMA Control Logic
     */
    always_comb begin : proc_process_regs

        // reset state
        valid_o              = '0;
        dma_hw2reg.next_id.d = '0;
        dma_hw2reg.done.d    = '0;
        dma_hw2reg.status.d  = ~backend_idle_i;

        dma_ctrl_rsp_o = dma_ctrl_rsp_tmp;

        // start transaction upon next_id read (and having a valid config)
        if (dma_reg2hw.next_id.re) begin
           if (dma_reg2hw.num_bytes.q != '0) begin
                valid_o = 1'b1;
                dma_hw2reg.next_id.d = next_id;
                dma_ctrl_rsp_o.ready = ready_i;
           end
        end

        // use full width id from generator
        dma_hw2reg.done.d = done_id;
    end : proc_process_regs


    // map hw register onto generic burst request
    always_comb begin : hw_req_conv
        burst_req_o                     = '0;

        burst_req_o.length              = dma_reg2hw.num_bytes.q;
        burst_req_o.src_addr            = dma_reg2hw.src_addr.q;
        burst_req_o.dst_addr            = dma_reg2hw.dst_addr.q;

            // Current backend only supports one ID
        // burst_req_o.opt.axi_id             = '0;
        burst_req_o.opt.axi_id             = '0;
            // DMA only supports incremental burst
        burst_req_o.opt.src.burst          = axi_pkg::BURST_INCR;
            // this frontend currently does not support cache variations
        burst_req_o.opt.src.cache          = '0;
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
        burst_req_o.opt.dst.cache          = '0;
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
    end : hw_req_conv

    // only increment issue counter if we have a valid transfer
    assign issue = ready_i && valid_o;

    // Set IP bits upon read/write completion
    // TODO: Should be set when RVALID & RLAST are set by the IOMMU. Check
    assign dma_hw2reg.ipsr.rip.de   = r_done_i;
    assign dma_hw2reg.ipsr.rip.d    = r_done_i;
    assign irq_o[0]                 = dma_reg2hw.ipsr.rip.q;

    // TODO: Should be set when WVALID & WLAST are set by the iDMA module. Check
    assign dma_hw2reg.ipsr.wip.de   = w_done_i;
    assign dma_hw2reg.ipsr.wip.d    = w_done_i;
    assign irq_o[1]                 = dma_reg2hw.ipsr.wip.q;

    // transfer id generator
    idma_transfer_id_gen #(
        .IdWidth      ( DmaRegisterWidth  )
    ) i_idma_transfer_id_gen (
        .clk_i,
        .rst_ni,
        .issue_i      ( issue             ),
        .retire_i     ( trans_complete_i  ),
        .next_o       ( next_id           ),
        .completed_o  ( done_id           )
    );

endmodule : idma_reg64_frontend
