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
    Date:   10/03/2023

    Description: RISC-V IOMMU WSI Interrupt Generation Module.
*/

module iommu_wsi_ig #(
    // Number of supported interrupt vectors
    parameter int unsigned N_INT_VEC = 16,
    // Number of interrupt sources
    parameter int unsigned N_SOURCES = 3,
    
    // DO NOT MODIFY
    parameter int unsigned LOG2_INTVEC = $clog2(N_INT_VEC)
) (
    
    // fctl.wsi
    input  logic        wsi_en_i,

    // Interrupt pending bits
    input  logic [(N_SOURCES-1):0]      intp_i,

    // Interrupt vectors
    input  logic [(LOG2_INTVEC-1):0]    intv_i[N_SOURCES],

    // interrupt wires
    output logic [(N_INT_VEC-1):0]      wsi_wires_o
);

    always_comb begin : wsi_support
            
        /* verilator lint_off WIDTH */
        // If WSI generation supported and enabled
        if (wsi_en_i) begin

            for (int unsigned i = 0; i < N_INT_VEC; i++) begin
                for (int unsigned j = 0; j < N_SOURCES; j++) begin
                    wsi_wires_o[i] = (intp_i[j] & (intv_i[j] == rv_iommu::icvec_vals[i]));
                end
            end
        end
        /* verilator lint_on WIDTH */
    end
    
endmodule