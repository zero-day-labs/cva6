// Copyright (c) 2019 ETH Zurich, University of Bologna
//
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//
// Authors:
// - Andreas Kurth <akurth@iis.ee.ethz.ch>
// - Florian Zaruba <zarubaf@iis.ee.ethz.ch>
// - Wolfgang Roenninger <wroennin@iis.ee.ethz.ch>

// Macros to define AXI and AXI-Lite Channel and Request/Response Structs

`ifndef AXI_TYPEDEF_SVH_
`define AXI_TYPEDEF_SVH_

////////////////////////////////////////////////////////////////////////////////////////////////////
// AXI4+ATOP Channel and Request/Response Structs
//
// Usage Example:
// `AXI_TYPEDEF_AW_CHAN_T(axi_aw_t, axi_addr_t, axi_id_t, axi_user_t)
// `AXI_TYPEDEF_W_CHAN_T(axi_w_t, axi_data_t, axi_strb_t, axi_user_t)
// `AXI_TYPEDEF_B_CHAN_T(axi_b_t, axi_id_t, axi_user_t)
// `AXI_TYPEDEF_AR_CHAN_T(axi_ar_t, axi_addr_t, axi_id_t, axi_user_t)
// `AXI_TYPEDEF_R_CHAN_T(axi_r_t, axi_data_t, axi_id_t, axi_user_t)
// `AXI_TYPEDEF_REQ_T(axi_req_t, axi_aw_t, axi_w_t, axi_ar_t)
// `AXI_TYPEDEF_RESP_T(axi_resp_t, axi_b_t, axi_r_t)
`define AXI_TYPEDEF_AW_CHAN_T(aw_chan_t, addr_t, id_t, user_t)  \
  typedef struct packed {                                       \
    id_t              id;                                       \
    addr_t            addr;                                     \
    axi_pkg::len_t    len;                                      \
    axi_pkg::size_t   size;                                     \
    axi_pkg::burst_t  burst;                                    \
    logic             lock;                                     \
    axi_pkg::cache_t  cache;                                    \
    axi_pkg::prot_t   prot;                                     \
    axi_pkg::qos_t    qos;                                      \
    axi_pkg::region_t region;                                   \
    axi_pkg::atop_t   atop;                                     \
    user_t            user;                                     \
  } aw_chan_t;
`define AXI_TYPEDEF_W_CHAN_T(w_chan_t, data_t, strb_t, user_t)  \
  typedef struct packed {                                       \
    data_t data;                                                \
    strb_t strb;                                                \
    logic  last;                                                \
    user_t user;                                                \
  } w_chan_t;
`define AXI_TYPEDEF_B_CHAN_T(b_chan_t, id_t, user_t)  \
  typedef struct packed {                             \
    id_t            id;                               \
    axi_pkg::resp_t resp;                             \
    user_t          user;                             \
  } b_chan_t;
`define AXI_TYPEDEF_AR_CHAN_T(ar_chan_t, addr_t, id_t, user_t)  \
  typedef struct packed {                                       \
    id_t              id;                                       \
    addr_t            addr;                                     \
    axi_pkg::len_t    len;                                      \
    axi_pkg::size_t   size;                                     \
    axi_pkg::burst_t  burst;                                    \
    logic             lock;                                     \
    axi_pkg::cache_t  cache;                                    \
    axi_pkg::prot_t   prot;                                     \
    axi_pkg::qos_t    qos;                                      \
    axi_pkg::region_t region;                                   \
    user_t            user;                                     \
  } ar_chan_t;
`define AXI_TYPEDEF_R_CHAN_T(r_chan_t, data_t, id_t, user_t)  \
  typedef struct packed {                                     \
    id_t            id;                                       \
    data_t          data;                                     \
    axi_pkg::resp_t resp;                                     \
    logic           last;                                     \
    user_t          user;                                     \
  } r_chan_t;
`define AXI_TYPEDEF_REQ_T(req_t, aw_chan_t, w_chan_t, ar_chan_t)  \
  typedef struct packed {                                         \
    aw_chan_t aw;                                                 \
    logic     aw_valid;                                           \
    w_chan_t  w;                                                  \
    logic     w_valid;                                            \
    logic     b_ready;                                            \
    ar_chan_t ar;                                                 \
    logic     ar_valid;                                           \
    logic     r_ready;                                            \
  } req_t;
`define AXI_TYPEDEF_RESP_T(resp_t, b_chan_t, r_chan_t)  \
  typedef struct packed {                               \
    logic     aw_ready;                                 \
    logic     ar_ready;                                 \
    logic     w_ready;                                  \
    logic     b_valid;                                  \
    b_chan_t  b;                                        \
    logic     r_valid;                                  \
    r_chan_t  r;                                        \
  } resp_t;
////////////////////////////////////////////////////////////////////////////////////////////////////


////////////////////////////////////////////////////////////////////////////////////////////////////
// All AXI4+ATOP Channels and Request/Response Structs in One Macro
//
// This can be used whenever the user is not interested in "precise" control of the naming of the
// individual channels.
//
// Usage Example:
// `AXI_TYPEDEF_ALL(axi, addr_t, id_t, data_t, strb_t, user_t)
//
// This defines `axi_req_t` and `axi_resp_t` request/response structs as well as `axi_aw_chan_t`,
// `axi_w_chan_t`, `axi_b_chan_t`, `axi_ar_chan_t`, and `axi_r_chan_t` channel structs.
`define AXI_TYPEDEF_ALL(__name, __addr_t, __id_t, __data_t, __strb_t, __user_t)                 \
  `AXI_TYPEDEF_AW_CHAN_T(__name``_aw_chan_t, __addr_t, __id_t, __user_t)                        \
  `AXI_TYPEDEF_W_CHAN_T(__name``_w_chan_t, __data_t, __strb_t, __user_t)                        \
  `AXI_TYPEDEF_B_CHAN_T(__name``_b_chan_t, __id_t, __user_t)                                    \
  `AXI_TYPEDEF_AR_CHAN_T(__name``_ar_chan_t, __addr_t, __id_t, __user_t)                        \
  `AXI_TYPEDEF_R_CHAN_T(__name``_r_chan_t, __data_t, __id_t, __user_t)                          \
  `AXI_TYPEDEF_REQ_T(__name``_req_t, __name``_aw_chan_t, __name``_w_chan_t, __name``_ar_chan_t) \
  `AXI_TYPEDEF_RESP_T(__name``_resp_t, __name``_b_chan_t, __name``_r_chan_t)
////////////////////////////////////////////////////////////////////////////////////////////////////


////////////////////////////////////////////////////////////////////////////////////////////////////
// AXI4-Lite Channel and Request/Response Structs
//
// Usage Example:
// `AXI_LITE_TYPEDEF_AW_CHAN_T(axi_lite_aw_t, axi_lite_addr_t)
// `AXI_LITE_TYPEDEF_W_CHAN_T(axi_lite_w_t, axi_lite_data_t, axi_lite_strb_t)
// `AXI_LITE_TYPEDEF_B_CHAN_T(axi_lite_b_t)
// `AXI_LITE_TYPEDEF_AR_CHAN_T(axi_lite_ar_t, axi_lite_addr_t)
// `AXI_LITE_TYPEDEF_R_CHAN_T(axi_lite_r_t, axi_lite_data_t)
// `AXI_LITE_TYPEDEF_REQ_T(axi_lite_req_t, axi_lite_aw_t, axi_lite_w_t, axi_lite_ar_t)
// `AXI_LITE_TYPEDEF_RESP_T(axi_lite_resp_t, axi_lite_b_t, axi_lite_r_t)
`define AXI_LITE_TYPEDEF_AW_CHAN_T(aw_chan_lite_t, addr_t)  \
  typedef struct packed {                                   \
    addr_t          addr;                                   \
    axi_pkg::prot_t prot;                                   \
  } aw_chan_lite_t;
`define AXI_LITE_TYPEDEF_W_CHAN_T(w_chan_lite_t, data_t, strb_t)  \
  typedef struct packed {                                         \
    data_t   data;                                                \
    strb_t   strb;                                                \
  } w_chan_lite_t;
`define AXI_LITE_TYPEDEF_B_CHAN_T(b_chan_lite_t)  \
  typedef struct packed {                         \
    axi_pkg::resp_t resp;                         \
  } b_chan_lite_t;
`define AXI_LITE_TYPEDEF_AR_CHAN_T(ar_chan_lite_t, addr_t)  \
  typedef struct packed {                                   \
    addr_t          addr;                                   \
    axi_pkg::prot_t prot;                                   \
  } ar_chan_lite_t;
`define AXI_LITE_TYPEDEF_R_CHAN_T(r_chan_lite_t, data_t)  \
  typedef struct packed {                                 \
    data_t          data;                                 \
    axi_pkg::resp_t resp;                                 \
  } r_chan_lite_t;
`define AXI_LITE_TYPEDEF_REQ_T(req_lite_t, aw_chan_lite_t, w_chan_lite_t, ar_chan_lite_t)  \
  typedef struct packed {                                                                  \
    aw_chan_lite_t aw;                                                                     \
    logic          aw_valid;                                                               \
    w_chan_lite_t  w;                                                                      \
    logic          w_valid;                                                                \
    logic          b_ready;                                                                \
    ar_chan_lite_t ar;                                                                     \
    logic          ar_valid;                                                               \
    logic          r_ready;                                                                \
  } req_lite_t;
`define AXI_LITE_TYPEDEF_RESP_T(resp_lite_t, b_chan_lite_t, r_chan_lite_t)  \
  typedef struct packed {                                                   \
    logic          aw_ready;                                                \
    logic          w_ready;                                                 \
    b_chan_lite_t  b;                                                       \
    logic          b_valid;                                                 \
    logic          ar_ready;                                                \
    r_chan_lite_t  r;                                                       \
    logic          r_valid;                                                 \
  } resp_lite_t;
////////////////////////////////////////////////////////////////////////////////////////////////////


////////////////////////////////////////////////////////////////////////////////////////////////////
// All AXI4-Lite Channels and Request/Response Structs in One Macro
//
// This can be used whenever the user is not interested in "precise" control of the naming of the
// individual channels.
//
// Usage Example:
// `AXI_LITE_TYPEDEF_ALL(axi_lite, addr_t, data_t, strb_t)
//
// This defines `axi_lite_req_t` and `axi_lite_resp_t` request/response structs as well as
// `axi_lite_aw_chan_t`, `axi_lite_w_chan_t`, `axi_lite_b_chan_t`, `axi_lite_ar_chan_t`, and
// `axi_lite_r_chan_t` channel structs.
`define AXI_LITE_TYPEDEF_ALL(__name, __addr_t, __data_t, __strb_t)                                    \
  `AXI_LITE_TYPEDEF_AW_CHAN_T(__name``_aw_chan_t, __addr_t)                                           \
  `AXI_LITE_TYPEDEF_W_CHAN_T(__name``_w_chan_t, __data_t, __strb_t)                                   \
  `AXI_LITE_TYPEDEF_B_CHAN_T(__name``_b_chan_t)                                                       \
  `AXI_LITE_TYPEDEF_AR_CHAN_T(__name``_ar_chan_t, __addr_t)                                           \
  `AXI_LITE_TYPEDEF_R_CHAN_T(__name``_r_chan_t, __data_t)                                             \
  `AXI_LITE_TYPEDEF_REQ_T(__name``_req_t, __name``_aw_chan_t, __name``_w_chan_t, __name``_ar_chan_t)  \
  `AXI_LITE_TYPEDEF_RESP_T(__name``_resp_t, __name``_b_chan_t, __name``_r_chan_t)
////////////////////////////////////////////////////////////////////////////////////////////////////

//////////////////////////////////////// iDMA TYPEDEFS ////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////////////////////////
// iDMA Request and Response Structs
//
// Usage Example:
// `IDMA_TYPEDEF_OPTIONS_T(options_t, axi_id_t)
// `IDMA_TYPEDEF_ERR_PAYLOAD_T(err_payload_t, axi_addr_t)
// `IDMA_TYPEDEF_REQ_T(idma_req_t, tf_len_t, axi_addr_t, options_t)
// `IDMA_TYPEDEF_RSP_T(idma_rsp_t, err_payload_t)
`define IDMA_TYPEDEF_OPTIONS_T(options_t, axi_id_t)                      \
    typedef struct packed {                                              \
        axi_id_t                    axi_id;                              \
        idma_pkg::axi_options_t     src;                                 \
        idma_pkg::axi_options_t     dst;                                 \
        idma_pkg::backend_options_t beo;                                 \
        logic                       last;                                \
    } options_t;
`define IDMA_TYPEDEF_ERR_PAYLOAD_T(err_payload_t, axi_addr_t)            \
    typedef struct packed {                                              \
        axi_pkg::resp_t      cause;                                      \
        idma_pkg::err_type_t err_type;                                   \
        axi_addr_t           burst_addr;                                 \
    } err_payload_t;
`define IDMA_TYPEDEF_REQ_T(idma_req_t, tf_len_t, axi_addr_t, options_t)  \
    typedef struct packed {                                              \
        tf_len_t   length;                                               \
        axi_addr_t src_addr;                                             \
        axi_addr_t dst_addr;                                             \
        options_t  opt;                                                  \
    } idma_req_t;
`define IDMA_TYPEDEF_RSP_T(idma_rsp_t, err_payload_t)                    \
    typedef struct packed {                                              \
        logic         last;                                              \
        logic         error;                                             \
        err_payload_t pld;                                               \
    } idma_rsp_t;
////////////////////////////////////////////////////////////////////////////////////////////////////


////////////////////////////////////////////////////////////////////////////////////////////////////
// iDMA Full Request and Response Structs
//
// Usage Example:
// `IDMA_TYPEDEF_FULL_REQ_T(idma_req_t, axi_id_t, axi_addr_t, tf_len_t)
// `IDMA_TYPEDEF_FULL_RSP_T(idma_rsp_t, axi_addr_t)
`define IDMA_TYPEDEF_FULL_REQ_T(idma_req_t, axi_id_t, axi_addr_t, tf_len_t) \
    `IDMA_TYPEDEF_OPTIONS_T(options_t, axi_id_t)                            \
    `IDMA_TYPEDEF_REQ_T(idma_req_t, tf_len_t, axi_addr_t, options_t)
`define IDMA_TYPEDEF_FULL_RSP_T(idma_rsp_t, axi_addr_t)                     \
    `IDMA_TYPEDEF_ERR_PAYLOAD_T(err_payload_t, axi_addr_t)                  \
    `IDMA_TYPEDEF_RSP_T(idma_rsp_t, err_payload_t)
////////////////////////////////////////////////////////////////////////////////////////////////////


////////////////////////////////////////////////////////////////////////////////////////////////////
// iDMA n-dimensional Request Struct
//
// Usage Example:
// `IDMA_TYPEDEF_D_REQ_T(idma_d_req_t, reps_t, strides_t)
// `IDMA_TYPEDEF_ND_REQ_T(idma_nd_req_t, idma_req_t, idma_d_req_t)
`define IDMA_TYPEDEF_D_REQ_T(idma_d_req_t, reps_t, strides_t)            \
    typedef struct packed {                                              \
        reps_t    reps;                                                  \
        strides_t src_strides;                                           \
        strides_t dst_strides;                                           \
    } idma_d_req_t;
`define IDMA_TYPEDEF_ND_REQ_T(idma_nd_req_t, idma_req_t, idma_d_req_t)   \
    typedef struct packed {                                              \
        idma_req_t                burst_req;                             \
        idma_d_req_t [NumDim-2:0] d_req;                                 \
    } idma_nd_req_t;
////////////////////////////////////////////////////////////////////////////////////////////////////


////////////////////////////////////////////////////////////////////////////////////////////////////
// iDMA Full n-dimensional Request Struct
//
// Usage Example:
// `IDMA_TYPEDEF_FULL_ND_REQ_T(idma_nd_req_t, idma_req_t, reps_t, strides_t)
`define IDMA_TYPEDEF_FULL_ND_REQ_T(idma_nd_req_t, idma_req_t, reps_t, strides_t) \
    `IDMA_TYPEDEF_D_REQ_T(idma_d_req_t, reps_t, strides_t)                       \
    `IDMA_TYPEDEF_ND_REQ_T(idma_nd_req_t, idma_req_t, idma_d_req_t)
////////////////////////////////////////////////////////////////////////////////////////////////////

`define IDMA_OBI_TYPEDEF_A_CHAN_T(a_chan_t, addr_t, data_t, strb_t) \
  typedef struct packed {                                           \
    addr_t addr;                                                    \
    logic  we;                                                      \
    strb_t be;                                                      \
    data_t wdata;                                                   \
  } a_chan_t;

`define IDMA_OBI_TYPEDEF_R_CHAN_T(r_chan_t, data_t) \
  typedef struct packed {                           \
    data_t rdata;                                   \
  } r_chan_t;

`define IDMA_OBI_TYPEDEF_REQ_T(req_t, a_chan_t) \
  typedef struct packed {                       \
    a_chan_t a;                                 \
    logic     a_req;                            \
    logic  r_ready;                             \
  } req_t;

`define IDMA_OBI_TYPEDEF_RESP_T(resp_t, r_chan_t) \
  typedef struct packed {                         \
    logic     a_gnt;                              \
    r_chan_t r;                                   \
    logic  r_valid;                               \
  } resp_t;

`define IDMA_OBI_TYPEDEF_BIDIRECT_REQ_T(bidirect_req_t, req_t) \
  typedef struct packed {                                      \
    req_t write;                                               \
    req_t read;                                                \
  } bidirect_req_t;

`define IDMA_OBI_TYPEDEF_BIDIRECT_RESP_T(bidirect_resp_t, resp_t) \
  typedef struct packed {                                         \
    resp_t write;                                                 \
    resp_t read;                                                  \
  } bidirect_resp_t;

// Guard macros

`define IDMA_NONSYNTH_BLOCK(__block) \
`ifndef TARGET_SYNTHESIS             \
`ifndef TARGET_VERILATOR             \
`ifndef TARGET_XSIM                  \
`ifndef VERILATOR                    \
`ifndef SYNTHESIS                    \
`ifndef XSIM                         \
/* pragma translate_off */           \
__block                              \
/* pragma translate_on */            \
`endif                               \
`endif                               \
`endif                               \
`endif                               \
`endif                               \
`endif

`endif
