// Copyright 2022 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Thomas Benz  <tbenz@ethz.ch>
// Tobias Senti <tsenti@student.ethz.ch>

/// iDMA Package
/// Contains all static type definitions
package idma_pkg;

    /// Request type
    /// - `DEFAULT`: Default read-write behavior
    /// - `READ`: Read only. Read data is saved in the rdata register
    /// - `WRITE`: Write only. Data to be written must be placed in the wdata register
    /// - `PARALLEL`: Read and write performed in parallel
    typedef enum logic [1:0] {
        DEFAULT     = 2'b00,
        READ        = 2'b01,
        WRITE       = 2'b10,
        PARALLEL    = 2'b11
    } ttype_e;

    /// Error Handling Capabilities
    /// - `NO_ERROR_HANDLING`: No error handling hardware is present
    /// - `ERROR_HANDLING`: Error handling hardware is present
    typedef enum logic [0:0] {
        NO_ERROR_HANDLING,
        ERROR_HANDLING
    } error_cap_e;

    /// Error Handling Type
    typedef logic [0:0] idma_eh_req_t;

    /// Error Handling Action
    /// - `CONTINUE`: The current 1D transfer will just be continued
    /// - `ABORT`: The current 1D transfer will be aborted
    typedef enum logic [0:0] {
        CONTINUE,
        ABORT
    } eh_action_e;

    /// Error Type type
    typedef logic [1:0] err_type_t;

    /// Error Type
    /// - `BUS_READ`: Error happened during a manager bus read
    /// - `BUS_WRITE`: Error happened during a manager bus write
    /// - `BACKEND`: Internal error to the backend; currently only transfer length == 0
    /// - `ND_MIDEND`: Internal error to the nd-midend; currently all number of repetitions are
    ///                zero
    typedef enum logic [1:0] {
        BUS_READ,
        BUS_WRITE,
        BACKEND,
        ND_MIDEND
    } err_type_e;

    /// iDMA busy type: contains the busy fields of the various sub units
    typedef struct packed {
        logic buffer_busy;
        logic r_dp_busy;
        logic w_dp_busy;
        logic r_leg_busy;
        logic w_leg_busy;
        logic eh_fsm_busy;
        logic eh_cnt_busy;
        logic raw_coupler_busy;
    } idma_busy_t;

    /// AXI4 option type: contains the AXI4 options fields
    typedef struct packed {
        axi_pkg::burst_t  burst;
        axi_pkg::cache_t  cache;
        logic             lock;
        axi_pkg::prot_t   prot;
        axi_pkg::qos_t    qos;
        axi_pkg::region_t region;
    } axi_options_t;

    /// Backend option type:
    /// - `decouple_aw`: `AWs` will only be sent after the first corresponding `R` is received
    /// - `decouple_rw`: decouples the `R` and `W` channels completely: can cause deadlocks
    /// - `*_max_llen`: the maximum log length of a burst
    /// - `*_reduce_len`: should bursts be reduced in length?
    typedef struct packed {
        logic       decouple_aw;
        logic       decouple_rw;
        logic [2:0] src_max_llen;
        logic [2:0] dst_max_llen;
        logic       src_reduce_len;
        logic       dst_reduce_len;
    } backend_options_t;

    /// Supported Protocols
    /// - `AXI`: Full AXI
    /// - `AXI_LITE`: AXI Lite
    /// - `OBI`: OBI
    typedef enum logic[1:0] {
        AXI,
        AXI_LITE,
        OBI
    } protocol_e;

    /// Determines the maximum number of beats allowed within a burst depending on the protocol
    /// - `protocol`: The protocol that is used
    function automatic int unsigned determineMaxBeatsPerBurst(protocol_e protocol);
        case (protocol)
        AXI:        return 256;
        // AXI-Lite and OBI do not have bursts
        default:    return 1;
        endcase
    endfunction

endpackage : idma_pkg