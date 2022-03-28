// Author: Bruno Sá, UMinho
// Date: 21.4.2022
// Description: Translation Lookaside Buffer, SV39
//              Indexed set-associative 


module l2_tlb import ariane_pkg::*; #(
      parameter int unsigned TLB_ENTRIES_4K = 128,
      parameter int unsigned TLB_WAYS_4k    = 4,
      parameter int unsigned TLB_ENTRIES_2M = 32,
      parameter int unsigned TLB_WAYS_2M    = 4,
      parameter int unsigned ASID_WIDTH     = 1,
      parameter int unsigned VMID_WIDTH     = 1
  )(
    input  logic                    clk_i,           // Clock
    input  logic                    rst_ni,          // Asynchronous reset active low
    input  logic                    flush_i,         // Flush normal translations signal
    input  logic                    flush_vvma_i,    // Flush vs stage signal
    input  logic                    flush_gvma_i,    // Flush g stage signal
    // From PTW
    input  logic                    l2_tlb_access_i,
    input  tlb_update_t             l2_tlb_update_i, // L2 TLB update information
    input  l2_tlb_req_t             l2_tlb_req_i,    // L2 TLB request from PTW
    // To PTW
    output l2_tlb_resp_t            l2_tlb_resp_o,   // L2 TLB response to PTW
    output logic                    l2_tlb_hit_o,    
    output logic                    l2_tlb_flushing_o // L2 TLB is flushing
);
    // 4K L2 TLB control signals
    tlb_update_t    l2_tlb_4k_update;
    l2_tlb_resp_t   l2_tlb_4k_resp;
    logic           l2_tlb_4k_hit;
    logic           l2_tlb_4k_flushing;

    // 2M L2 TLB control signals
    tlb_update_t    l2_tlb_2m_update;
    l2_tlb_resp_t   l2_tlb_2m_resp;
    logic           l2_tlb_2m_hit;
    logic           l2_tlb_2m_flushing;

    //Assignments
    assign l2_tlb_resp_o      = (l2_tlb_4k_hit) ? l2_tlb_4k_resp : (l2_tlb_2m_hit) ? l2_tlb_2m_resp : '0;
    assign l2_tlb_hit_o       = (l2_tlb_4k_hit | l2_tlb_2m_hit);
    assign l2_tlb_flushing_o  = (l2_tlb_4k_flushing | l2_tlb_2m_flushing);

    // --------------------
    // L2 TLB 4k Generation
    // --------------------

    if (L2_TLB_4K_PRESENT && (riscv::XLEN == 64)) begin : gen_l2_tlb_4k

    assign l2_tlb_4k_update = ((l2_tlb_update_i.is_s_2M && (l2_tlb_update_i.is_g_2M || l2_tlb_update_i.is_g_1G)) || (l2_tlb_update_i.is_g_2M && (l2_tlb_update_i.is_s_2M || l2_tlb_update_i.is_s_1G)))  ? '0 : l2_tlb_update_i;

        set_tlb #(
            .TLB_ENTRIES          ( TLB_ENTRIES_4K              ),
            .TLB_WAYS             ( TLB_WAYS_4k                 ),
            .TLB_LVL              ( 0                           ),
            .ASID_WIDTH           ( ASID_WIDTH                  ),
            .VMID_WIDTH           ( VMID_WIDTH                  )
        ) set_tlb_4k (
            .clk_i                ( clk_i                       ),
            .rst_ni               ( rst_ni                      ),
            .flush_i              ( flush_i                     ),
            .flush_vvma_i         ( flush_vvma_i                ),
            .flush_gvma_i         ( flush_gvma_i                ),

            .update_i             ( l2_tlb_4k_update            ),
            .req_i                ( l2_tlb_req_i                ),
            .resp_o               ( l2_tlb_4k_resp              ),
            .flushing_o           ( l2_tlb_4k_flushing          ),

            .lu_access_i          ( l2_tlb_access_i             ),
            .lu_hit_o             ( l2_tlb_4k_hit               )
        );
    end else begin

        assign l2_tlb_4k_update   = '0;
        assign l2_tlb_4k_resp     = '0;
        assign l2_tlb_4k_hit      = 1'b0;
        assign l2_tlb_4k_flushing = 1'b0;

    end

    // --------------------
    // L2 TLB 2M Generation
    // --------------------

    if (L2_TLB_2M_PRESENT && (riscv::XLEN == 64)) begin : gen_l2_tlb_2M

        assign l2_tlb_2m_update = ((l2_tlb_update_i.is_s_2M && (l2_tlb_update_i.is_g_2M || l2_tlb_update_i.is_g_1G)) || (l2_tlb_update_i.is_g_2M && (l2_tlb_update_i.is_s_2M || l2_tlb_update_i.is_s_1G))) ? l2_tlb_update_i : '0;

       set_tlb #(
            .TLB_ENTRIES          ( TLB_ENTRIES_2M              ),
            .TLB_WAYS             ( TLB_WAYS_2M                 ),
            .TLB_LVL              ( 1                           ),
            .ASID_WIDTH           ( ASID_WIDTH                  ),
            .VMID_WIDTH           ( VMID_WIDTH                  )
        ) set_tlb_2m (
            .clk_i                ( clk_i                       ),
            .rst_ni               ( rst_ni                      ),
            .flush_i              ( flush_i                     ),
            .flush_vvma_i         ( flush_vvma_i                ),
            .flush_gvma_i         ( flush_gvma_i                ),

            .update_i             ( l2_tlb_2m_update            ),
            .req_i                ( l2_tlb_req_i                ),
            .resp_o               ( l2_tlb_2m_resp              ),
            .flushing_o           ( l2_tlb_2m_flushing          ),

            .lu_access_i          ( l2_tlb_access_i             ),
            .lu_hit_o             ( l2_tlb_2m_hit               )
        );
    end else begin
        
        assign l2_tlb_2m_update   = '0;
        assign l2_tlb_2m_resp     = '0;
        assign l2_tlb_2m_hit      = 1'b0;
        assign l2_tlb_2m_flushing = 1'b0;

    end

endmodule