// Copyright © 2023 University of Minho
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

// Licensed under the Solderpad Hardware License v 2.1 (the “License”); 
// you may not use this file except in compliance with the License, 
// or, at your option, the Apache License version 2.0. 
// You may obtain a copy of the License at https://solderpad.org/licenses/SHL-2.1/.
// Unless required by applicable law or agreed to in writing, 
// any work distributed under the License is distributed on an “AS IS” BASIS, 
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. 
// See the License for the specific language governing permissions and limitations under the License.

/*
    Author: Manuel Rodríguez, University of Minho <manuel.cederog@gmail.com>
    Date: 08/03/2023

    Description: RISC-V IOMMU MSI Interrupt Generation Module.
*/

//! NOTES:
/*
    -   Interrupt generation is triggered on a possitive transition of cip, fip or pmip.
    -   The IOMMU must not send MSIs for interrupt vectors with mask M = 1. These messages must be saved and later sent if
        the corresponding mask is cleared to 0.
    -   A register could be used for each vector to save messages M = 1. When a source generates an interrupt whose MSI 
        vector is masked, the index is saved so that the corresponding MSI is sent after clearing the flag. This means
        that the mask is associated with one vector, but may be associated with multiple interrupt sources if they 
        share the same MSI vector.
*/

module iommu_msi_ig #(
    // Number of interrupt vectors implemented
    parameter int unsigned N_INT_VEC = 16,
    // Number of interrupt sources
    parameter int unsigned N_INT_SRCS = 3,

    // DO NOT MODIFY
    parameter int unsigned LOG2_INTVEC = $clog2(N_INT_VEC)
) (
    input  logic clk_i,
    input  logic rst_ni,

    input  logic msi_ig_enabled_i,

    // Interrupt pending bits
    input  logic [(N_INT_SRCS-1):0]     intp_i,

    // Interrupt vectors
    input  logic [(LOG2_INTVEC-1):0]    intv_i[N_INT_SRCS],

    // MSI config table
    input  logic [53:0] msi_addr_x_i[16],
    input  logic [31:0] msi_data_x_i[16],
    input  logic        msi_vec_masked_x_i[16],

    // MSI write error
    output logic        msi_write_error_o,

    // AXI Master interface to write to memory
    input  ariane_axi_soc::resp_t       mem_resp_i,
    output ariane_axi_soc::req_t        mem_req_o
);

    // FSM States
    enum logic [1:0] {
        IDLE,
        WRITE,
        ERROR
    }   state_q, state_n;

    // Write FSM states
    enum logic [1:0] {
        AW_REQ,
        W_DATA,
        B_RESP
    }   wr_state_q, wr_state_n;

    // To detect rising edge transition of IP bits
    logic [(N_INT_SRCS-1):0]  edged_q, edged_n;

    // Interrupt source index
    enum logic [1:0] {
        CQ,
        FQ,
        HPM
    } int_idx;

    // Interrupt source selector
    logic [(LOG2_INTVEC-1):0]   intv_q, intv_n;

    // Pending interrupts
    logic [(N_INT_VEC-1):0]     pending_q, pending_n;

    always_comb begin : msi_generation_fsm

        // Default values
        // AXI parameters
        // AW
        /* verilator lint_off WIDTH */
        mem_req_o.aw.id         = 4'b0010;
        mem_req_o.aw.addr       = {msi_addr_x_i[intv_q], 2'b0};
        mem_req_o.aw.len        = 8'd0;         // MSI writes only 32 bits
        mem_req_o.aw.size       = 3'b010;       // 4-bytes beat
        mem_req_o.aw.burst      = axi_pkg::BURST_FIXED;
        mem_req_o.aw.lock       = '0;
        mem_req_o.aw.cache      = '0;
        mem_req_o.aw.prot       = '0;
        mem_req_o.aw.qos        = '0;
        mem_req_o.aw.region     = '0;
        mem_req_o.aw.atop       = '0;
        mem_req_o.aw.user       = '0;

        mem_req_o.aw_valid      = 1'b0;

        // W
        mem_req_o.w.data        = msi_data_x_i[intv_q];
        /* verilator lint_on WIDTH */
        mem_req_o.w.strb        = '1;
        mem_req_o.w.last        = 1'b0;
        mem_req_o.w.user        = '0;

        mem_req_o.w_valid       = 1'b0;

        // B
        mem_req_o.b_ready       = 1'b0;

        // AR
        mem_req_o.ar.id         = 4'b0011;
        mem_req_o.ar.addr       = '0;                   // we never read here
        mem_req_o.ar.len        = '0;
        mem_req_o.ar.size       = 3'b011;
        mem_req_o.ar.burst      = axi_pkg::BURST_FIXED;
        mem_req_o.ar.lock       = '0;
        mem_req_o.ar.cache      = '0;
        mem_req_o.ar.prot       = '0;
        mem_req_o.ar.qos        = '0;
        mem_req_o.ar.region     = '0;
        mem_req_o.ar.user       = '0;

        mem_req_o.ar_valid      = 1'b0;                 // we never read here

        // R
        mem_req_o.r_ready       = 1'b0;                 // we never read here

        msi_write_error_o       = 1'b0;

        state_n         = state_q;
        wr_state_n      = wr_state_q;
        intv_n          = intv_q;
        edged_n         = edged_q;
        pending_n       = pending_q;

        case (state_q)
            
            // Monitor interrupt-pending bits. Select corresponding vector (addr, data and mask).
            IDLE: begin

                // If MSI IG is not enabled, do nothing
                if (msi_ig_enabled_i) begin
                    
                    /* verilator lint_off WIDTH */

                    for (int unsigned i = 0; i < N_INT_SRCS; i++) begin

                        //# Prioritize pending messages
                        if (pending_q[intv_i[i]] && !msi_vec_masked_x_i[intv_i[i]]) begin
                            intv_n                  = intv_i[i];
                            pending_n[intv_i[i]]    = 1'b0;
                            state_n                 = WRITE;
                            break;  // Use break to set priority
                        end

                        //# Incoming interrupt
                        else if (intp_i[i] && !edged_q[i]) begin
                            
                            // We do not attribute IP value directly to avoid missing 
                            // any IP bit transition while sending another interrupt.
                            edged_n[i] = 1'b1;

                            // IP bit was set in the last cycle, send MSI if vector is not masked
                            if (!msi_vec_masked_x_i[intv_i[i]]) begin
                                intv_n      = intv_i[i];
                                state_n     = WRITE;
                            end

                            // if vector is masked, then save request
                            else begin
                                pending_n[intv_i[i]]    = 1'b1;
                            end

                            break;  // Use break to set priority
                        end 
                    end

                    for (int unsigned j = 0; j < N_INT_SRCS; j++) begin
                        
                        // Clear edged IP bits when input is clear
                        if (!intp_i[j] && edged_q[j]) begin
                            edged_n[j] = 1'b0;
                        end
                    end

                    // priority case (1'b1)

                    //     //# Prioritize pending messages

                    //     // CQ
                    //     (pending_q[intv_i[CQ]] && !msi_vec_masked_x_i[intv_i[CQ]]): begin
                    //         intv_n                  = intv_i[CQ];
                    //         pending_n[intv_i[CQ]]   = 1'b0;
                    //         state_n                 = WRITE;
                    //     end

                    //     // FQ
                    //     (pending_q[intv_i[FQ]] && !msi_vec_masked_x_i[intv_i[FQ]]): begin
                    //         intv_n                  = intv_i[FQ];
                    //         pending_n[intv_i[FQ]]   = 1'b0;
                    //         state_n                 = WRITE;
                    //     end

                    //     // HPM
                    //     (pending_q[intv_i[HPM]] && !msi_vec_masked_x_i[intv_i[HPM]]): begin
                    //         intv_n                  = intv_i[HPM];
                    //         pending_n[intv_i[HPM]]  = 1'b0;
                    //         state_n                 = WRITE;
                    //     end

                    //     //# Incoming interrupt
                        
                    //     // CQ
                    //     (intp_i[CQ] && !edged_q[CQ]): begin
                            
                    //         // We do not attribute cip_i directly to avoid missing 
                    //         // any IP bit transition while sending another interrupt.
                    //         edged_n[CQ] = 1'b1;

                    //         // cip bit was set in the last cycle, send MSI if vector is not masked
                    //         if (!msi_vec_masked_x_i[intv_i[CQ]]) begin
                    //             intv_n      = intv_i[CQ];
                    //             state_n     = WRITE;
                    //         end

                    //         // if vector is masked, then save request
                    //         else begin
                    //             pending_n[intv_i[CQ]]   = 1'b1;
                    //         end
                    //     end

                    //     // FQ
                    //     (intp_i[FQ] && !edged_q[FQ]): begin
                            
                    //         // We do not attribute fip_i directly to avoid missing 
                    //         // any IP bit transition while sending another interrupt.
                    //         edged_n[FQ] = 1'b1;

                    //         // fip bit was set in the last cycle, send MSI if vector is not masked
                    //         if (!msi_vec_masked_x_i[intv_i[FQ]]) begin
                    //             intv_n      = intv_i[FQ];
                    //             state_n     = WRITE;
                    //         end

                    //         // if vector is masked, then save request for FQ
                    //         else begin
                    //             pending_n[intv_i[FQ]]    = 1'b1;
                    //         end
                    //     end

                    //     // HPM
                    //     (intp_i[HPM] && !edged_q[HPM]): begin
                            
                    //         // We do not attribute pmip_i directly to avoid missing 
                    //         // any IP bit transition while sending another interrupt.
                    //         edged_n[HPM] = 1'b1;

                    //         // pmip bit was set in the last cycle, send MSI if vector is not masked
                    //         if (!msi_vec_masked_x_i[intv_i[HPM]]) begin
                    //             intv_n      = intv_i[HPM];
                    //             state_n     = WRITE;
                    //         end

                    //         // if vector is masked, then save request for HPM
                    //         else begin
                    //             pending_n[intv_i[HPM]]    = 1'b1;
                    //         end
                    //     end

                    // endcase

                    /* verilator lint_on WIDTH */

                    // // Clear edged IP bits when input is clear
                    // if (!intp_i[CQ] && edged_q[CQ]) begin
                    //     edged_n[CQ] = 1'b0;
                    // end
                    // if (!fip_i && edged_fip_q) begin
                    //     edged_fip_n = 1'b0;
                    // end
                    // if (!pmip_i && edged_pmip_q) begin
                    //     edged_pmip_n = 1'b0;
                    // end
                end
            end 

            // Write MSI to the corresponding address
            WRITE: begin
                case (wr_state_q)

                    // Send request to AW Channel
                    AW_REQ: begin
                        mem_req_o.aw_valid  = 1'b1;

                        if (mem_resp_i.aw_ready) begin
                            wr_state_n  = W_DATA;
                        end
                    end

                    // Send data through W channel
                    W_DATA: begin
                        mem_req_o.w_valid   = 1'b1;
                        mem_req_o.w.last    = 1'b1;

                        if(mem_resp_i.w_ready) begin
                            wr_state_n  = B_RESP;
                        end
                    end

                    // Check response code
                    B_RESP: begin
                        if (mem_resp_i.b_valid) begin
                            
                            mem_req_o.b_ready   = 1'b1;
                            state_n             = IDLE;
                            wr_state_n  = AW_REQ;

                            // TODO: IOPMP access faults are reported as AXI faults. We need a way to
                            // TODO: differentiate these faults from normal AXI faults.
                            if (mem_resp_i.b.resp != axi_pkg::RESP_OKAY) begin
                                // AXI error
                                state_n = ERROR;
                            end
                        end
                    end

                    default: state_n = IDLE;
                endcase
            end

            // We may receive an AXI or access error when writing
            ERROR: begin
                msi_write_error_o   = 1'b1;
                state_n             = IDLE;
            end

            default: state_n = IDLE;
        endcase
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin : sequential_logic
        
        if (~rst_ni) begin
            // Reset values
            state_q         <= IDLE;
            wr_state_q      <= AW_REQ;
            intv_q          <= '0;
            edged_q         <= '0;
            pending_q       <= '0;
        end

        else begin
            state_q         <= state_n;
            wr_state_q      <= wr_state_n;
            intv_q          <= intv_n;
            edged_q         <= edged_n;
            pending_q       <= pending_n;
        end
    end
    
endmodule