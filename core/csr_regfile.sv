// Copyright 2018 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//
// Author: Florian Zaruba, ETH Zurich
// Date: 05.05.2017
// Description: CSR Register File as specified by RISC-V


module csr_regfile import ariane_pkg::*; #(
    parameter logic [63:0] DmBaseAddress   = 64'h0, // debug module base address
    parameter int          AsidWidth       = 1,
    parameter int          VmidWidth       = 1,
    parameter int unsigned NrCommitPorts   = 2,
    parameter int unsigned NrPMPEntries    = 8
) (
    input  logic                  clk_i,                      // Clock
    input  logic                  rst_ni,                     // Asynchronous reset active low
    input  logic                  time_irq_i,                 // Timer threw a interrupt
    // send a flush request out if a CSR with a side effect has changed (e.g. written)
    output logic                  flush_o,
    output logic                  halt_csr_o,                 // halt requested
    // commit acknowledge
    input  scoreboard_entry_t [NrCommitPorts-1:0] commit_instr_i, // the instruction we want to commit
    input  logic [NrCommitPorts-1:0]              commit_ack_i,   // Commit acknowledged a instruction -> increase instret CSR
    // Core and Cluster ID
    input  logic[riscv::VLEN-1:0] boot_addr_i,                // Address from which to start booting, mtvec is set to the same address
    input  logic[riscv::XLEN-1:0] hart_id_i,                  // Hart id in a multicore environment (reflected in a CSR)
    // we are taking an exception
    input exception_t             ex_i,                       // We've got an exception from the commit stage, take it

    input  fu_op                  csr_op_i,                   // Operation to perform on the CSR file
    input  logic  [11:0]          csr_addr_i,                 // Address of the register to read/write
    input  logic[riscv::XLEN-1:0] csr_wdata_i,                // Write data in
    output logic[riscv::XLEN-1:0] csr_rdata_o,                // Read data out
    input  logic                  dirty_fp_state_i,           // Mark the FP sate as dirty
    input  logic                  csr_write_fflags_i,         // Write fflags register e.g.: we are retiring a floating point instruction
    input  logic  [riscv::VLEN-1:0]  pc_i,                    // PC of instruction accessing the CSR
    output exception_t            csr_exception_o,            // attempts to access a CSR without appropriate privilege
                                                              // level or to write  a read-only register also
                                                              // raises illegal instruction exceptions.
    // Interrupts/Exceptions
    output logic  [riscv::VLEN-1:0] epc_o,                    // Output the exception PC to PC Gen, the correct CSR (mepc, sepc, vsepc) is set accordingly
    output logic                  eret_o,                     // Return from exception, set the PC of epc_o
    output logic  [riscv::VLEN-1:0] trap_vector_base_o,       // Output base of exception vector, correct CSR is output (mtvec, stvec, vstvec)
    output riscv::priv_lvl_t      priv_lvl_o,                 // Current privilege level the CPU is in
    output logic                  v_o,                        // Current virtualization mode state
    // FPU
    output riscv::xs_t            fs_o,                       // Floating point extension status
    output riscv::xs_t            vfs_o,                      // Floating point extension virtual status
    output logic [4:0]            fflags_o,                   // Floating-Point Accured Exceptions
    output logic [2:0]            frm_o,                      // Floating-Point Dynamic Rounding Mode
    output logic [6:0]            fprec_o,                    // Floating-Point Precision Control
    // Decoder
    output irq_ctrl_t             irq_ctrl_o,                 // interrupt management to id stage
    // MMU
    output logic                  en_translation_o,           // enable VA translation
    output logic                  en_g_translation_o,         // enable G-Stage translation
    output logic                  en_ld_st_translation_o,     // enable VA translation for load and stores
    output logic                  en_ld_st_g_translation_o,   // enable G-Stage translation for load and stores
    output riscv::priv_lvl_t      ld_st_priv_lvl_o,           // Privilege level at which load and stores should happen
    output logic                  ld_st_v_o,                  // Virtualization mode at which load and stores should happen
    input  logic                  csr_hs_ld_st_inst_i,        // Current instruction is a Hypervisor Load/Store Instruction
    output logic                  sum_o,
    output logic                  vs_sum_o,
    output logic                  mxr_o,
    output logic                  vmxr_o,
    output logic[riscv::PPNW-1:0] satp_ppn_o,
    output logic [AsidWidth-1:0]  asid_o,
    output logic[riscv::PPNW-1:0] vsatp_ppn_o,
    output logic [AsidWidth-1:0]  vs_asid_o,
    output logic[riscv::PPNW-1:0] hgatp_ppn_o,
    output logic [VmidWidth-1:0]  vmid_o,
    // external interrupts
`ifndef MSI_MODE
    input  logic [1:0]            irq_i,                      // external interrupt in
`else
    input  logic [ariane_pkg::NrIntpFiles-1:0] irq_i,         // external interrupt in
`endif
    input  logic                  ipi_i,                      // inter processor interrupt -> connected to machine mode sw
    input  logic                  debug_req_i,                // debug request in
    output logic                  set_debug_pc_o,
    // Virtualization Support
    output logic                  tvm_o,                      // trap virtual memory
    output logic                  tw_o,                       // timeout wait
    output logic                  vtw_o,                      // virtual timeout wait
    output logic                  tsr_o,                      // trap sret
    output logic                  debug_mode_o,               // we are in debug mode -> that will change some decoding
    output logic                  single_step_o,              // we are in single-step mode
    output logic                  hu_o,                       // hypervisor user mode
    // Caches
    output logic                  icache_en_o,                // L1 ICache Enable
    output logic                  dcache_en_o,                // L1 DCache Enable
    // From Decoder
    input  logic [riscv::XLEN-1:0]                                              mtopi_i             ,
    input  logic [riscv::XLEN-1:0]                                              stopi_i             ,
    input  logic [riscv::XLEN-1:0]                                              vstopi_i            ,
`ifdef MSI_MODE
    // To/From IMSIC
    output  logic [1:0]                                                         imsic_priv_lvl_o    ,
    output  logic [ariane_pkg::NrVSIntpFilesW:0]                                imsic_vgein_o       ,
    output  logic [riscv::XLEN-1:0]                                             imsic_addr_o        ,
    output  logic [riscv::XLEN-1:0]                                             imsic_data_o        ,
    output  logic                                                               imsic_we_o          ,
    output  logic                                                               imsic_claim_o       ,
    input   logic [riscv::XLEN-1:0]                                             imsic_data_i        ,
    input   logic                                                               imsic_exception_i   ,
    input   logic [ariane_pkg::NrIntpFiles-1:0][ariane_pkg::NrSourcesW-1:0]     imsic_xtopei_i      ,
`endif
    // Performance Counter
    output logic  [4:0]           perf_addr_o,                // read/write address to performance counter module (up to 29 aux counters possible in riscv encoding.h)
    output logic[riscv::XLEN-1:0] perf_data_o,                // write data to performance counter module
    input  logic[riscv::XLEN-1:0] perf_data_i,                // read data from performance counter module
    output logic                  perf_we_o,
    // PMPs
    output riscv::pmpcfg_t [15:0] pmpcfg_o,   // PMP configuration containing pmpcfg for max 16 PMPs
    output logic [15:0][riscv::PLEN-3:0] pmpaddr_o            // PMP addresses
);
    // AIA Spec
    localparam logic [riscv::XLEN-1:0]      AIA_CSR_DEF_PRIO = 1;
    logic [7:0]                             miselect_d     , miselect_q     ; 
    logic [7:0]                             siselect_d     , siselect_q     ; 
    logic [7:0]                             vsiselect_d    , vsiselect_q    ; 
    `ifdef MSI_MODE
    logic [1:0]                             rimsic_priv_lvl, wimsic_priv_lvl;
    logic [riscv::XLEN-1:0]                 rimsic_addr    , wimsic_addr    ;
    logic [ariane_pkg::NrVSIntpFilesW:0]    rimsic_vgein   , wimsic_vgein   ;
    `endif
    
    // internal signal to keep track of access exceptions
    logic        read_access_exception, update_access_exception, privilege_violation;
    logic        virtual_read_access_exception, virtual_update_access_exception, virtual_privilege_violation;
    logic        trap_to_v;
    logic en_ld_st_g_translation_d, en_ld_st_g_translation_q;

    logic        csr_we, csr_read;
    riscv::xlen_t csr_wdata, csr_rdata;
    riscv::priv_lvl_t   trap_to_priv_lvl;
    // register for enabling load store address translation, this is critical, hence the register
    logic        en_ld_st_translation_d, en_ld_st_translation_q;
    logic  mprv;
    logic  mret;  // return from M-mode exception
    logic  sret;  // return from S-mode exception
    logic  dret;  // return from debug mode
    // CSR write causes us to mark the FPU state as dirty
    logic  dirty_fp_state_csr;
    riscv::status_rv_t    mstatus_q,  mstatus_d;
    riscv::hstatus_rv_t   hstatus_q,  hstatus_d;
    riscv::status_rv_t    vsstatus_q,  vsstatus_d;

    riscv::xlen_t         mstatus_extended;
    riscv::xlen_t         hstatus_extended;
    riscv::xlen_t         vsstatus_extended;
    riscv::satp_t         vsatp_q, vsatp_d;
    riscv::hgatp_t        hgatp_q, hgatp_d;
    riscv::satp_t         satp_q, satp_d;
    riscv::dcsr_t         dcsr_q,     dcsr_d;
    riscv::csr_t  csr_addr, conv_csr_addr;
    // privilege level register
    riscv::priv_lvl_t   priv_lvl_d, priv_lvl_q;
    logic v_q, v_d;  // virtualization mode
    riscv::priv_lvl_t   acess_priv_lvl;
    // we are in debug
    logic        debug_mode_q, debug_mode_d;
    logic        mtvec_rst_load_q;// used to determine whether we came out of reset

    riscv::xlen_t dpc_q,       dpc_d;
    riscv::xlen_t dscratch0_q, dscratch0_d;
    riscv::xlen_t dscratch1_q, dscratch1_d;
    riscv::xlen_t mtvec_q,     mtvec_d;
    riscv::xlen_t medeleg_q,   medeleg_d;
    riscv::xlen_t mideleg_q,   mideleg_d;
    riscv::xlen_t mip_q,       mip_d;
    riscv::xlen_t mie_q,       mie_d;
    riscv::xlen_t mcounteren_q,mcounteren_d;
    riscv::xlen_t mscratch_q,  mscratch_d;
    riscv::xlen_t mepc_q,      mepc_d;
    riscv::xlen_t mcause_q,    mcause_d;
    riscv::xlen_t mtval_q,     mtval_d;
    riscv::xlen_t mtinst_q,    mtinst_d;
    riscv::xlen_t mtval2_q,    mtval2_d;

    riscv::xlen_t stvec_q,     stvec_d;
    riscv::xlen_t scounteren_q,scounteren_d;
    riscv::xlen_t sscratch_q,  sscratch_d;
    riscv::xlen_t sepc_q,      sepc_d;
    riscv::xlen_t scause_q,    scause_d;
    riscv::xlen_t stval_q,     stval_d;

    riscv::xlen_t hedeleg_q,   hedeleg_d;
    riscv::xlen_t hideleg_q,   hideleg_d;
    riscv::xlen_t hcounteren_q,hcounteren_d;
    riscv::xlen_t hgeie_q,     hgeie_d;
    riscv::xlen_t htval_q,     htval_d;
    riscv::xlen_t htinst_q,    htinst_d;
    riscv::envcfg_rv_t henvcfg_q, henvcfg_d;

    riscv::xlen_t vstvec_q,    vstvec_d;
    riscv::xlen_t vsscratch_q, vsscratch_d;
    riscv::xlen_t vsepc_q,     vsepc_d;
    riscv::xlen_t vscause_q,   vscause_d;
    riscv::xlen_t vstval_q,    vstval_d;

    // Environment Configuration Registers
    riscv::envcfg_rv_t menvcfg_q, menvcfg_d;
    riscv::envcfg_rv_t senvcfg_q, senvcfg_d;

    riscv::xlen_t dcache_q,    dcache_d;
    riscv::xlen_t icache_q,    icache_d;

    logic        wfi_d,       wfi_q;

    logic [63:0] cycle_q,     cycle_d;
    logic [63:0] instret_q,   instret_d;

    riscv::pmpcfg_t [15:0]    pmpcfg_q,  pmpcfg_d;
    logic [15:0][riscv::PLEN-3:0]        pmpaddr_q,  pmpaddr_d;


    assign pmpcfg_o = pmpcfg_q[15:0];
    assign pmpaddr_o = pmpaddr_q;

    riscv::fcsr_t fcsr_q, fcsr_d;
    // ----------------
    // Assignments
    // ----------------
    assign csr_addr = riscv::csr_t'(csr_addr_i);
    assign conv_csr_addr = riscv::convert_vs_access_csr((riscv::csr_t'(csr_addr_i)),v_q);
    assign fs_o = mstatus_q.fs;
    assign vfs_o = (ariane_pkg::RVH) ? vsstatus_q.fs : riscv::Off;
    // ----------------
    // CSR Read logic
    // ----------------
    assign mstatus_extended  = riscv::IS_XLEN64 ? mstatus_q[riscv::XLEN-1:0] :
                              {mstatus_q.sd, mstatus_q.wpri3[7:0], mstatus_q[22:0]};
    if(ariane_pkg::RVH) begin
        assign hstatus_extended  = hstatus_q[riscv::XLEN-1:0];
        assign vsstatus_extended = riscv::IS_XLEN64 ? vsstatus_q[riscv::XLEN-1:0] :
                                {vsstatus_q.sd, vsstatus_q.wpri3[7:0], vsstatus_q[22:0]};
    end else begin 
        assign hstatus_extended  = '0;
        assign vsstatus_extended = '0;
    end

    always_comb begin : csr_read_process
        // a read access exception can only occur if we attempt to read a CSR which does not exist
        read_access_exception = 1'b0;
        virtual_read_access_exception = 1'b0;
        csr_rdata = '0;
        perf_addr_o = conv_csr_addr.address[4:0];

        if (csr_read) begin
            unique case (conv_csr_addr.address)
                riscv::CSR_FFLAGS: begin
                    if (mstatus_q.fs == riscv::Off || (ariane_pkg::RVH && v_q && vsstatus_q.fs == riscv::Off)) begin
                        read_access_exception = 1'b1;
                    end else begin
                        csr_rdata = {{riscv::XLEN-5{1'b0}}, fcsr_q.fflags};
                    end
                end
                riscv::CSR_FRM: begin
                    if (mstatus_q.fs == riscv::Off || (ariane_pkg::RVH && v_q && vsstatus_q.fs == riscv::Off)) begin
                        read_access_exception = 1'b1;
                    end else begin
                        csr_rdata = {{riscv::XLEN-3{1'b0}}, fcsr_q.frm};
                    end
                end
                riscv::CSR_FCSR: begin
                    if (mstatus_q.fs == riscv::Off || (ariane_pkg::RVH && v_q && vsstatus_q.fs == riscv::Off)) begin
                        read_access_exception = 1'b1;
                    end else begin
                        csr_rdata = {{riscv::XLEN-8{1'b0}}, fcsr_q.frm, fcsr_q.fflags};
                    end
                end
                // non-standard extension
                riscv::CSR_FTRAN: begin
                    if (mstatus_q.fs == riscv::Off || (ariane_pkg::RVH && v_q && vsstatus_q.fs == riscv::Off)) begin
                        read_access_exception = 1'b1;
                    end else begin
                        csr_rdata = {{riscv::XLEN-7{1'b0}}, fcsr_q.fprec};
                    end
                end
                // debug registers
                riscv::CSR_DCSR:               csr_rdata = {{riscv::XLEN-32{1'b0}}, dcsr_q};
                riscv::CSR_DPC:                csr_rdata = dpc_q;
                riscv::CSR_DSCRATCH0:          csr_rdata = dscratch0_q;
                riscv::CSR_DSCRATCH1:          csr_rdata = dscratch1_q;
                // trigger module registers
                riscv::CSR_TSELECT:; // not implemented
                riscv::CSR_TDATA1:;  // not implemented
                riscv::CSR_TDATA2:;  // not implemented
                riscv::CSR_TDATA3:;  // not implemented
                riscv::CSR_VSSTATUS: begin
                    if(~ariane_pkg::RVH) read_access_exception = 1'b1;           
                    else csr_rdata = vsstatus_extended;
                end
                riscv::CSR_VSIE: begin
                    if(~ariane_pkg::RVH) read_access_exception = 1'b1;           
                    else csr_rdata = (mie_q & VS_DELEG_INTERRUPTS & hideleg_q) >> 1;
                end
                riscv::CSR_VSIP: begin
                    if(~ariane_pkg::RVH) read_access_exception = 1'b1;           
                    else csr_rdata = (mip_q & VS_DELEG_INTERRUPTS & hideleg_q) >> 1;
                end
                riscv::CSR_VSTVEC: begin
                    if(~ariane_pkg::RVH) read_access_exception = 1'b1;           
                    else csr_rdata = vstvec_q;
                end
                riscv::CSR_VSSCRATCH: begin
                    if(~ariane_pkg::RVH) read_access_exception = 1'b1;           
                    else csr_rdata = vsscratch_q;
                end
                riscv::CSR_VSEPC: begin
                    if(~ariane_pkg::RVH) read_access_exception = 1'b1;           
                    else csr_rdata = vsepc_q;
                end
                riscv::CSR_VSCAUSE: begin
                    if(~ariane_pkg::RVH) read_access_exception = 1'b1;           
                    else csr_rdata = vscause_q;
                end
                riscv::CSR_VSTVAL: begin
                    if(~ariane_pkg::RVH) read_access_exception = 1'b1;           
                    else csr_rdata = vstval_q;
                end
                riscv::CSR_VSATP: begin
                    // intercept reads to VSATP if in VS-Mode and VTVM is enabled
                    if(~ariane_pkg::RVH) begin
                        read_access_exception = 1'b1;
                    end else if (priv_lvl_o == riscv::PRIV_LVL_S && hstatus_q.vtvm && v_q) begin
                        virtual_read_access_exception = 1'b1;
                    end else begin
                        csr_rdata = vsatp_q;
                    end
                end
                // supervisor registers
                riscv::CSR_SSTATUS: begin
                    csr_rdata = mstatus_extended & ariane_pkg::SMODE_STATUS_READ_MASK[riscv::XLEN-1:0];
                end
                riscv::CSR_SIE: begin
                    mask = (ariane_pkg::RVH) ? mideleg_q & ~HS_DELEG_INTERRUPTS : mideleg_q;
                    csr_rdata = mie_q & mask;
                end
                riscv::CSR_SIP: begin
                    mask = (ariane_pkg::RVH) ? mideleg_q & ~HS_DELEG_INTERRUPTS : mideleg_q;
                    csr_rdata = mip_q & mask;
                end
                riscv::CSR_STVEC:       csr_rdata = stvec_q;
                riscv::CSR_SCOUNTEREN:  csr_rdata = scounteren_q;
                riscv::CSR_SSCRATCH:    csr_rdata = sscratch_q;
                riscv::CSR_SEPC:        csr_rdata = sepc_q;
                riscv::CSR_SCAUSE:      csr_rdata = scause_q;
                riscv::CSR_STVAL:       csr_rdata = stval_q;
                riscv::CSR_SATP: begin
                    // intercept reads to SATP if in S-Mode and TVM is enabled
                    if (priv_lvl_o == riscv::PRIV_LVL_S && mstatus_q.tvm) begin
                        read_access_exception = 1'b1;
                    end else begin
                        csr_rdata = satp_q;
                    end
                end
                riscv::CSR_SENVCFG:            csr_rdata = senvcfg_q;
                // hypervisor mode registers
                riscv::CSR_HSTATUS: begin
                    if(~ariane_pkg::RVH) read_access_exception = 1'b1;           
                    else csr_rdata = hstatus_extended;
                end
                riscv::CSR_HEDELEG: begin
                    if(~ariane_pkg::RVH) read_access_exception = 1'b1;           
                    else csr_rdata = hedeleg_q;
                end
                riscv::CSR_HIDELEG: begin
                    if(~ariane_pkg::RVH) read_access_exception = 1'b1;           
                    else csr_rdata = hideleg_q;
                end
                riscv::CSR_HIE: begin
                    if(~ariane_pkg::RVH) read_access_exception = 1'b1;           
                    else csr_rdata = mie_q & HS_DELEG_INTERRUPTS;
                end
                riscv::CSR_HIP: begin
                    if(~ariane_pkg::RVH) read_access_exception = 1'b1;           
                    else csr_rdata = mip_q & HS_DELEG_INTERRUPTS;
                end
                riscv::CSR_HVIP: begin
                    if(~ariane_pkg::RVH) read_access_exception = 1'b1;           
                    else csr_rdata = mip_q & VS_DELEG_INTERRUPTS;
                end
                riscv::CSR_HCOUNTEREN: begin
                    if(~ariane_pkg::RVH) read_access_exception = 1'b1;           
                    else csr_rdata = hcounteren_q;
                end
                riscv::CSR_HTVAL: begin
                    if(~ariane_pkg::RVH) read_access_exception = 1'b1;           
                    else csr_rdata = htval_q;
                end
                riscv::CSR_HTINST: begin
                    if(~ariane_pkg::RVH) read_access_exception = 1'b1;           
                    else csr_rdata = htinst_q;
                end
                riscv::CSR_HGEIE: begin
                    if(~ariane_pkg::RVH) read_access_exception = 1'b1;           
                    else csr_rdata = '0;
                end
                riscv::CSR_HGEIP: begin
                    if(~ariane_pkg::RVH) read_access_exception = 1'b1;           
                    else csr_rdata = '0;
                end
                riscv::CSR_HGATP: begin
                    if(~ariane_pkg::RVH) begin 
                        read_access_exception = 1'b1;
                    // intercept reads to HGATP if in HS-Mode and TVM is enabled
                    end else if (priv_lvl_o == riscv::PRIV_LVL_S && !v_q && mstatus_q.tvm) begin
                        read_access_exception = 1'b1;
                    end else begin
                        csr_rdata = hgatp_q;
                    end
                end
                riscv::CSR_HENVCFG:            csr_rdata = henvcfg_q;

                // machine mode registers
                riscv::CSR_MSTATUS:            csr_rdata = mstatus_extended;
                riscv::CSR_MISA:               csr_rdata = ISA_CODE;
                riscv::CSR_MEDELEG:            csr_rdata = medeleg_q;
                riscv::CSR_MIDELEG:            csr_rdata = mideleg_q;
                riscv::CSR_MIE:                csr_rdata = mie_q;
                riscv::CSR_MTVEC:              csr_rdata = mtvec_q;
                riscv::CSR_MCOUNTEREN:         csr_rdata = mcounteren_q;
                riscv::CSR_MSCRATCH:           csr_rdata = mscratch_q;
                riscv::CSR_MEPC:               csr_rdata = mepc_q;
                riscv::CSR_MCAUSE:             csr_rdata = mcause_q;
                riscv::CSR_MTVAL:              csr_rdata = mtval_q;
                riscv::CSR_MIP:                csr_rdata = mip_q;
                riscv::CSR_MVENDORID:          csr_rdata = OPENHWGROUP_MVENDORID;
                riscv::CSR_MARCHID:            csr_rdata = ARIANE_MARCHID;
                riscv::CSR_MIMPID:             csr_rdata = '0; // not implemented
                riscv::CSR_MHARTID:            csr_rdata = hart_id_i;
                riscv::CSR_MCONFIGPTR:         csr_rdata = '0; // no configuration data structure
                riscv::CSR_MTINST: begin
                    if(~ariane_pkg::RVH) begin 
                        read_access_exception = 1'b1;
                    end else begin 
                        csr_rdata = mtinst_q;
                    end
                end
                riscv::CSR_MTVAL2: begin
                    if(~ariane_pkg::RVH) begin 
                        read_access_exception = 1'b1;
                    end else begin 
                        csr_rdata = mtval2_q;
                    end
                end
                riscv::CSR_MENVCFG:            csr_rdata = menvcfg_q;
                // Smaia and Ssaia
                riscv::CSR_MISELECT:           csr_rdata = {{riscv::XLEN-8{1'b0}}, miselect_q};
                riscv::CSR_MIREG: begin
                    case (miselect_q) inside
                        [8'h30 : 8'h3F]: begin
                            // Return 1 iprio array not implemented yet
                            csr_rdata = AIA_CSR_DEF_PRIO;
                        end
                        [8'h70 : 8'hFF]: begin
                            `ifdef MSI_MODE
                            rimsic_addr         = {{riscv::XLEN-8{1'b0}}, miselect_q}; 
                            rimsic_priv_lvl     = riscv::PRIV_LVL_M;
                            rimsic_vgein        = '0;
                            csr_rdata           = imsic_data_i;
                            `else
                            read_access_exception = 1'b1;
                            `endif
                        end 
                        default: read_access_exception = 1'b1;
                    endcase
                end
                `ifdef MSI_MODE
                riscv::CSR_MTOPIE:             csr_rdata = ((imsic_xtopei_i[ariane_pkg::M_FILE] << 16)|
                                                            imsic_xtopei_i[ariane_pkg::M_FILE]);
                `endif
                riscv::CSR_MTOPI:              csr_rdata = (mtopi_i == 0) ? '0 : 
                                                           (((mtopi_i) << 16) | AIA_CSR_DEF_PRIO);
                riscv::CSR_MVIEN:              csr_rdata = '0;
                riscv::CSR_MVIP:               csr_rdata = '0;
                riscv::CSR_SISELECT:           csr_rdata = {{riscv::XLEN-8{1'b0}}, siselect_q};
                riscv::CSR_SIREG: begin
                    case (siselect_q) inside
                        [8'h30 : 8'h3F]: begin
                            // Return 1 iprio array not implemented yet
                            csr_rdata = AIA_CSR_DEF_PRIO;
                        end
                        [8'h70 : 8'hFF]: begin
                            `ifdef MSI_MODE
                            rimsic_addr         = {{riscv::XLEN-8{1'b0}}, siselect_q}; 
                            rimsic_priv_lvl     = riscv::PRIV_LVL_S;
                            rimsic_vgein        = '0;
                            csr_rdata           = imsic_data_i;
                            `else
                            read_access_exception = 1'b1;
                            `endif
                        end 
                        default: read_access_exception = 1'b1;
                    endcase
                end
                `ifdef MSI_MODE
                riscv::CSR_STOPIE:             csr_rdata = ((imsic_xtopei_i[ariane_pkg::S_FILE] << 16)|
                                                             imsic_xtopei_i[ariane_pkg::S_FILE]);
                `endif
                riscv::CSR_STOPI:              csr_rdata = (stopi_i == 0) ? '0 : 
                                                           ((stopi_i << 16) | AIA_CSR_DEF_PRIO);
                riscv::CSR_VSISELECT: begin
                    if(!ariane_pkg::RVH) begin
                        read_access_exception = 1'b1;
                    end else begin
                        csr_rdata = {{riscv::XLEN-8{1'b0}}, vsiselect_q};
                    end
                end
                riscv::CSR_VSIREG: begin
                    if(~ariane_pkg::RVH) begin
                        read_access_exception = 1'b1;
                    end else begin
                        case (vsiselect_q) inside
                            [8'h30 : 8'h3F]: begin
                                
                            end
                            [8'h70 : 8'hFF]: begin
                                `ifdef MSI_MODE
                                rimsic_addr         = {{riscv::XLEN-8{1'b0}}, vsiselect_q}; 
                                rimsic_priv_lvl     = riscv::PRIV_LVL_S;
                                rimsic_vgein        = hstatus_q.vgein[ariane_pkg::NrVSIntpFilesW:0];
                                csr_rdata           = imsic_data_i;
                                `else
                                virtual_read_access_exception = 1'b1;
                                `endif
                            end 
                            default: virtual_read_access_exception = 1'b1;
                        endcase
                    end
                end
                riscv::CSR_HVIEN: begin
                    if(~ariane_pkg::RVH) read_access_exception = 1'b1;   
                    else csr_rdata = '0;
                end
                riscv::CSR_HVICTL: begin
                    if(~ariane_pkg::RVH) read_access_exception = 1'b1;   
                    else csr_rdata = '0;
                end
                riscv::CSR_HVIPRIO1: begin
                    if(~ariane_pkg::RVH) read_access_exception = 1'b1;   
                    else csr_rdata = '0;
                end
                riscv::CSR_HVIPRIO2: begin
                    if(~ariane_pkg::RVH) read_access_exception = 1'b1;   
                    else csr_rdata = '0;
                end
                `ifdef MSI_MODE
                riscv::CSR_VSTOPEI: begin
                    if(~ariane_pkg::RVH) read_access_exception = 1'b1;   
                    else begin
                        /** We should check the value of hstatus_q.vgein[ariane_pkg::NrVSIntpFilesW:0]*/
                        csr_rdata = ((imsic_xtopei_i[ariane_pkg::S_FILE + hstatus_q.vgein[ariane_pkg::NrVSIntpFilesW:0]] << 16) 
                                    | imsic_xtopei_i[ariane_pkg::S_FILE + hstatus_q.vgein[ariane_pkg::NrVSIntpFilesW:0]]);
                    end
                end
                `endif
                riscv::CSR_VSTOPI: begin
                    if(~ariane_pkg::RVH) read_access_exception = 1'b1;   
                    else begin
                        /** TODO (D3boker1): needs optimization in "vstopi_i-1" to not infer an adder*/
                        csr_rdata = (vstopi_i == 0) ? '0 : 
                                    (((vstopi_i-1) << 16) | AIA_CSR_DEF_PRIO); 
                    end
                end
                // Counters and Timers
                riscv::CSR_MCYCLE:             csr_rdata = cycle_q[riscv::XLEN-1:0];
                riscv::CSR_MCYCLEH:            if (riscv::XLEN == 32) csr_rdata = cycle_q[63:32]; else read_access_exception = 1'b1;
                riscv::CSR_MINSTRET:           csr_rdata = instret_q[riscv::XLEN-1:0];
                riscv::CSR_MINSTRETH:          if (riscv::XLEN == 32) csr_rdata = instret_q[63:32]; else read_access_exception = 1'b1;
                riscv::CSR_CYCLE:              csr_rdata = cycle_q[riscv::XLEN-1:0];
                riscv::CSR_CYCLEH:             if (riscv::XLEN == 32) csr_rdata = cycle_q[63:32]; else read_access_exception = 1'b1;
                riscv::CSR_INSTRET:            csr_rdata = instret_q[riscv::XLEN-1:0];
                riscv::CSR_INSTRETH:           if (riscv::XLEN == 32) csr_rdata = instret_q[63:32]; else read_access_exception = 1'b1;
                riscv::CSR_ML1_ICACHE_MISS,
                riscv::CSR_ML1_DCACHE_MISS,
                riscv::CSR_MITLB_MISS,
                riscv::CSR_MDTLB_MISS,
                riscv::CSR_MLOAD,
                riscv::CSR_MSTORE,
                riscv::CSR_MEXCEPTION,
                riscv::CSR_MEXCEPTION_RET,
                riscv::CSR_MBRANCH_JUMP,
                riscv::CSR_MCALL,
                riscv::CSR_MRET,
                riscv::CSR_MMIS_PREDICT,
                riscv::CSR_MSB_FULL,
                riscv::CSR_MIF_EMPTY,
                riscv::CSR_MHPM_COUNTER_17,
                riscv::CSR_MHPM_COUNTER_18,
                riscv::CSR_MHPM_COUNTER_19,
                riscv::CSR_MHPM_COUNTER_20,
                riscv::CSR_MHPM_COUNTER_21,
                riscv::CSR_MHPM_COUNTER_22,
                riscv::CSR_MHPM_COUNTER_23,
                riscv::CSR_MHPM_COUNTER_24,
                riscv::CSR_MHPM_COUNTER_25,
                riscv::CSR_MHPM_COUNTER_26,
                riscv::CSR_MHPM_COUNTER_27,
                riscv::CSR_MHPM_COUNTER_28,
                riscv::CSR_MHPM_COUNTER_29,
                riscv::CSR_MHPM_COUNTER_30,
                riscv::CSR_MHPM_COUNTER_31:           csr_rdata   = perf_data_i;
                // custom (non RISC-V) cache control
                riscv::CSR_DCACHE:           csr_rdata = dcache_q;
                riscv::CSR_ICACHE:           csr_rdata = icache_q;
                // PMPs
                riscv::CSR_PMPCFG0:          csr_rdata = pmpcfg_q[riscv::XLEN/8-1:0];
                riscv::CSR_PMPCFG1:          if (riscv::XLEN == 32) csr_rdata = pmpcfg_q[7:4]; else read_access_exception = 1'b1;
                riscv::CSR_PMPCFG2:          csr_rdata = pmpcfg_q[8 +: riscv::XLEN/8];
                riscv::CSR_PMPCFG3:          if (riscv::XLEN == 32) csr_rdata = pmpcfg_q[15:12]; else read_access_exception = 1'b1;
                // PMPADDR
                riscv::CSR_PMPADDR0,
                riscv::CSR_PMPADDR1,
                riscv::CSR_PMPADDR2,
                riscv::CSR_PMPADDR3,
                riscv::CSR_PMPADDR4,
                riscv::CSR_PMPADDR5,
                riscv::CSR_PMPADDR6,
                riscv::CSR_PMPADDR7,
                riscv::CSR_PMPADDR8,
                riscv::CSR_PMPADDR9,
                riscv::CSR_PMPADDR10,
                riscv::CSR_PMPADDR11,
                riscv::CSR_PMPADDR12,
                riscv::CSR_PMPADDR13,
                riscv::CSR_PMPADDR14,
                riscv::CSR_PMPADDR15: begin
                    // index is specified by the last byte in the address
                    automatic int index = csr_addr.csr_decode.address[3:0];
                    // Important: we only support granularity 8 bytes (G=1)
                    // -> last bit of pmpaddr must be set 0/1 based on the mode:
                    // NA4, NAPOT: 1
                    // TOR, OFF:   0
                    if (pmpcfg_q[index].addr_mode[1] == 1'b1)
                        csr_rdata = {10'b0, pmpaddr_q[index][riscv::PLEN-3:0]};
                    else
                        csr_rdata = {10'b0, pmpaddr_q[index][riscv::PLEN-3:1], 1'b0};
                end
                default: read_access_exception = 1'b1;
            endcase
        end
    end
    // ---------------------------
    // CSR Write and update logic
    // ---------------------------
    riscv::xlen_t mask;
    always_comb begin : csr_update
        automatic riscv::satp_t satp;
        automatic riscv::satp_t vsatp;
        automatic riscv::hgatp_t hgatp;
        automatic logic [63:0] instret;

        satp = satp_q;
        if(ariane_pkg::RVH) begin
            vsatp = vsatp_q;
            hgatp = hgatp_q;
        end else begin
            vsatp = '0;
            hgatp = '0;
        end
        instret = instret_q;

        // --------------------
        // Counters
        // --------------------
        cycle_d = cycle_q;
        instret_d = instret_q;
        if (!debug_mode_q) begin
            // increase instruction retired counter
            for (int i = 0; i < NrCommitPorts; i++) begin
                if (commit_ack_i[i] && !ex_i.valid) instret++;
            end
            instret_d = instret;
            // increment the cycle count
            if (ENABLE_CYCLE_COUNT) cycle_d = cycle_q + 1'b1;
            else cycle_d = instret;
        end

        eret_o                  = 1'b0;
        flush_o                 = 1'b0;
        update_access_exception = 1'b0;
        virtual_update_access_exception = 1'b0;

        set_debug_pc_o          = 1'b0;

        perf_we_o               = 1'b0;
        perf_data_o             = 'b0;

        fcsr_d                  = fcsr_q;

        priv_lvl_d              = priv_lvl_q;
        v_d                     = v_q;
        debug_mode_d            = debug_mode_q;
        dcsr_d                  = dcsr_q;
        dpc_d                   = dpc_q;
        dscratch0_d             = dscratch0_q;
        dscratch1_d             = dscratch1_q;
        mstatus_d               = mstatus_q;
        if(ariane_pkg::RVH) begin
            hstatus_d               = hstatus_q;
            vsstatus_d              = vsstatus_q;
        end

        // check whether we come out of reset
        // this is a workaround. some tools have issues
        // having boot_addr_i in the asynchronous
        // reset assignment to mtvec_d, even though
        // boot_addr_i will be assigned a constant
        // on the top-level.
        if (mtvec_rst_load_q) begin
            mtvec_d             = {{riscv::XLEN-riscv::VLEN{1'b0}}, boot_addr_i} + 'h40;
        end else begin
            mtvec_d             = mtvec_q;
        end

        medeleg_d               = medeleg_q;
        mideleg_d               = mideleg_q;
        mip_d                   = mip_q;
        mie_d                   = mie_q;
        mepc_d                  = mepc_q;
        mcause_d                = mcause_q;
        mcounteren_d            = mcounteren_q;
        mscratch_d              = mscratch_q;
        mtval_d                 = mtval_q;
        if(ariane_pkg::RVH) begin
            mtinst_d                = mtinst_q;
            mtval2_d                = mtval2_q;
        end
        dcache_d                = dcache_q;
        icache_d                = icache_q;

        if(ariane_pkg::RVH) begin
            vsstatus_d              = vsstatus_q;
            vstvec_d                = vstvec_q;
            vsscratch_d             = vsscratch_q;
            vsepc_d                 = vsepc_q;
            vscause_d               = vscause_q;
            vstval_d                = vstval_q;
            vsatp_d                 = vsatp_q;
        end

        sepc_d                  = sepc_q;
        scause_d                = scause_q;
        stvec_d                 = stvec_q;
        scounteren_d            = scounteren_q;
        sscratch_d              = sscratch_q;
        stval_d                 = stval_q;
        satp_d                  = satp_q;

        if(ariane_pkg::RVH) begin
            hedeleg_d               = hedeleg_q;
            hideleg_d               = hideleg_q;
            hgeie_d                 = hgeie_q;
            hgatp_d                 = hgatp_q;
            hcounteren_d            = hcounteren_q;
            htval_d                 = htval_q;
            htinst_d                = htinst_q;
            henvcfg_d               = henvcfg_q;
        end

        menvcfg_d               = menvcfg_q;
        senvcfg_d               = senvcfg_q;

        en_ld_st_translation_d  = en_ld_st_translation_q;
        if(ariane_pkg::RVH) begin
            en_ld_st_g_translation_d = en_ld_st_g_translation_q;
        end
        dirty_fp_state_csr      = 1'b0;

        pmpcfg_d                = pmpcfg_q;
        pmpaddr_d               = pmpaddr_q;

        // AIA
        miselect_d              = miselect_q;
        siselect_d              = siselect_q;
        vsiselect_d             = vsiselect_q;

        `ifdef MSI_MODE
        wimsic_addr             = '0;
        wimsic_priv_lvl         = '0;
        wimsic_vgein            = '0;   
        imsic_data_o            = '0; 
        imsic_we_o              = '0;
        imsic_claim_o           = '0; 
        `endif

        // check for correct access rights and that we are writing
        if (csr_we) begin
            unique case (conv_csr_addr.address)
                // Floating-Point
                riscv::CSR_FFLAGS: begin
                    if (mstatus_q.fs == riscv::Off || (ariane_pkg::RVH && v_q && vsstatus_q.fs == riscv::Off)) begin
                        update_access_exception = 1'b1;
                    end else begin
                        dirty_fp_state_csr = 1'b1;
                        fcsr_d.fflags = csr_wdata[4:0];
                        // this instruction has side-effects
                        flush_o = 1'b1;
                    end
                end
                riscv::CSR_FRM: begin
                    if (mstatus_q.fs == riscv::Off || (ariane_pkg::RVH && v_q && vsstatus_q.fs == riscv::Off)) begin
                        update_access_exception = 1'b1;
                    end else begin
                        dirty_fp_state_csr = 1'b1;
                        fcsr_d.frm    = csr_wdata[2:0];
                        // this instruction has side-effects
                        flush_o = 1'b1;
                    end
                end
                riscv::CSR_FCSR: begin
                    if (mstatus_q.fs == riscv::Off || (ariane_pkg::RVH && v_q && vsstatus_q.fs == riscv::Off)) begin
                        update_access_exception = 1'b1;
                    end else begin
                        dirty_fp_state_csr = 1'b1;
                        fcsr_d[7:0] = csr_wdata[7:0]; // ignore writes to reserved space
                        // this instruction has side-effects
                        flush_o = 1'b1;
                    end
                end
                riscv::CSR_FTRAN: begin
                    if (mstatus_q.fs == riscv::Off || (ariane_pkg::RVH && v_q && vsstatus_q.fs == riscv::Off)) begin
                        update_access_exception = 1'b1;
                    end else begin
                        dirty_fp_state_csr = 1'b1;
                        fcsr_d.fprec = csr_wdata[6:0]; // ignore writes to reserved space
                        // this instruction has side-effects
                        flush_o = 1'b1;
                    end
                end
                // debug CSR
                riscv::CSR_DCSR: begin
                    dcsr_d = csr_wdata[31:0];
                    // debug is implemented
                    dcsr_d.xdebugver = 4'h4;
                    // currently not supported
                    dcsr_d.nmip      = 1'b0;
                    dcsr_d.stopcount = 1'b0;
                    dcsr_d.stoptime  = 1'b0;
                end
                riscv::CSR_DPC:                dpc_d = csr_wdata;
                riscv::CSR_DSCRATCH0:          dscratch0_d = csr_wdata;
                riscv::CSR_DSCRATCH1:          dscratch1_d = csr_wdata;
                // trigger module CSRs
                riscv::CSR_TSELECT:; // not implemented
                riscv::CSR_TDATA1:;  // not implemented
                riscv::CSR_TDATA2:;  // not implemented
                riscv::CSR_TDATA3:;  // not implemented
                // virtual supervisor registers
                riscv::CSR_VSSTATUS: begin
                    if(~ariane_pkg::RVH) begin 
                        update_access_exception = 1'b1;
                    end else begin
                        mask = ariane_pkg::SMODE_STATUS_WRITE_MASK[riscv::XLEN-1:0];
                        vsstatus_d = (vsstatus_q & ~{{64-riscv::XLEN{1'b0}}, mask}) | {{64-riscv::XLEN{1'b0}}, (csr_wdata & mask)};
                        // hardwire to zero if floating point extension is not present
                        vsstatus_d.xs   = riscv::Off;
                        if (!FP_PRESENT) begin
                            vsstatus_d.fs = riscv::Off;
                        end
                    end
                    // this instruction has side-effects
                    flush_o = 1'b1;
                end
                riscv::CSR_VSIE: begin
                    if(~ariane_pkg::RVH) begin 
                        update_access_exception = 1'b1;
                    end else begin 
                        mie_d = (mie_q & ~hideleg_q) | ((csr_wdata << 1) & hideleg_q);
                    end
                end
                riscv::CSR_VSIP: begin
                    if(~ariane_pkg::RVH) begin 
                        update_access_exception = 1'b1;
                    end else begin
                        // only the virtual supervisor software interrupt is write-able, iff delegated
                        mask = riscv::MIP_VSSIP & hideleg_q;
                        mip_d = (mip_q & ~mask) | ((csr_wdata << 1) & mask);
                    end
                end
                riscv::CSR_VSTVEC: begin
                    if(~ariane_pkg::RVH) begin 
                        update_access_exception = 1'b1;
                    end else begin
                        vstvec_d    = {csr_wdata[riscv::XLEN-1:2], 1'b0, csr_wdata[0]};
                        if (csr_wdata[0]) vstvec_d = {csr_wdata[riscv::XLEN-1:8], 7'b0, csr_wdata[0]};
                    end
                end
                riscv::CSR_VSSCRATCH: begin
                    if(~ariane_pkg::RVH) begin 
                        update_access_exception = 1'b1;
                    end else begin 
                        vsscratch_d = csr_wdata;
                    end
                end
                riscv::CSR_VSEPC: begin
                    if(~ariane_pkg::RVH) begin 
                        update_access_exception = 1'b1;
                    end else begin
                        vsepc_d = {csr_wdata[riscv::XLEN-1:1], 1'b0};
                    end
                end
                riscv::CSR_VSCAUSE: begin
                    if(~ariane_pkg::RVH) begin 
                        update_access_exception = 1'b1;
                    end else begin
                        vscause_d = csr_wdata;
                    end
                end
                riscv::CSR_VSTVAL: begin
                    if(~ariane_pkg::RVH) begin 
                        update_access_exception = 1'b1;
                    end else begin
                        vstval_d = csr_wdata;
                    end
                end
                // virtual supervisor address translation and protection
                riscv::CSR_VSATP: begin
                    if(~ariane_pkg::RVH) begin 
                        update_access_exception = 1'b1;
                    end if (priv_lvl_o == riscv::PRIV_LVL_S && v_q && hstatus_q.vtvm)
                            virtual_update_access_exception = 1'b1;
                    else begin
                        vsatp      = riscv::satp_t'(csr_wdata);
                        // only make ASID_LEN - 1 bit stick, that way software can figure out how many ASID bits are supported
                        vsatp.asid = vsatp.asid & {{(riscv::ASIDW-AsidWidth){1'b0}}, {AsidWidth{1'b1}}};
                        // only update if we actually support this mode
                        if (riscv::vm_mode_t'(vsatp.mode) == riscv::ModeOff ||
                            riscv::vm_mode_t'(vsatp.mode) == riscv::MODE_SV) vsatp_d = vsatp;
                        // this instruction has side-effects
                        flush_o = 1'b1;
                    end
                end
                // sstatus is a subset of mstatus - mask it accordingly
                riscv::CSR_SSTATUS: begin
                    mask = ariane_pkg::SMODE_STATUS_WRITE_MASK[riscv::XLEN-1:0];
                    mstatus_d  = (mstatus_q & ~{{64-riscv::XLEN{1'b0}}, mask}) | {{64-riscv::XLEN{1'b0}}, (csr_wdata & mask)};
                    // hardwire to zero if floating point extension is not present
                    if (!FP_PRESENT) begin
                        mstatus_d.fs  = riscv::Off;
                        if(ariane_pkg::RVH) begin
                            vsstatus_d.fs = riscv::Off;
                        end
                    end
                    // this instruction has side-effects
                    flush_o = 1'b1;
                end
                // even machine mode interrupts can be visible and set-able to supervisor
                // if the corresponding bit in mideleg is set
                riscv::CSR_SIE: begin
                    mask = (ariane_pkg::RVH) ? mideleg_q & ~HS_DELEG_INTERRUPTS : mideleg_q;
                    // the mideleg makes sure only delegate-able register (and therefore also only implemented registers) are written
                    mie_d = (mie_q & ~mask) | (csr_wdata & mask);
                end

                riscv::CSR_SIP: begin
                    mask = riscv::MIP_SSIP & mideleg_q;
                    // only the supervisor software interrupt is write-able, iff delegated
                    mip_d = (mip_q & ~mask) | (csr_wdata & mask);
                end

                riscv::CSR_STVEC: begin
                    stvec_d = {csr_wdata[riscv::XLEN-1:2], 1'b0, csr_wdata[0]};
                    if (csr_wdata[0]) stvec_d = {csr_wdata[riscv::XLEN-1:8], 7'b0, csr_wdata[0]};
                end
                riscv::CSR_SCOUNTEREN:         scounteren_d = {{riscv::XLEN-32{1'b0}}, csr_wdata[31:0]};
                riscv::CSR_SSCRATCH:           sscratch_d   = csr_wdata;
                riscv::CSR_SEPC:               sepc_d       = {csr_wdata[riscv::XLEN-1:1], 1'b0};
                riscv::CSR_SCAUSE:             scause_d     = csr_wdata;
                riscv::CSR_STVAL:              stval_d      = csr_wdata;
                // supervisor address translation and protection
                riscv::CSR_SATP: begin
                    // intercept SATP writes if in S-Mode and TVM is enabled
                    if (priv_lvl_o == riscv::PRIV_LVL_S && mstatus_q.tvm)
                        update_access_exception = 1'b1;
                    else begin
                        satp      = riscv::satp_t'(csr_wdata);
                        // only make ASID_LEN - 1 bit stick, that way software can figure out how many ASID bits are supported
                        satp.asid = satp.asid & {{(riscv::ASIDW-AsidWidth){1'b0}}, {AsidWidth{1'b1}}};
                        // only update if we actually support this mode
                        if (riscv::vm_mode_t'(satp.mode) == riscv::ModeOff ||
                            riscv::vm_mode_t'(satp.mode) == riscv::MODE_SV) satp_d = satp;
                    end
                    // changing the mode can have side-effects on address translation (e.g.: other instructions), re-fetch
                    // the next instruction by executing a flush
                    flush_o = 1'b1;
                end
                riscv::CSR_SENVCFG: begin
                    mask = ariane_pkg::ENVCFG_WRITE_MASK[riscv::XLEN-1:0];
                    senvcfg_d = (senvcfg_q & ~mask) | (csr_wdata & mask);
                    // this instruction has side-effects
                    flush_o = 1'b1;
                end
                //hypervisor mode registers
                riscv::CSR_HSTATUS: begin
                    if(~ariane_pkg::RVH) begin 
                        update_access_exception = 1'b1;
                    end else begin 
                        mask = ariane_pkg::HSTATUS_WRITE_MASK[riscv::XLEN-1:0];
                        hstatus_d = (hstatus_q & ~{{64-riscv::XLEN{1'b0}}, mask}) | {{64-riscv::XLEN{1'b0}}, (csr_wdata & mask)};
                        // this instruction has side-effects
                        flush_o = 1'b1;
                    end
                end
                riscv::CSR_HEDELEG: begin
                    if(~ariane_pkg::RVH) begin 
                        update_access_exception = 1'b1;
                    end else begin 
                        mask = (1 << riscv::INSTR_ADDR_MISALIGNED) |
                           (1 << riscv::INSTR_ACCESS_FAULT) |
                           (1 << riscv::ILLEGAL_INSTR) |
                           (1 << riscv::BREAKPOINT) |
                           (1 << riscv::LD_ADDR_MISALIGNED) |
                           (1 << riscv::LD_ACCESS_FAULT) |
                           (1 << riscv::ST_ADDR_MISALIGNED) |
                           (1 << riscv::ST_ACCESS_FAULT) |
                           (1 << riscv::ENV_CALL_UMODE) |
                           (1 << riscv::INSTR_PAGE_FAULT) |
                           (1 << riscv::LOAD_PAGE_FAULT) |
                           (1 << riscv::STORE_PAGE_FAULT);
                        hedeleg_d = (hedeleg_q & ~mask) | (csr_wdata & mask);
                    end
                end
                riscv::CSR_HIDELEG: begin
                    if(~ariane_pkg::RVH) begin 
                        update_access_exception = 1'b1;
                    end else begin 
                        hideleg_d = (hideleg_q & ~VS_DELEG_INTERRUPTS) | (csr_wdata & VS_DELEG_INTERRUPTS);
                    end
                end
                riscv::CSR_HIE: begin
                    if(~ariane_pkg::RVH) begin 
                        update_access_exception = 1'b1;
                    end else begin 
                        mask = HS_DELEG_INTERRUPTS;
                        mie_d = (mie_q & ~mask) | (csr_wdata & mask);
                    end
                end
                riscv::CSR_HIP: begin
                    if(~ariane_pkg::RVH) begin 
                        update_access_exception = 1'b1;
                    end else begin 
                        mask = riscv::MIP_VSSIP;
                        mip_d = (mip_q & ~mask) | (csr_wdata & mask);
                    end
                end
                riscv::CSR_HVIP: begin
                    if(~ariane_pkg::RVH) begin 
                        update_access_exception = 1'b1;
                    end else begin 
                        mask = VS_DELEG_INTERRUPTS;
                        mip_d = (mip_q & ~mask) | (csr_wdata & mask);
                    end
                end
                riscv::CSR_HCOUNTEREN: begin
                    if(~ariane_pkg::RVH) begin 
                        update_access_exception = 1'b1;
                    end else begin 
                        hcounteren_d = {{riscv::XLEN-32{1'b0}}, csr_wdata[31:0]};
                    end
                end
                riscv::CSR_HTVAL: begin
                    if(~ariane_pkg::RVH) begin 
                        update_access_exception = 1'b1;
                    end else begin 
                        htval_d = csr_wdata;
                    end
                end
                riscv::CSR_HTINST: begin
                    if(~ariane_pkg::RVH) begin 
                        update_access_exception = 1'b1;
                    end else begin 
                        htinst_d = {{riscv::XLEN-32{1'b0}}, csr_wdata[31:0]};
                    end
                end
                //TODO Hyp: implement hgeie write
                riscv::CSR_HGEIE: begin
                    if(~ariane_pkg::RVH) begin 
                        update_access_exception = 1'b1;
                    end
                end
                riscv::CSR_HGATP: begin
                    if(~ariane_pkg::RVH) begin 
                        update_access_exception = 1'b1;
                    end else begin
                        // intercept HGATP writes if in HS-Mode and TVM is enabled
                        if (priv_lvl_o == riscv::PRIV_LVL_S && !v_q && mstatus_q.tvm)
                            update_access_exception = 1'b1;
                        else begin
                            hgatp      = riscv::hgatp_t'(csr_wdata);
                            //hardwire PPN[1:0] to zero
                            hgatp[1:0] = 2'b0;
                            // only make VMID_LEN - 1 bit stick, that way software can figure out how many VMID bits are supported
                            hgatp.vmid = hgatp.vmid & {{(riscv::VMIDW-VmidWidth){1'b0}}, {VmidWidth{1'b1}}};
                            // only update if we actually support this mode
                            if (riscv::vm_mode_t'(hgatp.mode) == riscv::ModeOff ||
                                riscv::vm_mode_t'(hgatp.mode) == riscv::MODE_SV) hgatp_d = hgatp;
                        end
                        // changing the mode can have side-effects on address translation (e.g.: other instructions), re-fetch
                        // the next instruction by executing a flush
                        flush_o = 1'b1;
                    end
                end
                riscv::CSR_HENVCFG: begin
                    if(~ariane_pkg::RVH) begin 
                        update_access_exception = 1'b1;
                    end else begin
                        mask = ariane_pkg::ENVCFG_WRITE_MASK[riscv::XLEN-1:0];
                        henvcfg_d = (henvcfg_q & ~mask) | (csr_wdata & mask);
                        henvcfg_d.pbmte = menvcfg_q.pbmte ? henvcfg_d.pbmte : 1'b0;
                        // this instruction has side-effects
                        flush_o = 1'b1;
                    end
                end
                riscv::CSR_MSTATUS: begin
                    mstatus_d      = {{64-riscv::XLEN{1'b0}}, csr_wdata};
                    mstatus_d.xs   = riscv::Off;
                    if (!FP_PRESENT) begin
                        mstatus_d.fs = riscv::Off;
                    end
                    mstatus_d.upie = 1'b0;
                    mstatus_d.uie  = 1'b0;
                    // this register has side-effects on other registers, flush the pipeline
                    flush_o        = 1'b1;
                end
                // MISA is WARL (Write Any Value, Reads Legal Value)
                riscv::CSR_MISA:;
                // machine exception delegation register
                // 0 - 15 exceptions supported
                riscv::CSR_MEDELEG: begin
                    mask = (1 << riscv::INSTR_ADDR_MISALIGNED) |
                           (1 << riscv::INSTR_ACCESS_FAULT) |
                           (1 << riscv::ILLEGAL_INSTR) |
                           (1 << riscv::BREAKPOINT) |
                           (1 << riscv::LD_ADDR_MISALIGNED) |
                           (1 << riscv::LD_ACCESS_FAULT) |
                           (1 << riscv::ST_ADDR_MISALIGNED) |
                           (1 << riscv::ST_ACCESS_FAULT) |
                           (1 << riscv::ENV_CALL_UMODE) |
                           (ariane_pkg::RVH << riscv::ENV_CALL_VSMODE) |
                           (1 << riscv::INSTR_PAGE_FAULT) |
                           (1 << riscv::LOAD_PAGE_FAULT) |
                           (1 << riscv::STORE_PAGE_FAULT) |
                           (ariane_pkg::RVH << riscv::INSTR_GUEST_PAGE_FAULT) |
                           (ariane_pkg::RVH << riscv::LOAD_GUEST_PAGE_FAULT) |
                           (ariane_pkg::RVH << riscv::VIRTUAL_INSTRUCTION) |
                           (ariane_pkg::RVH << riscv::STORE_GUEST_PAGE_FAULT);
                    medeleg_d = (medeleg_q & ~mask) | (csr_wdata & mask);
                end
                // machine interrupt delegation register
                // we do not support user interrupt delegation
                riscv::CSR_MIDELEG: begin
                    mask = riscv::MIP_SSIP | riscv::MIP_STIP | riscv::MIP_SEIP;
                    if(~ariane_pkg::RVH) begin
                        mideleg_d = (mideleg_q & ~mask) | (csr_wdata & mask);
                    end else begin
                        mideleg_d = (mideleg_q & ~mask) | (csr_wdata & mask) | HS_DELEG_INTERRUPTS;
                    end
                end
                // mask the register so that unsupported interrupts can never be set
                riscv::CSR_MIE: begin
                    if(~ariane_pkg::RVH) begin
                         mask = riscv::MIP_SSIP | riscv::MIP_STIP | riscv::MIP_SEIP | riscv::MIP_MSIP | riscv::MIP_MTIP | riscv::MIP_MEIP;
                    end else begin
                        mask = HS_DELEG_INTERRUPTS | riscv::MIP_SSIP | riscv::MIP_STIP | riscv::MIP_SEIP | riscv::MIP_MSIP | riscv::MIP_MTIP | riscv::MIP_MEIP;
                    end
                    mie_d = (mie_q & ~mask) | (csr_wdata & mask); // we only support supervisor and M-mode interrupts
                end

                riscv::CSR_MTVEC: begin
                    mtvec_d = {csr_wdata[riscv::XLEN-1:2], 1'b0, csr_wdata[0]};
                    // we are in vector mode, this implementation requires the additional
                    // alignment constraint of 64 * 4 bytes
                    if (csr_wdata[0]) mtvec_d = {csr_wdata[riscv::XLEN-1:8], 7'b0, csr_wdata[0]};
                end
                riscv::CSR_MCOUNTEREN:         mcounteren_d = {{riscv::XLEN-32{1'b0}}, csr_wdata[31:0]};

                riscv::CSR_MSCRATCH:           mscratch_d  = csr_wdata;
                riscv::CSR_MEPC:               mepc_d      = {csr_wdata[riscv::XLEN-1:1], 1'b0};
                riscv::CSR_MCAUSE:             mcause_d    = csr_wdata;
                riscv::CSR_MTVAL:              mtval_d     = csr_wdata;
                riscv::CSR_MTINST: begin
                    if(~ariane_pkg::RVH) begin 
                        update_access_exception = 1'b1;
                    end else begin 
                        mtinst_d    = {{riscv::XLEN-32{1'b0}}, csr_wdata[31:0]};
                    end
                end
                riscv::CSR_MTVAL2: begin
                    if(~ariane_pkg::RVH) begin 
                        update_access_exception = 1'b1;
                    end else begin 
                        mtval2_d    = csr_wdata;
                    end
                end
                riscv::CSR_MENVCFG: begin
                    mask = ariane_pkg::ENVCFG_WRITE_MASK[riscv::XLEN-1:0];
                    menvcfg_d = (menvcfg_q & ~mask) | (csr_wdata & mask);
                    // this instruction has side-effects
                    flush_o = 1'b1;
                end
                riscv::CSR_MIP: begin
                    if (~ariane_pkg::RVH) begin
                        mask = riscv::MIP_SSIP | riscv::MIP_STIP | riscv::MIP_SEIP;
                    end else begin
                        mask = riscv::MIP_SSIP | riscv::MIP_STIP | riscv::MIP_SEIP | riscv::MIP_VSSIP;
                    end
                    mip_d = (mip_q & ~mask) | (csr_wdata & mask);
                end
                // Smaia and Ssaia
                riscv::CSR_MISELECT: miselect_d = csr_wdata[7:0];
                riscv::CSR_MIREG: begin
                    case (miselect_q) inside
                        [8'h30 : 8'h3F]: begin
                            // Do nothing, iprio array not implemented yet
                        end
                        [8'h70 : 8'hFF]: begin
                            `ifdef MSI_MODE
                            wimsic_addr         = {{riscv::XLEN-8{1'b0}}, miselect_q}; 
                            wimsic_priv_lvl     = riscv::PRIV_LVL_M;
                            wimsic_vgein        = '0;
                            imsic_data_o        = csr_wdata;
                            imsic_we_o          = 1'b1;
                            `else
                            update_access_exception = 1'b1;
                            `endif
                        end 
                        default: update_access_exception = 1'b1;
                    endcase
                end
                `ifdef MSI_MODE
                riscv::CSR_MTOPIE: begin
                    wimsic_priv_lvl     = riscv::PRIV_LVL_M;
                    imsic_claim_o       = 1'b1; 
                end
                `endif
                riscv::CSR_MVIEN:;  // Do nothing, not supported by openSBI
                riscv::CSR_MVIP:;   // Do nothing, not supported by openSBI
                riscv::CSR_SISELECT: siselect_d  = csr_wdata[7:0];
                riscv::CSR_SIREG: begin
                    case (siselect_q) inside
                        [8'h30 : 8'h3F]: begin
                            // Do nothing, iprio array not implemented yet
                        end
                        [8'h70 : 8'hFF]: begin
                            `ifdef MSI_MODE
                            wimsic_addr         = {{riscv::XLEN-8{1'b0}}, siselect_q}; 
                            wimsic_priv_lvl     = riscv::PRIV_LVL_S;
                            wimsic_vgein        = '0;
                            imsic_data_o        = csr_wdata;
                            imsic_we_o          = 1'b1;
                            `else
                            update_access_exception = 1'b1;
                            `endif
                        end 
                        default: update_access_exception = 1'b1;
                    endcase
                end
                `ifdef MSI_MODE
                riscv::CSR_STOPIE: begin
                    wimsic_priv_lvl     = riscv::PRIV_LVL_S;
                    imsic_claim_o       = 1'b1;
                end
                `endif
                riscv::CSR_VSISELECT: begin
                    if(~ariane_pkg::RVH) begin 
                        update_access_exception = 1'b1;
                    end else begin
                        vsiselect_d = csr_wdata[7:0];
                    end
                end
                riscv::CSR_VSIREG: begin
                    if(~ariane_pkg::RVH) begin 
                        update_access_exception = 1'b1;
                    end else begin
                        case (vsiselect_q) inside
                            [8'h70 : 8'hFF]: begin
                                `ifdef MSI_MODE
                                wimsic_addr         = {{riscv::XLEN-8{1'b0}}, vsiselect_q}; 
                                wimsic_priv_lvl     = riscv::PRIV_LVL_S;
                                wimsic_vgein        = hstatus_q.vgein[ariane_pkg::NrVSIntpFilesW:0];
                                imsic_data_o        = csr_wdata;
                                imsic_we_o          = 1'b1;
                                `else
                                virtual_update_access_exception = 1'b1;
                                `endif
                            end 
                            default: virtual_update_access_exception = 1'b1;
                        endcase
                    end
                end
                riscv::CSR_HVIEN: begin
                    if(~ariane_pkg::RVH) begin 
                        update_access_exception = 1'b1;
                    end else begin
                        /** Do nothing, not supported yet */
                    end
                end
                riscv::CSR_HVICTL: begin
                    if(~ariane_pkg::RVH) begin 
                        update_access_exception = 1'b1;
                    end else begin
                        /** Do nothing, not supported yet */
                    end
                end
                riscv::CSR_HVIPRIO1: begin
                    if(~ariane_pkg::RVH) begin 
                        update_access_exception = 1'b1;
                    end else begin
                        /** Do nothing, not supported yet */
                    end
                end
                riscv::CSR_HVIPRIO2: begin
                    if(~ariane_pkg::RVH) begin 
                        update_access_exception = 1'b1;
                    end else begin
                        /** Do nothing, not supported yet */
                    end
                end
                `ifdef MSI_MODE
                riscv::CSR_VSTOPEI: begin
                    if(~ariane_pkg::RVH) begin 
                        update_access_exception = 1'b1;
                    end else begin
                        wimsic_priv_lvl     = riscv::PRIV_LVL_S;
                        wimsic_vgein        = hstatus_q.vgein[ariane_pkg::NrVSIntpFilesW:0];
                        imsic_claim_o       = 1'b1; 
                    end
                end
                `endif
                // performance counters
                riscv::CSR_MCYCLE:             cycle_d[riscv::XLEN-1:0] = csr_wdata;
                riscv::CSR_MCYCLEH:            if (riscv::XLEN == 32) cycle_d[63:32] = csr_wdata; else update_access_exception = 1'b1;
                riscv::CSR_MINSTRET:           instret[riscv::XLEN-1:0] = csr_wdata;
                riscv::CSR_MINSTRETH:          if (riscv::XLEN == 32) instret[63:32] = csr_wdata; else update_access_exception = 1'b1;
                riscv::CSR_ML1_ICACHE_MISS,
                riscv::CSR_ML1_DCACHE_MISS,
                riscv::CSR_MITLB_MISS,
                riscv::CSR_MDTLB_MISS,
                riscv::CSR_MLOAD,
                riscv::CSR_MSTORE,
                riscv::CSR_MEXCEPTION,
                riscv::CSR_MEXCEPTION_RET,
                riscv::CSR_MBRANCH_JUMP,
                riscv::CSR_MCALL,
                riscv::CSR_MRET,
                riscv::CSR_MMIS_PREDICT,
                riscv::CSR_MSB_FULL,
                riscv::CSR_MIF_EMPTY,
                riscv::CSR_MHPM_COUNTER_17,
                riscv::CSR_MHPM_COUNTER_18,
                riscv::CSR_MHPM_COUNTER_19,
                riscv::CSR_MHPM_COUNTER_20,
                riscv::CSR_MHPM_COUNTER_21,
                riscv::CSR_MHPM_COUNTER_22,
                riscv::CSR_MHPM_COUNTER_23,
                riscv::CSR_MHPM_COUNTER_24,
                riscv::CSR_MHPM_COUNTER_25,
                riscv::CSR_MHPM_COUNTER_26,
                riscv::CSR_MHPM_COUNTER_27,
                riscv::CSR_MHPM_COUNTER_28,
                riscv::CSR_MHPM_COUNTER_29,
                riscv::CSR_MHPM_COUNTER_30,
                riscv::CSR_MHPM_COUNTER_31: begin
                                        perf_data_o = csr_wdata;
                                        perf_we_o   = 1'b1;
                end

                riscv::CSR_DCACHE:             dcache_d    = {{riscv::XLEN-1{1'b0}}, csr_wdata[0]}; // enable bit
                riscv::CSR_ICACHE:             icache_d    = {{riscv::XLEN-1{1'b0}}, csr_wdata[0]}; // enable bit
                // PMP locked logic
                // 1. refuse to update any locked entry
                // 2. also refuse to update the entry below a locked TOR entry
                // Note that writes to pmpcfg below a locked TOR entry are valid
                riscv::CSR_PMPCFG0:    for (int i = 0; i < (riscv::XLEN/8); i++) if (!pmpcfg_q[i].locked) pmpcfg_d[i]  = csr_wdata[i*8+:8];
                riscv::CSR_PMPCFG1: begin
                    if (riscv::XLEN == 32) begin
                        for (int i = 0; i < 4; i++) if (!pmpcfg_q[i+4].locked) pmpcfg_d[i+4]  = csr_wdata[i*8+:8];
                    end
                end
                riscv::CSR_PMPCFG2:    for (int i = 0; i < (riscv::XLEN/8); i++) if (!pmpcfg_q[i+8].locked) pmpcfg_d[i+8]  = csr_wdata[i*8+:8];
                riscv::CSR_PMPCFG3: begin
                    if (riscv::XLEN == 32) begin
                        for (int i = 0; i < 4; i++) if (!pmpcfg_q[i+12].locked) pmpcfg_d[i+12]  = csr_wdata[i*8+:8];
                    end
                end
                riscv::CSR_PMPADDR0,
                riscv::CSR_PMPADDR1,
                riscv::CSR_PMPADDR2,
                riscv::CSR_PMPADDR3,
                riscv::CSR_PMPADDR4,
                riscv::CSR_PMPADDR5,
                riscv::CSR_PMPADDR6,
                riscv::CSR_PMPADDR7,
                riscv::CSR_PMPADDR8,
                riscv::CSR_PMPADDR9,
                riscv::CSR_PMPADDR10,
                riscv::CSR_PMPADDR11,
                riscv::CSR_PMPADDR12,
                riscv::CSR_PMPADDR13,
                riscv::CSR_PMPADDR14,
                riscv::CSR_PMPADDR15:  begin
                    // index is specified by the last byte in the address
                    automatic int index = csr_addr.csr_decode.address[3:0];
                    // check if the entry or the entry above is locked
                    if (!pmpcfg_q[index].locked && !(pmpcfg_q[index].locked && pmpcfg_q[index].addr_mode == riscv::TOR)) begin
                        pmpaddr_d[index] = csr_wdata[riscv::PLEN-3:0];
                    end
                end
                default: update_access_exception = 1'b1;
            endcase
        end

        mstatus_d.sxl  = riscv::XLEN_64;
        mstatus_d.uxl  = riscv::XLEN_64;
        if (ariane_pkg::RVH) begin
            hstatus_d.vsxl = riscv::XLEN_64;
            vsstatus_d.uxl = riscv::XLEN_64;
        end
        // mark the floating point extension register as dirty
        if (FP_PRESENT && (dirty_fp_state_csr || dirty_fp_state_i)) begin
            mstatus_d.fs = riscv::Dirty;
            if (ariane_pkg::RVH && v_q) begin
                vsstatus_d.fs = riscv::Dirty;
            end
        end
        // hardwired extension registers
        mstatus_d.sd   = (mstatus_q.xs == riscv::Dirty) | (mstatus_q.fs == riscv::Dirty);
        if (ariane_pkg::RVH) begin
            vsstatus_d.sd  = (vsstatus_q.xs == riscv::Dirty) | (vsstatus_q.fs == riscv::Dirty);
        end

        // write the floating point status register
        if (csr_write_fflags_i) begin
            fcsr_d.fflags = csr_wdata_i[4:0] | fcsr_q.fflags;
        end
        // ---------------------
        // External Interrupts
        // ---------------------
        // Machine Mode External Interrupt Pending
        mip_d[riscv::IRQ_M_EXT] = irq_i[0];
        // Machine software interrupt
        mip_d[riscv::IRQ_M_SOFT] = ipi_i;
        // Timer interrupt pending, coming from platform timer
        mip_d[riscv::IRQ_M_TIMER] = time_irq_i;
        
        // Deboker1 (01/04/2023): We dont support > 1 VS interrupt files yet 
        if (ariane_pkg::NrIntpFiles == 3) begin
            // Virtual Supervisor Mode External Interrupt Pending 
            mip_d[riscv::IRQ_VS_EXT] = irq_i[2];
        end

        // -----------------------
        // Manage Exception Stack
        // -----------------------
        // update exception CSRs
        // we got an exception update cause, pc and stval register
        trap_to_priv_lvl = riscv::PRIV_LVL_M;
        trap_to_v        = 1'b0;
        // Exception is taken and we are not in debug mode
        // exceptions in debug mode don't update any fields
        if (!debug_mode_q && ex_i.cause != riscv::DEBUG_REQUEST && ex_i.valid) begin
            // do not flush, flush is reserved for CSR writes with side effects
            flush_o   = 1'b0;
            // figure out where to trap to
            // a m-mode trap might be delegated if we are taking it in S mode
            // first figure out if this was an exception or an interrupt e.g.: look at bit (XLEN-1)
            // the cause register can only be $clog2(riscv::XLEN) bits long (as we only support XLEN exceptions)
            if (ariane_pkg::RVH) begin
                if ((ex_i.cause[riscv::XLEN-1] && mideleg_q[ex_i.cause[$clog2(riscv::XLEN)-1:0]] && ~hideleg_q[ex_i.cause[$clog2(riscv::XLEN)-1:0]]) ||
                    (~ex_i.cause[riscv::XLEN-1] && medeleg_q[ex_i.cause[$clog2(riscv::XLEN)-1:0]] && ~hedeleg_q[ex_i.cause[$clog2(riscv::XLEN)-1:0]])) begin
                    // traps never transition from a more-privileged mode to a less privileged mode
                    // so if we are already in M mode, stay there
                    trap_to_priv_lvl = (priv_lvl_o == riscv::PRIV_LVL_M) ? riscv::PRIV_LVL_M : riscv::PRIV_LVL_S;
                end else if ((ex_i.cause[riscv::XLEN-1] && hideleg_q[ex_i.cause[$clog2(riscv::XLEN)-1:0]]) ||
                        (~ex_i.cause[riscv::XLEN-1] && hedeleg_q[ex_i.cause[$clog2(riscv::XLEN)-1:0]])) begin
                    trap_to_priv_lvl = (priv_lvl_o == riscv::PRIV_LVL_M) ? riscv::PRIV_LVL_M : riscv::PRIV_LVL_S;
                    // trap to VS only if it is  the currently active mode
                    trap_to_v   = v_q;
                end
            end else begin
                if ((ex_i.cause[riscv::XLEN-1] && mideleg_q[ex_i.cause[$clog2(riscv::XLEN)-1:0]]) ||
                    (~ex_i.cause[riscv::XLEN-1] && medeleg_q[ex_i.cause[$clog2(riscv::XLEN)-1:0]])) begin
                    // traps never transition from a more-privileged mode to a less privileged mode
                    // so if we are already in M mode, stay there
                    trap_to_priv_lvl = (priv_lvl_o == riscv::PRIV_LVL_M) ? riscv::PRIV_LVL_M : riscv::PRIV_LVL_S;
            end
            end

            // trap to supervisor mode
            if (trap_to_priv_lvl == riscv::PRIV_LVL_S) begin
                if (ariane_pkg::RVH && trap_to_v) begin
                    // update sstatus
                    vsstatus_d.sie  = 1'b0;
                    vsstatus_d.spie = vsstatus_q.sie;
                    // this can either be user or supervisor mode
                    vsstatus_d.spp  = priv_lvl_q[0];
                    // set cause
                    vscause_d       = ex_i.cause[riscv::XLEN-1] ? {ex_i.cause[riscv::XLEN-1:2],2'b01} : ex_i.cause;
                    // set epc
                    vsepc_d         = {{riscv::XLEN-riscv::VLEN{pc_i[riscv::VLEN-1]}},pc_i};
                    // set vstval
                    vstval_d        = (ariane_pkg::ZERO_TVAL
                                      && (ex_i.cause inside {
                                        riscv::ILLEGAL_INSTR,
                                        riscv::BREAKPOINT,
                                        riscv::ENV_CALL_UMODE
                                      } || ex_i.cause[riscv::XLEN-1])) ? '0 : ex_i.tval;
                end else begin
                    // update sstatus
                    mstatus_d.sie  = 1'b0;
                    mstatus_d.spie = mstatus_q.sie;
                    // this can either be user or supervisor mode
                    mstatus_d.spp  = priv_lvl_q[0];
                    // set cause
                    scause_d       = ex_i.cause;
                    // set epc
                    sepc_d         = {{riscv::XLEN-riscv::VLEN{pc_i[riscv::VLEN-1]}},pc_i};
                    // set mtval or stval
                    stval_d        = (ariane_pkg::ZERO_TVAL
                                      && (ex_i.cause inside {
                                        riscv::ILLEGAL_INSTR,
                                        riscv::BREAKPOINT,
                                        riscv::ENV_CALL_UMODE,
                                        riscv::ENV_CALL_SMODE,
                                        riscv::ENV_CALL_MMODE
                                      } || ex_i.cause[riscv::XLEN-1])) ? '0 : ex_i.tval;
                    if (ariane_pkg::RVH) begin             
                        htinst_d       = (ariane_pkg::ZERO_TVAL
                                          && (ex_i.cause inside {
                                            riscv::INSTR_ACCESS_FAULT,
                                            riscv::ILLEGAL_INSTR,
                                            riscv::BREAKPOINT,
                                            riscv::ENV_CALL_UMODE,
                                            riscv::ENV_CALL_SMODE,
                                            riscv::ENV_CALL_MMODE,
                                            riscv::INSTR_PAGE_FAULT,
                                            riscv::INSTR_GUEST_PAGE_FAULT,
                                            riscv::VIRTUAL_INSTRUCTION
                                          } || ex_i.cause[riscv::XLEN-1])) ? '0 : ex_i.tinst;
                        hstatus_d.spvp = v_q ? priv_lvl_q[0] : hstatus_d.spvp;
                        htval_d        = ex_i.tval2 >> 2;
                        hstatus_d.gva  = ex_i.gva;
                        hstatus_d.spv  = v_q;
                    end
                end
            // trap to machine mode
            end else begin
                // update mstatus
                mstatus_d.mie  = 1'b0;
                mstatus_d.mpie = mstatus_q.mie;
                // save the previous privilege mode
                mstatus_d.mpp  = priv_lvl_q;
                mcause_d       = ex_i.cause;
                // set epc
                mepc_d         = {{riscv::XLEN-riscv::VLEN{pc_i[riscv::VLEN-1]}},pc_i};
                // set mtval or stval
                mtval_d        = (ariane_pkg::ZERO_TVAL
                                  && (ex_i.cause inside {
                                    riscv::ILLEGAL_INSTR,
                                    riscv::BREAKPOINT,
                                    riscv::ENV_CALL_UMODE,
                                    riscv::ENV_CALL_SMODE,
                                    riscv::ENV_CALL_MMODE
                                  } || ex_i.cause[riscv::XLEN-1])) ? '0 : ex_i.tval;
                if (ariane_pkg::RVH) begin
                    // save previous virtualization mode
                    mstatus_d.mpv  = v_q;
                    mtinst_d       = (ariane_pkg::ZERO_TVAL
                                      && (ex_i.cause inside {
                                        riscv::INSTR_ADDR_MISALIGNED,
                                        riscv::INSTR_ACCESS_FAULT,
                                        riscv::ILLEGAL_INSTR,
                                        riscv::BREAKPOINT,
                                        riscv::ENV_CALL_UMODE,
                                        riscv::ENV_CALL_SMODE,
                                        riscv::ENV_CALL_MMODE,
                                        riscv::INSTR_PAGE_FAULT,
                                        riscv::INSTR_GUEST_PAGE_FAULT,
                                        riscv::VIRTUAL_INSTRUCTION
                                      } || ex_i.cause[riscv::XLEN-1])) ? '0 : ex_i.tinst;
                    mtval2_d       = ex_i.tval2 >> 2;
                    mstatus_d.gva  = ex_i.gva;
                end
            end

            priv_lvl_d = trap_to_priv_lvl;
            if (ariane_pkg::RVH) begin
                v_d        = trap_to_v;
            end
        end

        // ------------------------------
        // Debug
        // ------------------------------
        // Explains why Debug Mode was entered.
        // When there are multiple reasons to enter Debug Mode in a single cycle, hardware should set cause to the cause with the highest priority.
        // 1: An ebreak instruction was executed. (priority 3)
        // 2: The Trigger Module caused a breakpoint exception. (priority 4)
        // 3: The debugger requested entry to Debug Mode. (priority 2)
        // 4: The hart single stepped because step was set. (priority 1)
        // we are currently not in debug mode and could potentially enter
        if (!debug_mode_q) begin
            dcsr_d.prv = priv_lvl_o;
            // save virtualization mode bit
            dcsr_d.v   = v_q;
            // trigger module fired

            // caused by a breakpoint
            if (ex_i.valid && ex_i.cause == riscv::BREAKPOINT) begin
                dcsr_d.prv = priv_lvl_o;
                // save virtualization mode bit
                dcsr_d.v   = v_q;
                // check that we actually want to enter debug depending on the privilege level we are currently in
                unique case (priv_lvl_o)
                    riscv::PRIV_LVL_M: begin
                        debug_mode_d = dcsr_q.ebreakm;
                        set_debug_pc_o = dcsr_q.ebreakm;
                    end
                    riscv::PRIV_LVL_S: begin
                        debug_mode_d = v_q ? dcsr_q.ebreakvs : dcsr_q.ebreaks;
                        set_debug_pc_o = v_q ? dcsr_q.ebreakvs : dcsr_q.ebreaks;
                    end
                    riscv::PRIV_LVL_U: begin
                        debug_mode_d = v_q ? dcsr_q.ebreakvu : dcsr_q.ebreaku;
                        set_debug_pc_o = v_q ? dcsr_q.ebreakvu : dcsr_q.ebreaku;
                    end
                    default:;
                endcase
                // save PC of next this instruction e.g.: the next one to be executed
                dpc_d = {{riscv::XLEN-riscv::VLEN{pc_i[riscv::VLEN-1]}},pc_i};
                dcsr_d.cause = ariane_dm_pkg::CauseBreakpoint;
            end

            // we've got a debug request
            if (ex_i.valid && ex_i.cause == riscv::DEBUG_REQUEST) begin
                dcsr_d.prv = priv_lvl_o;
                // save virtualization mode bit
                dcsr_d.v   = v_q;
                // save the PC
                dpc_d = {{riscv::XLEN-riscv::VLEN{pc_i[riscv::VLEN-1]}},pc_i};
                // enter debug mode
                debug_mode_d = 1'b1;
                // jump to the base address
                set_debug_pc_o = 1'b1;
                // save the cause as external debug request
                dcsr_d.cause = ariane_dm_pkg::CauseRequest;
            end

            // single step enable and we just retired an instruction
            if (dcsr_q.step && commit_ack_i[0]) begin
                dcsr_d.prv = priv_lvl_o;
                // save virtualization mode bit
                dcsr_d.v   = v_q;
                // valid CTRL flow change
                if (commit_instr_i[0].fu == CTRL_FLOW) begin
                    // we saved the correct target address during execute
                    dpc_d = {{riscv::XLEN-riscv::VLEN{commit_instr_i[0].bp.predict_address[riscv::VLEN-1]}}, commit_instr_i[0].bp.predict_address};
                // exception valid
                end else if (ex_i.valid) begin
                    dpc_d = {{riscv::XLEN-riscv::VLEN{1'b0}},trap_vector_base_o};
                // return from environment
                end else if (eret_o) begin
                    dpc_d = {{riscv::XLEN-riscv::VLEN{1'b0}},epc_o};
                // consecutive PC
                end else begin
                    dpc_d = {{riscv::XLEN-riscv::VLEN{commit_instr_i[0].pc[riscv::VLEN-1]}}, commit_instr_i[0].pc + (commit_instr_i[0].is_compressed ? 'h2 : 'h4)};
                end
                debug_mode_d = 1'b1;
                set_debug_pc_o = 1'b1;
                dcsr_d.cause = ariane_dm_pkg::CauseSingleStep;
            end
        end
        // go in halt-state again when we encounter an exception
        if (debug_mode_q && ex_i.valid && ex_i.cause == riscv::BREAKPOINT) begin
            set_debug_pc_o = 1'b1;
        end

        // ------------------------------
        // MPRV - Modify Privilege Level
        // ------------------------------
        // Set the address translation at which the load and stores should occur
        // we can use the previous values since changing the address translation will always involve a pipeline flush
        if (ariane_pkg::RVH) begin
            if (mprv && (mstatus_q.mpv == 1'b0) && (riscv::vm_mode_t'(satp_q.mode) == riscv::MODE_SV) && (mstatus_q.mpp != riscv::PRIV_LVL_M)) begin
                en_ld_st_translation_d = 1'b1;
            end else if (mprv && (mstatus_q.mpv == 1'b1)) begin
                if (riscv::vm_mode_t'(vsatp_q.mode) == riscv::MODE_SV) begin
                    en_ld_st_translation_d = 1'b1;
                end else begin
                    en_ld_st_translation_d = 1'b0;
                end
            end else begin // otherwise we go with the regular settings
                en_ld_st_translation_d = en_translation_o;
            end

            if(mprv && (mstatus_q.mpv == 1'b1)) begin
                if(riscv::vm_mode_t'(hgatp_q.mode) == riscv::MODE_SV) begin
                    en_ld_st_g_translation_d = 1'b1;
                end else begin
                    en_ld_st_g_translation_d = 1'b0;
                end
            end else begin
                en_ld_st_g_translation_d = en_g_translation_o;
            end

            if(csr_hs_ld_st_inst_i)
                ld_st_priv_lvl_o = riscv::priv_lvl_t'(hstatus_q.spvp);
            else
                ld_st_priv_lvl_o = (mprv) ? mstatus_q.mpp : priv_lvl_o;

            ld_st_v_o = ((mprv ? mstatus_q.mpv : v_q ) || (csr_hs_ld_st_inst_i));

            en_ld_st_translation_o = (en_ld_st_translation_q && !csr_hs_ld_st_inst_i) || (riscv::vm_mode_t'(vsatp_q.mode) == riscv::MODE_SV && csr_hs_ld_st_inst_i);

            en_ld_st_g_translation_o = (en_ld_st_g_translation_q && !csr_hs_ld_st_inst_i) || (csr_hs_ld_st_inst_i && riscv::vm_mode_t'(hgatp_q.mode) == riscv::MODE_SV && csr_hs_ld_st_inst_i);
        end else begin
            if (mprv && riscv::vm_mode_t'(satp_q.mode) == riscv::MODE_SV && (mstatus_q.mpp != riscv::PRIV_LVL_M))
                en_ld_st_translation_d = 1'b1;
            else // otherwise we go with the regular settings
                en_ld_st_translation_d = en_translation_o;

            ld_st_priv_lvl_o = (mprv) ? mstatus_q.mpp : priv_lvl_o;
            en_ld_st_translation_o = en_ld_st_translation_q;
            ld_st_v_o = 1'b0;
            en_ld_st_g_translation_o = 1'b0;
        end
        // ------------------------------
        // Return from Environment
        // ------------------------------
        // When executing an xRET instruction, supposing xPP holds the value y, xIE is set to xPIE; the privilege
        // mode is changed to y; xPIE is set to 1; and xPP is set to U
        if (mret) begin
            // return from exception, IF doesn't care from where we are returning
            eret_o = 1'b1;
            // return to the previous privilege level and restore all enable flags
            // get the previous machine interrupt enable flag
            mstatus_d.mie  = mstatus_q.mpie;
            // restore the previous privilege level
            priv_lvl_d     = mstatus_q.mpp;
            // set mpp to user mode
            mstatus_d.mpp  = riscv::PRIV_LVL_U;
            // set mpie to 1
            mstatus_d.mpie = 1'b1;
            if (ariane_pkg::RVH) begin
                // set virtualization mode
                v_d            = mstatus_q.mpv;
                //set mstatus mpv to false
                mstatus_d.mpv  = 1'b0;
                if(mstatus_q.mpp != riscv::PRIV_LVL_M)
                    mstatus_d.mprv = 1'b0;
            end
        end

        if (sret && ((ariane_pkg::RVH && !v_q) || !ariane_pkg::RVH)) begin
            // return from exception, IF doesn't care from where we are returning
            eret_o = 1'b1;
            // return the previous supervisor interrupt enable flag
            mstatus_d.sie  = mstatus_q.spie;
            // restore the previous privilege level
            priv_lvl_d     = riscv::priv_lvl_t'({1'b0, mstatus_q.spp});
            // set spp to user mode
            mstatus_d.spp  = 1'b0;
            // set spie to 1
            mstatus_d.spie = 1'b1;
            if(ariane_pkg::RVH) begin
                // set virtualization mode
                v_d            = hstatus_q.spv;
                //set hstatus spv to false
                hstatus_d.spv  = 1'b0;
                mstatus_d.mprv = 1'b0;
            end
        end

        if (ariane_pkg::RVH && sret && v_q) begin
            // return from exception, IF doesn't care from where we are returning
            eret_o = 1'b1;
            // return the previous supervisor interrupt enable flag
            vsstatus_d.sie  = vsstatus_q.spie;
            // restore the previous privilege level
            priv_lvl_d     = riscv::priv_lvl_t'({1'b0, vsstatus_q.spp});
            // set spp to user mode
            vsstatus_d.spp  = 1'b0;
            // set spie to 1
            vsstatus_d.spie = 1'b1;
        end

        // return from debug mode
        if (dret) begin
            // return from exception, IF doesn't care from where we are returning
            eret_o = 1'b1;
            // restore the previous privilege level
            priv_lvl_d     = riscv::priv_lvl_t'(dcsr_q.prv);
            // restore the previous virtualization mode
            v_d            = dcsr_q.v;
            // actually return from debug mode
            debug_mode_d = 1'b0;
        end
    end

    // ---------------------------
    // IMSIC Output assign
    // ---------------------------
    /** Give priority to writes */
    `ifdef MSI_MODE
    assign imsic_addr_o        = ((imsic_we_o == 1'b1) || (imsic_claim_o == 1'b1) ) ? wimsic_addr    : rimsic_addr;
    assign imsic_priv_lvl_o    = ((imsic_we_o == 1'b1) || (imsic_claim_o == 1'b1) ) ? wimsic_priv_lvl: rimsic_priv_lvl;
    assign imsic_vgein_o       = ((imsic_we_o == 1'b1) || (imsic_claim_o == 1'b1) ) ? wimsic_vgein   : rimsic_vgein;
    `endif

    // ---------------------------
    // CSR OP Select Logic
    // ---------------------------
    always_comb begin : csr_op_logic
        csr_wdata = csr_wdata_i;
        csr_we    = 1'b1;
        csr_read  = 1'b1;
        mret      = 1'b0;
        sret      = 1'b0;
        dret      = 1'b0;

        unique case (csr_op_i)
            CSR_WRITE: csr_wdata = csr_wdata_i;
            CSR_SET:   csr_wdata = csr_wdata_i | csr_rdata;
            CSR_CLEAR: csr_wdata = (~csr_wdata_i) & csr_rdata;
            CSR_READ:  csr_we    = 1'b0;
            SRET: begin
                // the return should not have any write or read side-effects
                csr_we   = 1'b0;
                csr_read = 1'b0;
                sret     = 1'b1; // signal a return from supervisor mode or virtual supervisor mode
            end
            MRET: begin
                // the return should not have any write or read side-effects
                csr_we   = 1'b0;
                csr_read = 1'b0;
                mret     = 1'b1; // signal a return from machine mode
            end
            DRET: begin
                // the return should not have any write or read side-effects
                csr_we   = 1'b0;
                csr_read = 1'b0;
                dret     = 1'b1; // signal a return from debug mode
            end
            default: begin
                csr_we   = 1'b0;
                csr_read = 1'b0;
            end
        endcase
        // if we are violating our privilges do not update the architectural state
        if (privilege_violation) begin
            csr_we = 1'b0;
            csr_read = 1'b0;
        end
    end

    assign irq_ctrl_o.mie = mie_q;
    assign irq_ctrl_o.mip = mip_q;
    assign irq_ctrl_o.sie = v_q ? vsstatus_q.sie : mstatus_q.sie;
    assign irq_ctrl_o.mideleg = mideleg_q;
    assign irq_ctrl_o.hideleg = (ariane_pkg::RVH) ? hideleg_q : '0;
    assign irq_ctrl_o.global_enable = (~debug_mode_q)
                                    // interrupts are enabled during single step or we are not stepping
                                    & (~dcsr_q.step | dcsr_q.stepie)
                                    & ((mstatus_q.mie & (priv_lvl_o == riscv::PRIV_LVL_M))
                                    | (priv_lvl_o != riscv::PRIV_LVL_M));

    always_comb begin : privilege_check
        if(ariane_pkg::RVH) begin
            automatic riscv::priv_lvl_t access_priv;
            automatic riscv::priv_lvl_t curr_priv;
            // transforms S mode accesses into HS mode
            access_priv = (priv_lvl_o == riscv::PRIV_LVL_S && !v_q) ? riscv::PRIV_LVL_HS : priv_lvl_o;
            curr_priv = priv_lvl_o;
            // -----------------
            // Privilege Check
            // -----------------
            privilege_violation = 1'b0;
            virtual_privilege_violation = 1'b0;
            // if we are reading or writing, check for the correct privilege level this has
            // precedence over interrupts
            if (csr_op_i inside {CSR_WRITE, CSR_SET, CSR_CLEAR, CSR_READ}) begin
                if (access_priv < csr_addr.csr_decode.priv_lvl) begin
                    if(v_q && csr_addr.csr_decode.priv_lvl == riscv::PRIV_LVL_HS)
                        virtual_privilege_violation = 1'b1;
                    else
                        privilege_violation = 1'b1;
                end
                // check access to debug mode only CSRs
                if (csr_addr_i[11:4] == 8'h7b && !debug_mode_q) begin
                    privilege_violation = 1'b1;
                end
                // check counter-enabled counter CSR accesses
                // counter address range is C00 to C1F
                if (csr_addr_i inside {[riscv::CSR_CYCLE:riscv::CSR_HPM_COUNTER_31]}) begin
                    unique case (curr_priv)
                        riscv::PRIV_LVL_M: privilege_violation = 1'b0;
                        riscv::PRIV_LVL_S: begin
                            virtual_privilege_violation = v_q & mcounteren_q[csr_addr_i[4:0]] & ~hcounteren_q[csr_addr_i[4:0]];
                            privilege_violation = ~mcounteren_q[csr_addr_i[4:0]];
                        end
                        riscv::PRIV_LVL_U: begin
                            virtual_privilege_violation = v_q & mcounteren_q[csr_addr_i[4:0]] & ~hcounteren_q[csr_addr_i[4:0]];
                            if(v_q) begin
                                privilege_violation = ~mcounteren_q[csr_addr_i[4:0]] & ~scounteren_q[csr_addr_i[4:0]] & hcounteren_q[csr_addr_i[4:0]];
                            end else begin
                                privilege_violation = ~mcounteren_q[csr_addr_i[4:0]] & ~scounteren_q[csr_addr_i[4:0]];
                            end
                        end
                    endcase
                end
            end
        end else begin
            // -----------------
            // Privilege Check
            // -----------------
            privilege_violation = 1'b0;
            // if we are reading or writing, check for the correct privilege level this has
            // precedence over interrupts
            if (csr_op_i inside {CSR_WRITE, CSR_SET, CSR_CLEAR, CSR_READ}) begin
                if ((riscv::priv_lvl_t'(priv_lvl_o & csr_addr.csr_decode.priv_lvl) != csr_addr.csr_decode.priv_lvl)) begin
                    privilege_violation = 1'b1;
                end
                // check access to debug mode only CSRs
                if (csr_addr_i[11:4] == 8'h7b && !debug_mode_q) begin
                    privilege_violation = 1'b1;
                end
                // check counter-enabled counter CSR accesses
                // counter address range is C00 to C1F
                if (csr_addr_i inside {[riscv::CSR_CYCLE:riscv::CSR_HPM_COUNTER_31]}) begin
                    unique case (priv_lvl_o)
                        riscv::PRIV_LVL_M: privilege_violation = 1'b0;
                        riscv::PRIV_LVL_S: privilege_violation = ~mcounteren_q[csr_addr_i[4:0]];
                        riscv::PRIV_LVL_U: privilege_violation = ~mcounteren_q[csr_addr_i[4:0]] & ~scounteren_q[csr_addr_i[4:0]];
                    endcase
                end
            end
        end    
    end
    // ----------------------
    // CSR Exception Control
    // ----------------------
    always_comb begin : exception_ctrl
        csr_exception_o = {
            '0, '0, '0, '0, 1'b0, 1'b0
        };
        // ----------------------------------
        // Illegal Access (decode exception)
        // ----------------------------------
        // we got an exception in one of the processes above
        // throw an illegal instruction exception
        if (update_access_exception || read_access_exception) begin
            csr_exception_o.cause = riscv::ILLEGAL_INSTR;
            // we don't set the tval field as this will be set by the commit stage
            // this spares the extra wiring from commit to CSR and back to commit
            csr_exception_o.valid = 1'b1;
        end

        if (privilege_violation) begin
          csr_exception_o.cause = riscv::ILLEGAL_INSTR;
          csr_exception_o.valid = 1'b1;
        end

        if (ariane_pkg::RVH && (virtual_update_access_exception || virtual_read_access_exception || virtual_privilege_violation)) begin
            csr_exception_o.cause = riscv::VIRTUAL_INSTRUCTION;
            csr_exception_o.valid = 1'b1;
        end
    end

    // -------------------
    // Wait for Interrupt
    // -------------------
    always_comb begin : wfi_ctrl
        // wait for interrupt register
        wfi_d = wfi_q;
        // if there is any (enabled) interrupt pending un-stall the core
        // also un-stall if we want to enter debug mode
        if (|(mip_q & mie_q) || debug_req_i || irq_i[1]) begin
            wfi_d = 1'b0;
        // or alternatively if there is no exception pending and we are not in debug mode wait here
        // for the interrupt
        end else if (!debug_mode_q && csr_op_i == WFI && !ex_i.valid) begin
            wfi_d = 1'b1;
        end
    end

    // output assignments dependent on privilege mode
    always_comb begin : priv_output
        trap_vector_base_o = {mtvec_q[riscv::VLEN-1:2], 2'b0};
        // output user mode stvec
        if (trap_to_priv_lvl == riscv::PRIV_LVL_S) begin
            trap_vector_base_o = (ariane_pkg::RVH && trap_to_v) ? {vstvec_q[riscv::VLEN-1:2], 2'b0} : {stvec_q[riscv::VLEN-1:2], 2'b0};
        end

        // if we are in debug mode jump to a specific address
        if (debug_mode_q) begin
            trap_vector_base_o = DmBaseAddress[riscv::VLEN-1:0] + ariane_dm_pkg::ExceptionAddress[riscv::VLEN-1:0];
        end

        // check if we are in vectored mode, if yes then do BASE + 4 * cause we
        // are imposing an additional alignment-constraint of 64 * 4 bytes since
        // we want to spare the costly addition. Furthermore check to which
        // privilege level we are jumping and whether the vectored mode is
        // activated for _that_ privilege level.
       unique case(trap_to_priv_lvl)
            riscv::PRIV_LVL_M: begin
                if (mtvec_q[0] && ex_i.cause[riscv::XLEN-1]) begin
                    trap_vector_base_o[7:2] = ex_i.cause[5:0];
                end
            end
            riscv::PRIV_LVL_S: begin
                if(ariane_pkg::RVH && trap_to_v) begin
                    if (vstvec_q[0] && ex_i.cause[riscv::XLEN-1]) begin
                        trap_vector_base_o[7:2] = {ex_i.cause[5:2],2'b01};
                    end
                end else begin
                    if (stvec_q[0] && ex_i.cause[riscv::XLEN-1]) begin
                        trap_vector_base_o[7:2] = ex_i.cause[5:0];
                    end
                end
            end
        endcase

        epc_o = mepc_q[riscv::VLEN-1:0];
        // we are returning from supervisor or virtual supervisor mode, so take the sepc register
        if (sret) begin
            epc_o = (ariane_pkg::RVH && v_q) ? vsepc_q[riscv::VLEN-1:0] : sepc_q[riscv::VLEN-1:0];
        end
        // we are returning from debug mode, to take the dpc register
        if (dret) begin
            epc_o = dpc_q[riscv::VLEN-1:0];
        end
    end

    // -------------------
    // Output Assignments
    // -------------------
    always_comb begin
        // When the SEIP bit is read with a CSRRW, CSRRS, or CSRRC instruction, the value
        // returned in the rd destination register contains the logical-OR of the software-writable
        // bit and the interrupt signal from the interrupt controller.
        csr_rdata_o = csr_rdata;

        unique case (conv_csr_addr.address)
            riscv::CSR_MIP: csr_rdata_o = csr_rdata | (irq_i[1] << riscv::IRQ_S_EXT);
            // in supervisor mode we also need to check whether we delegated this bit
            riscv::CSR_SIP: csr_rdata_o = csr_rdata | ((irq_i[1] & mideleg_q[riscv::IRQ_S_EXT]) << riscv::IRQ_S_EXT);
            default:;
        endcase
    end

    // in debug mode we execute with privilege level M
    assign priv_lvl_o       = (debug_mode_q) ? riscv::PRIV_LVL_M : priv_lvl_q;
    assign v_o              = ariane_pkg::RVH ? v_q : 1'b0;
    // FPU outputs
    assign fflags_o         = fcsr_q.fflags;
    assign frm_o            = fcsr_q.frm;
    assign fprec_o          = fcsr_q.fprec;
    // MMU outputs
    assign satp_ppn_o       = satp_q.ppn;
    assign vsatp_ppn_o      = ariane_pkg::RVH ? vsatp_q.ppn : '0;
    assign hgatp_ppn_o      = ariane_pkg::RVH ? hgatp_q.ppn : '0;
    assign asid_o           = satp_q.asid[AsidWidth-1:0];
    assign vs_asid_o        = ariane_pkg::RVH ? vsatp_q.asid[AsidWidth-1:0] : '0;
    assign vmid_o           = ariane_pkg::RVH ? hgatp_q.vmid[VmidWidth-1:0] : '0;
    assign sum_o            = mstatus_q.sum;
    assign vs_sum_o         = ariane_pkg::RVH ? vsstatus_q.sum : '0;
    assign hu_o             = ariane_pkg::RVH ? hstatus_q.hu : '0;
    // we support bare memory addressing and SV39
    if(ariane_pkg::RVH) begin
        assign en_translation_o = ((((riscv::vm_mode_t'(satp_q.mode) == riscv::MODE_SV && !v_q) || (riscv::vm_mode_t'(vsatp_q.mode) == riscv::MODE_SV && v_q)) &&
                                   priv_lvl_o != riscv::PRIV_LVL_M)
                                  ? 1'b1
                                  : 1'b0);
        assign en_g_translation_o = (riscv::vm_mode_t'(hgatp_q.mode) == riscv::MODE_SV &&
                                   priv_lvl_o != riscv::PRIV_LVL_M && v_q)
                                  ? 1'b1
                                  : 1'b0;
    end else begin
        assign en_translation_o    = (riscv::vm_mode_t'(satp_q.mode) == riscv::MODE_SV &&
                                  priv_lvl_o != riscv::PRIV_LVL_M)
                                 ? 1'b1
                                 : 1'b0;
        assign en_g_translation_o  = 1'b0;
    end
    assign mxr_o            = mstatus_q.mxr;
    assign vmxr_o           = ariane_pkg::RVH ? vsstatus_q.mxr : '0;
    assign tvm_o            = (ariane_pkg::RVH && v_q) ? hstatus_q.vtvm : mstatus_q.tvm;
    assign tw_o             = mstatus_q.tw;
    assign vtw_o            = ariane_pkg::RVH ? hstatus_q.vtw : '0;
    assign tsr_o            = (ariane_pkg::RVH && v_q) ? hstatus_q.vtsr : mstatus_q.tsr;
    assign halt_csr_o       = wfi_q;
`ifdef PITON_ARIANE
    assign icache_en_o      = icache_q[0];
`else
    assign icache_en_o      = icache_q[0] & (~debug_mode_q);
`endif
    assign dcache_en_o      = dcache_q[0];

    // determine if mprv needs to be considered if in debug mode
    assign mprv             = (debug_mode_q && !dcsr_q.mprven) ? 1'b0 : mstatus_q.mprv;
    assign debug_mode_o     = debug_mode_q;
    assign single_step_o    = dcsr_q.step;

    // sequential process
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (~rst_ni) begin
            priv_lvl_q             <= riscv::PRIV_LVL_M;
            v_q                    <= '0;
            // floating-point registers
            fcsr_q                 <= '0;
            // debug signals
`ifdef DROMAJO
            debug_mode_q           <= 1'b1;
`else
            debug_mode_q           <= 1'b0;
`endif
            dcsr_q                 <= '0;
            dcsr_q.prv             <= riscv::PRIV_LVL_M;
            dcsr_q.xdebugver       <= 4'h4;
            dpc_q                  <= '0;
            dscratch0_q            <= {riscv::XLEN{1'b0}};
            dscratch1_q            <= {riscv::XLEN{1'b0}};
            // machine mode registers
            mstatus_q              <= 64'b0;
            // set to boot address + direct mode + 4 byte offset which is the initial trap
            mtvec_rst_load_q       <= 1'b1;
            mtvec_q                <= '0;
            medeleg_q              <= {riscv::XLEN{1'b0}};
            mideleg_q              <= {riscv::XLEN{1'b0}};
            mip_q                  <= {riscv::XLEN{1'b0}};
            mie_q                  <= {riscv::XLEN{1'b0}};
            mepc_q                 <= {riscv::XLEN{1'b0}};
            mcause_q               <= {riscv::XLEN{1'b0}};
            mcounteren_q           <= {riscv::XLEN{1'b0}};
            mscratch_q             <= {riscv::XLEN{1'b0}};
            mtval_q                <= {riscv::XLEN{1'b0}};
            mtval2_q               <= {riscv::XLEN{1'b0}};
            mtinst_q               <= {riscv::XLEN{1'b0}};
            menvcfg_q              <= {riscv::XLEN{1'b0}};
            senvcfg_q              <= {riscv::XLEN{1'b0}};
            dcache_q               <= {{riscv::XLEN-1{1'b0}}, 1'b1};
            icache_q               <= {{riscv::XLEN-1{1'b0}}, 1'b1};
            // AIA
            miselect_q             <= '0;
            siselect_q             <= '0;
            vsiselect_q            <= '0;
            // supervisor mode registers
            sepc_q                 <= {riscv::XLEN{1'b0}};
            scause_q               <= {riscv::XLEN{1'b0}};
            stvec_q                <= {riscv::XLEN{1'b0}};
            scounteren_q           <= {riscv::XLEN{1'b0}};
            sscratch_q             <= {riscv::XLEN{1'b0}};
            stval_q                <= {riscv::XLEN{1'b0}};
            satp_q                 <= {riscv::XLEN{1'b0}};
            hstatus_q              <= {riscv::XLEN{1'b0}};
            hedeleg_q              <= {riscv::XLEN{1'b0}};
            hideleg_q              <= {riscv::XLEN{1'b0}};
            hgeie_q                <= {riscv::XLEN{1'b0}};
            hgatp_q                <= {riscv::XLEN{1'b0}};
            hcounteren_q           <= {riscv::XLEN{1'b0}};
            htval_q                <= {riscv::XLEN{1'b0}};
            htinst_q               <= {riscv::XLEN{1'b0}};
            henvcfg_q              <= {riscv::XLEN{1'b0}};
            // virtual supervisor mode registers
            vsstatus_q              <= 64'b0;
            vsepc_q                 <= {riscv::XLEN{1'b0}};
            vscause_q               <= {riscv::XLEN{1'b0}};
            vstvec_q                <= {riscv::XLEN{1'b0}};
            vsscratch_q             <= {riscv::XLEN{1'b0}};
            vstval_q                <= {riscv::XLEN{1'b0}};
            vsatp_q                 <= {riscv::XLEN{1'b0}};
            // timer and counters
            cycle_q                <= {riscv::XLEN{1'b0}};
            instret_q              <= {riscv::XLEN{1'b0}};
            // aux registers
            en_ld_st_translation_q <= 1'b0;
            en_ld_st_g_translation_q <= 1'b0;
            // wait for interrupt
            wfi_q                  <= 1'b0;
            // pmp
            pmpcfg_q               <= '0;
            pmpaddr_q              <= '0;
        end else begin
            priv_lvl_q             <= priv_lvl_d;
            v_q                    <= v_d;
            // floating-point registers
            fcsr_q                 <= fcsr_d;
            // debug signals
            debug_mode_q           <= debug_mode_d;
            dcsr_q                 <= dcsr_d;
            dpc_q                  <= dpc_d;
            dscratch0_q            <= dscratch0_d;
            dscratch1_q            <= dscratch1_d;
            // machine mode registers
            mstatus_q              <= mstatus_d;
            mtvec_rst_load_q       <= 1'b0;
            mtvec_q                <= mtvec_d;
            medeleg_q              <= medeleg_d;
            mideleg_q              <= mideleg_d;
            mip_q                  <= mip_d;
            mie_q                  <= mie_d;
            mepc_q                 <= mepc_d;
            mcause_q               <= mcause_d;
            mcounteren_q           <= mcounteren_d;
            mscratch_q             <= mscratch_d;
            mtval_q                <= mtval_d;
            mtval2_q               <= mtval2_d;
            mtinst_q               <= mtinst_d;
            menvcfg_q              <= menvcfg_d;
            senvcfg_q              <= senvcfg_d;
            dcache_q               <= dcache_d;
            icache_q               <= icache_d;
            // AIA
            miselect_q             <= miselect_d;
            siselect_q             <= siselect_d;
            vsiselect_q            <= vsiselect_d;
            // supervisor mode registers
            sepc_q                 <= sepc_d;
            scause_q               <= scause_d;
            stvec_q                <= stvec_d;
            scounteren_q           <= scounteren_d;
            sscratch_q             <= sscratch_d;
            stval_q                <= stval_d;
            satp_q                 <= satp_d;
            // hypervisor mode registers
            hstatus_q              <= hstatus_d;
            hedeleg_q              <= hedeleg_d;
            hideleg_q              <= hideleg_d;
            hgeie_q                <= hgeie_d;
            hgatp_q                <= hgatp_d;
            hcounteren_q           <= hcounteren_d;
            htval_q                <= htval_d;
            htinst_q               <= htinst_d;
            henvcfg_q              <= henvcfg_d;
            // virtual supervisor mode registers
            vsstatus_q              <= vsstatus_d;
            vsepc_q                 <= vsepc_d;
            vscause_q               <= vscause_d;
            vstvec_q                <= vstvec_d;
            vsscratch_q             <= vsscratch_d;
            vstval_q                <= vstval_d;
            vsatp_q                 <= vsatp_d;
            // timer and counters
            cycle_q                <= cycle_d;
            instret_q              <= instret_d;
            // aux registers
            en_ld_st_translation_q <= en_ld_st_translation_d;
            en_ld_st_g_translation_q <= en_ld_st_g_translation_d;
            // wait for interrupt
            wfi_q                  <= wfi_d;
            // pmp
            for(int i = 0; i < 16; i++) begin
                if(i < NrPMPEntries) begin
                    // We only support >=8-byte granularity, NA4 is disabled
                    if(pmpcfg_d[i].addr_mode != riscv::NA4 && !(pmpcfg_d[i].access_type.r == '0 && pmpcfg_d[i].access_type.w == '1)) begin
                        pmpcfg_q[i] <= pmpcfg_d[i];
                    end else begin
                        pmpcfg_q[i] <= pmpcfg_q[i];
                    end
                    pmpaddr_q[i] <= pmpaddr_d[i];
                end else begin
                    pmpcfg_q[i] <= '0;
                    pmpaddr_q[i] <= '0;
                end
            end
        end
    end

    //-------------
    // Assertions
    //-------------
    //pragma translate_off
    `ifndef VERILATOR
        // check that eret and ex are never valid together
        assert property (
          @(posedge clk_i) disable iff (!rst_ni !== '0) !(eret_o && ex_i.valid))
        else begin $error("eret and exception should never be valid at the same time"); $stop(); end
    `endif
    //pragma translate_on
endmodule
