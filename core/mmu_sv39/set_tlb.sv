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
// Author: David Schaffenrath, TU Graz
// Author: Florian Zaruba, ETH Zurich
// Author: Bruno Sá, UMinho
// Date: 21.4.2022
// Description: Translation Lookaside Buffer, SV39
//              Indexed set-associative 


module set_tlb import ariane_pkg::*; #(
      parameter int unsigned TLB_ENTRIES = 4,
      parameter int unsigned TLB_WAYS    = 64,
      parameter int unsigned TLB_LVL     = 0,      // by default 0 -> 4k page size 
      parameter int unsigned ASID_WIDTH  = 1,
      parameter int unsigned VMID_WIDTH  = 1,
      // DO NOT OVERWRITE THESE PARAMETER
      parameter int unsigned TLB_SETS   = (TLB_ENTRIES / TLB_WAYS),
      parameter int unsigned IDX_BITS   = $clog2(TLB_SETS),
      parameter int unsigned TAG_BITS   = (riscv::SVX - (12 + (TLB_LVL * 9) + $clog2(TLB_SETS))),
      parameter int unsigned IDX_OFFSET_BITS = (12 + (TLB_LVL * 9)),
      parameter int unsigned TAG_OFFSET_BITS = (IDX_OFFSET_BITS + $clog2(TLB_SETS)),
      parameter ariane_pkg::ariane_cfg_t ArianeCfg = ariane_pkg::ArianeDefaultConfig
  )(
    input  logic                    clk_i,          // Clock
    input  logic                    rst_ni,         // Asynchronous reset active low
    input  logic                    flush_i,        // Flush s-stage translations
    input  logic                    flush_vvma_i,   // Flush vs-stage translations
    input  logic                    flush_gvma_i,   // Flush g-stage translations
    // Update TLB L2
    input   tlb_update_t            update_i,       // PTW updates TLB
    input   l2_tlb_req_t            req_i,          // PTW requests a TLB translation
    output  l2_tlb_resp_t           resp_o,         // TLB responds to PTW 
    output logic                    flushing_o,     // TLB is flushing 
    // Lookup signals
    input  logic                    lu_access_i,
    output logic                    lu_hit_o
);

    // TLB FSM
    enum logic[2:0] {
      FLUSH,
      IDLE,
      READ,
      UPDATE
    } state_q, state_d;

    // Tag structure
    typedef struct packed {
      logic [ASID_WIDTH-1:0] asid;
      logic [VMID_WIDTH-1:0] vmid;
      logic [TAG_BITS-1:0]   vpn;
      logic                  is_s_2M;
      logic                  is_s_1G;
      logic                  is_g_2M;
      logic                  is_g_1G;
      logic                  s_st_enbl;   // s-stage translation
      logic                  g_st_enbl;   // g-stage translation
      logic                  v;           // virtualization mode
    } tlb_tag_t;

    // Control signals
    l2_tlb_req_t                                 req_n, req_q; // request translation from PTW
    logic                                        wr_enbl; // control signal enables tlb writes
    logic                                        rd_enbl; // control signal enables tlb reads
    logic [IDX_BITS-1:0]                         lu_index; // decodes index to read from vaddr
    logic [TAG_BITS-1:0]                         lu_tag; // decodes vaddr tag based on the page size and index bits
    logic [TLB_WAYS-1:0]                         lu_hit; // hit array
    logic [$clog2(TLB_WAYS)-1:0]                 lu_hit_idx; // decodes hit way index from hit array

    // Update control signals
    tlb_tag_t                                    update_tag; // incoming update tag
    logic [TLB_WAYS-1:0]                         replace_en;  // replace the following entry, set by replacement strategy
    logic [IDX_BITS-1:0]                         update_index; // update write index
    logic [TLB_WAYS-1:0]                         update_way; // one hot encoding of way to replace

    // Flush control signals
    logic                                        flush_enbl; // flush is enabled
    logic                                        flush_end; // all entries have been flushed
    logic [IDX_BITS-1:0]                         flush_cnt_d, flush_cnt_q; // next set to be flushed

    // Tag Ram interface
    logic [TLB_WAYS-1:0]                         tag_vld_req; // request to tag array
    logic                                        tag_vld_we; // write enable to tag array
    logic [IDX_BITS-1:0]                         tag_vld_addr; // address to read from tag array
    logic [TLB_WAYS-1:0]                         tag_vld_wdata; // write data valid bit
    tlb_tag_t [TLB_WAYS-1:0]                     tag_rdata; // tag packed read data
    logic [TLB_WAYS-1:0]                         tag_vld_rdata; // tag read data valid
    logic [TLB_WAYS-1:0][$bits(tlb_tag_t):0]     vld_tag_rdata; // tag unpacked read data + valid bit

    // Content Ram interface
    logic [TLB_WAYS-1:0]                         content_vld_req; // request to S-stage content array
    logic                                        content_vld_we;  // write enable to  S-stage content array
    logic [63:0]                                 content_wdata;   // write data to S-stage content array
    logic [63:0]                                 gcontent_wdata;  // write data to G-stage content array
    logic [TLB_WAYS-1:0][63:0]                   content_rdata;   // read unpacked data to S-stage content array
    logic [TLB_WAYS-1:0][63:0]                   gcontent_rdata;  // read unpacked data to G-stage content array
    riscv::pte_t [TLB_WAYS-1:0]                  gcontent;        // read pte to S-stage content array
    riscv::pte_t [TLB_WAYS-1:0]                  content;         // read pte to G-stage content array


    // assignments
    // decode lookup index and tag
    assign lu_index          = req_i.vaddr[(IDX_OFFSET_BITS+(IDX_BITS-1)):IDX_OFFSET_BITS];
    assign lu_tag            = req_i.vaddr[(30+riscv::GPPN2):TAG_OFFSET_BITS];

    // logic for tag array memory interface
    assign tag_vld_req       = (rd_enbl || flush_enbl) ? '1 : update_way;
    assign tag_vld_we        = (wr_enbl | flush_enbl);
    assign tag_vld_addr      = (flush_enbl) ? flush_cnt_q : lu_index;
    assign tag_vld_wdata     = (wr_enbl) ? '1 : '0;


    // logic for content array interface
    assign content_vld_req   = (rd_enbl) ? '1 :
                               (wr_enbl) ? update_way :
                               '0;
    assign content_vld_we    = wr_enbl;
    assign content_wdata     = update_i.content;
    assign gcontent_wdata    = update_i.g_content;
    
    // flush logic
    assign flush_end         = (flush_cnt_q == (TLB_SETS-1));
    assign flush_cnt_d       = (flush_end)   ? '0               :
                               (flush_enbl)  ?  flush_cnt_q + 1 :
                                               flush_cnt_q;

    // update logic 
    assign update_index      = update_i.vpn[(TLB_LVL * 9)+(IDX_BITS-1):(TLB_LVL * 9)];
    assign update_way        = replace_en;

    // active when TLB is flushing
    assign flushing_o = flush_i | flush_vvma_i | flush_gvma_i | flush_enbl;

    // Get index accordingly to the way that hitted
    lzc #(
    .WIDTH       ( TLB_WAYS   )
    ) i_lzc_hit (
        .in_i    ( lu_hit     ),
        .cnt_o   ( lu_hit_idx ),
        .empty_o (            )
    );

    always_comb begin : tlb_fsm
        // default assignments
        state_d         = state_q;
        update_tag      = '{default: 0};
        flush_enbl      = 1'b0;
        rd_enbl         = 1'b0;
        wr_enbl         = 1'b0;
        lu_hit_o        = 1'b0;
        resp_o          = '{default: 0};
        req_n           = req_i;

        unique case (state_q)

        FLUSH: begin
            // flush enabled
            flush_enbl = 1'b1;
            if(flush_end) begin
                // next state IDLE
                state_d = IDLE;
            end
        end

        IDLE: begin
            if(flush_i || flush_vvma_i || flush_gvma_i) begin
                //next state FLUSH
                state_d = FLUSH;
            end else if (update_i.valid) begin
                // enable tlb write
                wr_enbl = 1'b1;
                // decode update tag
                update_tag  = '{  
                  asid:  update_i.s_st_enbl_i ? update_i.asid : 'b0,
                  vmid:  update_i.g_st_enbl_i ? update_i.vmid : 'b0,
                  vpn:  update_i.vpn[28:(TLB_LVL * 9)+IDX_BITS],
                  s_st_enbl:  update_i.s_st_enbl_i,
                  g_st_enbl:  update_i.g_st_enbl_i,
                  v:     update_i.v_i,
                  is_s_1G: update_i.is_s_1G,
                  is_s_2M: update_i.is_s_2M,
                  is_g_1G: update_i.is_g_1G,
                  is_g_2M: update_i.is_g_2M
                };
                //next state UPDATE
                state_d = UPDATE;
                // request valid
            end else if (req_i.valid) begin
                // enable tlb read 
                rd_enbl = 1'b1;
                //next state READ
                state_d = READ;
            end
        end

        READ: begin
            if(flush_i || flush_vvma_i || flush_gvma_i) begin
                //next state FLUSH
                state_d = FLUSH;
            end else if(|lu_hit) begin
                 // send response to PTW
                 resp_o = '{
                         asid:       tag_rdata[lu_hit_idx].asid,
                         vmid:       tag_rdata[lu_hit_idx].vmid,
                         vpn:        {tag_rdata[lu_hit_idx].vpn,req_q.vaddr[(TAG_OFFSET_BITS-1):12]},
                         is_s_1G:    tag_rdata[lu_hit_idx].is_s_1G,
                         is_s_2M:    tag_rdata[lu_hit_idx].is_s_2M,
                         is_g_1G:    tag_rdata[lu_hit_idx].is_g_1G,
                         is_g_2M:    tag_rdata[lu_hit_idx].is_g_2M,
                         content:    content[lu_hit_idx],
                         g_content:  gcontent[lu_hit_idx],
                         valid: 1'b1
                     };
                 // signal we got a it
                 lu_hit_o = 1'b1;
                 state_d = IDLE;
             end else begin
                 state_d = IDLE;
            end
        end

        UPDATE: begin
            if(flush_i || flush_vvma_i || flush_gvma_i) begin
                //next state FLUSH
                state_d = FLUSH;
            end else begin
                state_d = IDLE;
            end
        end

        default: begin
            state_d = FLUSH;
        end
        endcase
    end

    //--------------------
    // Tag Ram Generation
    //--------------------
    
    for (genvar i = 0; i < TLB_WAYS; i++) begin : gen_tag_srams

      assign tag_rdata[i]     = tlb_tag_t'(vld_tag_rdata[i][$bits(tlb_tag_t)-1:0]);
      assign tag_vld_rdata[i] = vld_tag_rdata[i][$bits(tlb_tag_t)];

      tc_sram #(
        // tag + valid bit
        .PrintSimCfg(1'b1),
        .DataWidth  ( $bits(tlb_tag_t) + 1 ),
        .NumWords   ( TLB_SETS     )
      ) i_tag_sram (
        .clk_i     ( clk_i                           ),
        .rst_ni    ( rst_ni                          ),
        .req_i     ( tag_vld_req[i]                  ),
        .we_i      ( tag_vld_we                      ),
        .addr_i    ( tag_vld_addr                    ),
        .wdata_i   ( {tag_vld_wdata[i],update_tag}   ),
        .be_i      ( '1                              ),
        .rdata_o   ( vld_tag_rdata[i]                )
      );
    end

    //----------------
    // Tag comparison
    //----------------
    logic [TLB_WAYS-1:0] match_vmid;
    logic [TLB_WAYS-1:0] match_asid;
    logic [TLB_WAYS-1:0] match_stage;
    logic [TLB_WAYS-1:0] match_tag;

    always_comb begin : tag_comparison
        // default assignment
        lu_hit   = '{default: 0};
        match_asid   = '{default: 0};
        match_vmid   = '{default: 0};
        match_stage  = '{default: 0};
        match_tag    = '{default: 0};

        for (int unsigned i = 0; i < TLB_WAYS; i++) begin
            // first level match, this may be a giga page, check the ASID and VMID flags as well if needed
            // if the entry is associated to a global address, don't match the ASID (ASID is don't care)
            match_asid[i] = (((req_q.asid == tag_rdata[i].asid) || content[i].g) && req_q.s_st_enbl_i) || !req_q.s_st_enbl_i;
            match_vmid[i] = (req_q.vmid == tag_rdata[i].vmid && req_q.g_st_enbl_i) || !req_q.g_st_enbl_i;
            // check if translation is a: S-Stage and G-Stage, S-Stage only or G-Stage only translation and virtualization mode is on/off
            match_stage[i] = tag_rdata[i].g_st_enbl == req_q.g_st_enbl_i && tag_rdata[i].s_st_enbl == req_q.s_st_enbl_i && tag_rdata[i].v == req_q.v_i;
            match_tag[i] = req_q.s_st_enbl_i ? (tag_rdata[i].vpn[(TAG_BITS-3):0] == lu_tag[(TAG_BITS-3):0]) : (tag_rdata[i].vpn == lu_tag);

            if ((state_q == READ && !flush_enbl) && req_q.valid && tag_vld_rdata[i] && match_asid[i] && match_vmid[i] && match_stage[i] && match_tag[i]) begin
                lu_hit[i] = 1'b1;
            end
        end
    end

    //------------------------
    // Content Ram Generation
    //------------------------
    
    // One SRAM for each stage
    for (genvar i = 0; i < TLB_WAYS; i++) begin : gen_content_srams

      assign content[i] = riscv::pte_t'(content_rdata[i]);

      // Content RAM
      tc_sram #(
        // pte size
        .SimInit    ( 1'b1               ),
        .DataWidth  ( 64                 ),
        .NumWords   ( TLB_SETS           )
      ) i_content_sram (
        .clk_i     ( clk_i               ),
        .rst_ni    ( rst_ni              ),
        .req_i     ( content_vld_req[i]  ),
        .we_i      ( content_vld_we      ),
        .addr_i    ( lu_index            ),
        .wdata_i   ( content_wdata       ),
        .be_i      ( '1                  ),
        .rdata_o   ( content_rdata[i]    )
      );
    end

    for (genvar i = 0; i < TLB_WAYS; i++) begin : gen_g_content_srams

      assign gcontent[i] = riscv::pte_t'(gcontent_rdata[i]);

      // Content RAM
      tc_sram #(
        // pte size
        .SimInit    (1'b1),
        .DataWidth  ( 64                 ),
        .NumWords   ( TLB_SETS           )
      ) i_tag_sram (
        .clk_i     ( clk_i               ),
        .rst_ni    ( rst_ni              ),
        .req_i     ( content_vld_req[i]  ),
        .we_i      ( content_vld_we      ),
        .addr_i    ( lu_index            ),
        .wdata_i   ( gcontent_wdata      ),
        .be_i      ( '1                  ),
        .rdata_o   ( gcontent_rdata[i]   )
      );
    end

    // -----------------------------------------------
    // PLRU - Pseudo Least Recently Used Replacement
    // -----------------------------------------------
    logic[TLB_SETS-1:0][2*(TLB_WAYS-1)-1:0] plru_tree_q, plru_tree_n;
    always_comb begin : plru_replacement
        plru_tree_n = plru_tree_q;
        // The PLRU-tree indexing:
        // lvl0        0
        //            / \
        //           /   \
        // lvl1     1     2
        //         / \   / \
        // lvl2   3   4 5   6
        //       / \ /\/\  /\
        //      ... ... ... ...
        // Just predefine which nodes will be set/cleared
        // E.g. for a TLB with 8 entries, the for-loop is semantically
        // equivalent to the following pseudo-code:
        // unique case (1'b1)
        // lu_hit[7]: plru_tree_n[0, 2, 6] = {1, 1, 1};
        // lu_hit[6]: plru_tree_n[0, 2, 6] = {1, 1, 0};
        // lu_hit[5]: plru_tree_n[0, 2, 5] = {1, 0, 1};
        // lu_hit[4]: plru_tree_n[0, 2, 5] = {1, 0, 0};
        // lu_hit[3]: plru_tree_n[0, 1, 4] = {0, 1, 1};
        // lu_hit[2]: plru_tree_n[0, 1, 4] = {0, 1, 0};
        // lu_hit[1]: plru_tree_n[0, 1, 3] = {0, 0, 1};
        // lu_hit[0]: plru_tree_n[0, 1, 3] = {0, 0, 0};
        // default: begin /* No hit */ end
        // endcase
        for (int unsigned i = 0; i < TLB_WAYS; i++) begin
                automatic int unsigned idx_base, shift, new_index;
                // we got a hit so update the pointer as it was least recently used
                if (lu_hit[i] & lu_access_i & ~flush_enbl) begin
                    // Set the nodes to the values we would expect
                    for (int unsigned lvl = 0; lvl < $clog2(TLB_WAYS); lvl++) begin
                      idx_base = $unsigned((2**lvl)-1);
                      // lvl0 <=> MSB, lvl1 <=> MSB-1, ...
                      shift = $clog2(TLB_WAYS) - lvl;
                      // to circumvent the 32 bit integer arithmetic assignment
                      new_index =  ~((i >> (shift-1)) & 32'b1);
                      plru_tree_n[lu_index][idx_base + (i >> shift)] = new_index[0];
                    end
                end
        end
        // Decode tree to write enable signals
        // Next for-loop basically creates the following logic for e.g. an 8 entry
        // TLB (note: pseudo-code obviously):
        // replace_en[7] = &plru_tree_q[ 6, 2, 0]; //plru_tree_q[0,2,6]=={1,1,1}
        // replace_en[6] = &plru_tree_q[~6, 2, 0]; //plru_tree_q[0,2,6]=={1,1,0}
        // replace_en[5] = &plru_tree_q[ 5,~2, 0]; //plru_tree_q[0,2,5]=={1,0,1}
        // replace_en[4] = &plru_tree_q[~5,~2, 0]; //plru_tree_q[0,2,5]=={1,0,0}
        // replace_en[3] = &plru_tree_q[ 4, 1,~0]; //plru_tree_q[0,1,4]=={0,1,1}
        // replace_en[2] = &plru_tree_q[~4, 1,~0]; //plru_tree_q[0,1,4]=={0,1,0}
        // replace_en[1] = &plru_tree_q[ 3,~1,~0]; //plru_tree_q[0,1,3]=={0,0,1}
        // replace_en[0] = &plru_tree_q[~3,~1,~0]; //plru_tree_q[0,1,3]=={0,0,0}
        // For each entry traverse the tree. If every tree-node matches,
        // the corresponding bit of the entry's index, this is
        // the next entry to replace.
            for (int unsigned i = 0; i < TLB_WAYS; i += 1) begin
                automatic logic en;
                automatic int unsigned idx_base, shift, new_index;
                en = 1'b1;
                for (int unsigned lvl = 0; lvl < $clog2(TLB_WAYS); lvl++) begin
                    idx_base = $unsigned((2**lvl)-1);
                    // lvl0 <=> MSB, lvl1 <=> MSB-1, ...
                    shift = $clog2(TLB_WAYS) - lvl;

                    // en &= plru_tree_q[idx_base + (i>>shift)] == ((i >> (shift-1)) & 1'b1);
                    new_index =  (i >> (shift-1)) & 32'b1;
                    if (new_index[0]) begin
                      en &= plru_tree_q[update_index][idx_base + (i>>shift)];
                    end else begin
                      en &= ~plru_tree_q[update_index][idx_base + (i>>shift)];
                    end
                end
                replace_en[i] = en;
            end
    end

    // sequential process
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if(~rst_ni) begin
            state_q      <= FLUSH;
            plru_tree_q  <= '{default: 0};
            req_q        <= '{default: 0};
            flush_cnt_q  <= '{default: 0};
        end else begin
            state_q      <= state_d;
            plru_tree_q  <= plru_tree_n;
            req_q        <= req_n;
            flush_cnt_q  <= flush_cnt_d;
        end
    end

endmodule
