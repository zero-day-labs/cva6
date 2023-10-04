// Copyright © 2023 Manuel Rodríguez & Zero-Day Labs, Lda.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

// Licensed under the Solderpad Hardware License v 2.1 (the “License”); 
// you may not use this file except in compliance with the License, 
// or, at your option, the Apache License version 2.0. 
// You may obtain a copy of the License at https://solderpad.org/licenses/SHL-2.1/.
// Unless required by applicable law or agreed to in writing, 
// any work distributed under the License is distributed on an “AS IS” BASIS, 
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. 
// See the License for the specific language governing permissions and limitations under the License.
//
// Author: Manuel Rodríguez <manuel.cederog@gmail.com>
// Date: 06/02/2023
//
// Description: RISC-V IOMMU Translation Logic Wrapper.
//              Encompasses all modules involved in the address translation process.
//              PTW, CDW, IOTLB, DDTC, PDTC
//              Affected by InclPC and InclMSITrans design parameters
//

module rv_iommu_translation_wrapper #(

    parameter int unsigned  IOTLB_ENTRIES       = 4,
    parameter int unsigned  DDTC_ENTRIES        = 4,
    parameter int unsigned  PDTC_ENTRIES        = 4,

    // Include Process Context support
    parameter bit               InclPC         = 0,
    // Include MSI translation support
    parameter bit               InclMSITrans    = 0,

    /// AXI Full request struct type
    parameter type  axi_req_t       = logic,
    /// AXI Full response struct type
    parameter type  axi_rsp_t       = logic
) (
    input  logic    clk_i,
    input  logic    rst_ni,

    // Trigger translation
    input  logic    req_trans_i,

    // Translation request data
    input  logic [23:0]                     did_i,      // device_id associated with the transaction
    input  logic                            pv_i,       // a valid process_id is associated with the request
    input  logic [19:0]                     pid_i,      // process_id associated with the transaction
    input  logic [riscv::VLEN-1:0]          iova_i,     // IOVA
    output logic [15:0]                     gscid_o,    // GSCID
    output logic [19:0]                     pscid_o,    // PSCID
    
    input  logic [rv_iommu::TTYP_LEN-1:0]   trans_type_i,   // transaction type
    input  logic                            priv_lvl_i,     // privilege mode associated with the transaction

    // AXI ports directed to Data Structures Interface
    // CDW
    input  axi_rsp_t   cdw_axi_resp_i,
    output axi_req_t    cdw_axi_req_o,
    // PTW
    input  axi_rsp_t   ptw_axi_resp_i,
    output axi_req_t    ptw_axi_req_o,

    // From Regmap
    input  rv_iommu_reg_pkg::iommu_reg2hw_capabilities_reg_t   capabilities_i,
    input  rv_iommu_reg_pkg::iommu_reg2hw_fctl_reg_t           fctl_i,
    input  rv_iommu_reg_pkg::iommu_reg2hw_ddtp_reg_t           ddtp_i,

    // Request status and output data
    output logic                        trans_valid_o,      // Translation completed
    output logic [riscv::PLEN-1:0]      spaddr_o,           // Translated address
    output logic                        is_msi_o,           // Indicate whether the translated address is an MSI address
    // Error
    output logic                                trans_error_o,      // Translation error
    output logic                                report_fault_o,     // The fault must be reported through the FQ
    output logic [(rv_iommu::CAUSE_LEN-1):0]    cause_code_o,       // Fault code defined by translation logic
    output logic                                is_guest_pf_o,      // a guest page fault occurred in the PTW
    output logic                                is_implicit_o,      // Guest page fault caused by implicit access for 1st-stage addr translation
    output logic [riscv::SVX-1:0]               bad_gpaddr_o,       // to report bits [63:2] of the GPA in case of a Guest Page Fault
    input  logic                                msi_write_error_i,  // An error occurred when writing an MSI generated by the IOMMU

    // to HPM
    output logic                        iotlb_miss_o,       // IOTLB miss happened
    output logic                        ddt_walk_o,         // DDT walk triggered
    output logic                        pdt_walk_o,         // PDT walk triggered
    output logic                        s1_ptw_o,           // first-stage PT walk triggered
    output logic                        s2_ptw_o,           // second-stage PT walk triggered

    // IOATC Invalidation control (from CQ Handler to IOATC)
    // DDTC Invalidation
    input  logic                        flush_ddtc_i,   // Flush DDTC
    input  logic                        flush_dv_i,     // Indicates if device_id is valid
    input  logic [23:0]                 flush_did_i,    // device_id to tag entries to be flushed
    // PDTC Invalidation
    input  logic                        flush_pdtc_i,   // Flush PDTC
    input  logic                        flush_pv_i,     // This is used to difference between IODIR.INVAL_DDT and IODIR.INVAL_PDT
    input  logic [19:0]                 flush_pid_i,    // process_id to be flushed if PV = 1
    // IOTLB Invalidation
    input  logic                        flush_vma_i,    // Flush first-stage PTEs cached entries in IOTLB
    input  logic                        flush_gvma_i,   // Flush second-stage PTEs cached entries in IOTLB 
    input  logic                        flush_av_i,     // Address valid
    input  logic                        flush_gv_i,     // GSCID valid
    input  logic                        flush_pscv_i,   // PSCID valid
    input  logic [riscv::GPPNW-1:0]     flush_vpn_i,    // IOVA to tag entries to be flushed
    input  logic [15:0]                 flush_gscid_i,  // GSCID (Guest physical address space identifier) to tag entries to be flushed
    input  logic [19:0]                 flush_pscid_i   // PSCID (Guest virtual address space identifier) to tag entries to be flushed
);

    generate
        case ({InclPC, InclMSITrans})

            // No PC support
            // No MSI translation support
            0: begin
                rv_iommu_tw_sv39x4 #(
                    .IOTLB_ENTRIES      (IOTLB_ENTRIES  ),
                    .DDTC_ENTRIES       (DDTC_ENTRIES   ),

                    .axi_req_t          (axi_req_t      ),
                    .axi_rsp_t          (axi_rsp_t      )
                ) i_rv_iommu_tw_sv39x4 (
                    .clk_i,
                    .rst_ni,
                    .req_trans_i,
                    .did_i,                 // device_id associated with the transaction
                    .iova_i,                // IOVA
                    .gscid_o,               // GSCID
                    .pscid_o,               // PSCID
                    .trans_type_i,          // transaction type
                    .cdw_axi_resp_i,
                    .cdw_axi_req_o,
                    .ptw_axi_resp_i,
                    .ptw_axi_req_o,
                    .capabilities_i,
                    .fctl_i,
                    .ddtp_i,
                    .trans_valid_o,         // Translation completed
                    .spaddr_o,              // Translated address
                    .trans_error_o,         // Translation error
                    .report_fault_o,        // The fault must be reported through the FQ
                    .cause_code_o,          // Fault code defined by translation logic
                    .is_guest_pf_o,         // a guest page fault occurred in the PTW
                    .is_implicit_o,         // Guest page fault caused by implicit access for 1st-stage addr translation
                    .bad_gpaddr_o,          // to report bits [63:2] of the GPA in case of a Guest Page Fault
                    .msi_write_error_i,     // An error occurred when writing an MSI generated by the IOMMU
                    .iotlb_miss_o,          // IOTLB miss happened
                    .ddt_walk_o,            // DDT walk triggered
                    .pdt_walk_o,            // PDT walk triggered
                    .s1_ptw_o,              // first-stage PT walk triggered
                    .s2_ptw_o,              // second-stage PT walk triggered
                    .flush_ddtc_i,          // Flush DDTC
                    .flush_dv_i,            // Indicates if device_id is valid
                    .flush_did_i,           // device_id to tag entries to be flushed
                    .flush_vma_i,           // Flush first-stage PTEs cached entries in IOTLB
                    .flush_gvma_i,          // Flush second-stage PTEs cached entries in IOTLB 
                    .flush_av_i,            // Address valid
                    .flush_gv_i,            // GSCID valid
                    .flush_pscv_i,          // PSCID valid
                    .flush_vpn_i,           // IOVA to tag entries to be flushed
                    .flush_gscid_i,         // GSCID (Guest physical address space identifier) to tag entries to be flushed
                    .flush_pscid_i          // PSCID (Guest virtual address space identifier) to tag entries to be flushed
                );

                assign is_msi_o     = 1'b0;
            end

            // No PC support
            // MSI translation support
            1: begin
                rv_iommu_tw_sv39x4_msi #(
                    .IOTLB_ENTRIES      (IOTLB_ENTRIES  ),
                    .DDTC_ENTRIES       (DDTC_ENTRIES   ),

                    .axi_req_t          (axi_req_t      ),
                    .axi_rsp_t          (axi_rsp_t      )
                ) i_rv_iommu_tw_sv39x4_msi (
                    .clk_i,
                    .rst_ni,
                    .req_trans_i,
                    .did_i,                 // device_id associated with the transaction
                    .iova_i,                // IOVA
                    .gscid_o,               // GSCID
                    .pscid_o,               // PSCID
                    .trans_type_i,          // transaction type
                    .cdw_axi_resp_i,
                    .cdw_axi_req_o,
                    .ptw_axi_resp_i,
                    .ptw_axi_req_o,
                    .capabilities_i,
                    .fctl_i,
                    .ddtp_i,
                    .trans_valid_o,         // Translation completed
                    .spaddr_o,              // Translated address
                    .is_msi_o,              // Indicate whether the translated address is an MSI address
                    .trans_error_o,         // Translation error
                    .report_fault_o,        // The fault must be reported through the FQ
                    .cause_code_o,          // Fault code defined by translation logic
                    .is_guest_pf_o,         // a guest page fault occurred in the PTW
                    .is_implicit_o,         // Guest page fault caused by implicit access for 1st-stage addr translation
                    .bad_gpaddr_o,          // to report bits [63:2] of the GPA in case of a Guest Page Fault
                    .msi_write_error_i,     // An error occurred when writing an MSI generated by the IOMMU
                    .iotlb_miss_o,          // IOTLB miss happened
                    .ddt_walk_o,            // DDT walk triggered
                    .pdt_walk_o,            // PDT walk triggered
                    .s1_ptw_o,              // first-stage PT walk triggered
                    .s2_ptw_o,              // second-stage PT walk triggered
                    .flush_ddtc_i,          // Flush DDTC
                    .flush_dv_i,            // Indicates if device_id is valid
                    .flush_did_i,           // device_id to tag entries to be flushed
                    .flush_vma_i,           // Flush first-stage PTEs cached entries in IOTLB
                    .flush_gvma_i,          // Flush second-stage PTEs cached entries in IOTLB 
                    .flush_av_i,            // Address valid
                    .flush_gv_i,            // GSCID valid
                    .flush_pscv_i,          // PSCID valid
                    .flush_vpn_i,           // IOVA to tag entries to be flushed
                    .flush_gscid_i,         // GSCID (Guest physical address space identifier) to tag entries to be flushed
                    .flush_pscid_i          // PSCID (Guest virtual address space identifier) to tag entries to be flushed
                );
            end

            // PC support
            // No MSI translation support
            2: begin
                rv_iommu_tw_sv39x4_pc #(
                    .IOTLB_ENTRIES      (IOTLB_ENTRIES  ),
                    .DDTC_ENTRIES       (DDTC_ENTRIES   ),
                    .PDTC_ENTRIES       (PDTC_ENTRIES   ),

                    .axi_req_t          (axi_req_t      ),
                    .axi_rsp_t          (axi_rsp_t      )
                ) i_rv_iommu_tw_sv39x4_pc (
                    .clk_i,
                    .rst_ni,
                    .req_trans_i,
                    .did_i,                 // device_id associated with the transaction
                    .pv_i,                  // a valid process_id is associated with the request
                    .pid_i,                 // process_id associated with the transaction
                    .iova_i,                // IOVA
                    .gscid_o,               // GSCID
                    .pscid_o,               // PSCID
                    .trans_type_i,          // transaction type
                    .priv_lvl_i,            // privilege mode associated with the transaction
                    .cdw_axi_resp_i,
                    .cdw_axi_req_o,
                    .ptw_axi_resp_i,
                    .ptw_axi_req_o,
                    .capabilities_i,
                    .fctl_i,
                    .ddtp_i,
                    .trans_valid_o,         // Translation completed
                    .spaddr_o,              // Translated address
                    .trans_error_o,         // Translation error
                    .report_fault_o,        // The fault must be reported through the FQ
                    .cause_code_o,          // Fault code defined by translation logic
                    .is_guest_pf_o,         // a guest page fault occurred in the PTW
                    .is_implicit_o,         // Guest page fault caused by implicit access for 1st-stage addr translation
                    .bad_gpaddr_o,          // to report bits [63:2] of the GPA in case of a Guest Page Fault
                    .msi_write_error_i,     // An error occurred when writing an MSI generated by the IOMMU
                    .iotlb_miss_o,          // IOTLB miss happened
                    .ddt_walk_o,            // DDT walk triggered
                    .pdt_walk_o,            // PDT walk triggered
                    .s1_ptw_o,              // first-stage PT walk triggered
                    .s2_ptw_o,              // second-stage PT walk triggered
                    .flush_ddtc_i,          // Flush DDTC
                    .flush_dv_i,            // Indicates if device_id is valid
                    .flush_did_i,           // device_id to tag entries to be flushed
                    .flush_pdtc_i,          // Flush PDTC
                    .flush_pv_i,            // This is used to difference between IODIR.INVAL_DDT and IODIR.INVAL_PDT
                    .flush_pid_i,           // process_id to be flushed if PV = 1
                    .flush_vma_i,           // Flush first-stage PTEs cached entries in IOTLB
                    .flush_gvma_i,          // Flush second-stage PTEs cached entries in IOTLB 
                    .flush_av_i,            // Address valid
                    .flush_gv_i,            // GSCID valid
                    .flush_pscv_i,          // PSCID valid
                    .flush_vpn_i,           // IOVA to tag entries to be flushed
                    .flush_gscid_i,         // GSCID (Guest physical address space identifier) to tag entries to be flushed
                    .flush_pscid_i          // PSCID (Guest virtual address space identifier) to tag entries to be flushed
                );

                assign is_msi_o     = 1'b0;
            end

            // PC support
            // MSI translation support
            3: begin
                rv_iommu_tw_sv39x4_msi_pc #(
                    .IOTLB_ENTRIES      (IOTLB_ENTRIES  ),
                    .DDTC_ENTRIES       (DDTC_ENTRIES   ),
                    .PDTC_ENTRIES       (PDTC_ENTRIES   ),

                    .axi_req_t          (axi_req_t      ),
                    .axi_rsp_t          (axi_rsp_t      )
                ) i_rv_iommu_tw_sv39x4_msi_pc (
                    .clk_i,
                    .rst_ni,
                    .req_trans_i,
                    .did_i,                 // device_id associated with the transaction
                    .pv_i,                  // a valid process_id is associated with the request
                    .pid_i,                 // process_id associated with the transaction
                    .iova_i,                // IOVA
                    .gscid_o,               // GSCID
                    .pscid_o,               // PSCID
                    .trans_type_i,          // transaction type
                    .priv_lvl_i,            // privilege mode associated with the transaction
                    .cdw_axi_resp_i,
                    .cdw_axi_req_o,
                    .ptw_axi_resp_i,
                    .ptw_axi_req_o,
                    .capabilities_i,
                    .fctl_i,
                    .ddtp_i,
                    .trans_valid_o,         // Translation completed
                    .spaddr_o,              // Translated address
                    .is_msi_o,              // Indicate whether the translated address is an MSI address
                    .trans_error_o,         // Translation error
                    .report_fault_o,        // The fault must be reported through the FQ
                    .cause_code_o,          // Fault code defined by translation logic
                    .is_guest_pf_o,         // a guest page fault occurred in the PTW
                    .is_implicit_o,         // Guest page fault caused by implicit access for 1st-stage addr translation
                    .bad_gpaddr_o,          // to report bits [63:2] of the GPA in case of a Guest Page Fault
                    .msi_write_error_i,     // An error occurred when writing an MSI generated by the IOMMU
                    .iotlb_miss_o,          // IOTLB miss happened
                    .ddt_walk_o,            // DDT walk triggered
                    .pdt_walk_o,            // PDT walk triggered
                    .s1_ptw_o,              // first-stage PT walk triggered
                    .s2_ptw_o,              // second-stage PT walk triggered
                    .flush_ddtc_i,          // Flush DDTC
                    .flush_dv_i,            // Indicates if device_id is valid
                    .flush_did_i,           // device_id to tag entries to be flushed
                    .flush_pdtc_i,          // Flush PDTC
                    .flush_pv_i,            // This is used to difference between IODIR.INVAL_DDT and IODIR.INVAL_PDT
                    .flush_pid_i,           // process_id to be flushed if PV = 1
                    .flush_vma_i,           // Flush first-stage PTEs cached entries in IOTLB
                    .flush_gvma_i,          // Flush second-stage PTEs cached entries in IOTLB 
                    .flush_av_i,            // Address valid
                    .flush_gv_i,            // GSCID valid
                    .flush_pscv_i,          // PSCID valid
                    .flush_vpn_i,           // IOVA to tag entries to be flushed
                    .flush_gscid_i,         // GSCID (Guest physical address space identifier) to tag entries to be flushed
                    .flush_pscid_i          // PSCID (Guest virtual address space identifier) to tag entries to be flushed
                );
            end
        endcase
    endgenerate

endmodule