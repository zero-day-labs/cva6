// Copyright 2018 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

`include "register_interface/assign.svh"
`include "register_interface/typedef.svh"

// Xilinx Peripherals
module ariane_peripherals #(
    parameter int AxiAddrWidth = -1,
    parameter int AxiDataWidth = -1,
    parameter int AxiIdWidth   = -1,
    parameter int AxiUserWidth = 1,
    parameter bit InclUART     = 1,
    parameter bit InclSPI      = 0,
    parameter bit InclEthernet = 0,
    parameter bit InclGPIO     = 0,
    parameter bit InclTimer    = 1
) (
    input  logic       clk_i                                                , // Clock
    input  logic       rst_ni                                               , // Asynchronous reset active low
    AXI_BUS.Slave      aplic                                                ,
    AXI_BUS.Slave      uart                                                 ,
    AXI_BUS.Slave      spi                                                  ,
    AXI_BUS.Slave      ethernet                                             ,
    AXI_BUS.Slave      timer                                                ,
    // IMSIC
    AXI_BUS.Slave                                             imsic         ,
    input  imsic_pkg::csr_channel_to_imsic_t                  imsic_csr_i   , 
    output imsic_pkg::csr_channel_from_imsic_t                imsic_csr_o   ,
    output logic [ariane_soc::NrIntpFiles-1:0] irq_o                        ,
    // UART
    input  logic       rx_i                                                 ,
    output logic       tx_o                                                 ,
    // Ethernet
    input  wire        eth_txck                                             ,
    input  wire        eth_rxck                                             ,
    input  wire        eth_rxctl                                            ,
    input  wire [3:0]  eth_rxd                                              ,
    output wire        eth_rst_n                                            ,
    output wire        eth_tx_en                                            ,
    output wire [3:0]  eth_txd                                              ,
    inout  wire        phy_mdio                                             ,
    output logic       eth_mdc                                              ,
    // MDIO Interface
    inout              mdio                                                 ,
    output             mdc                                                  ,
    // SPI
    output logic       spi_clk_o                                            ,
    output logic       spi_mosi                                             ,
    input  logic       spi_miso                                             ,
    output logic       spi_ss
);

    // ---------------
    // 1. IRQC
    // ---------------
    localparam int unsigned UART_IRQ         = 32'd0;
    localparam int unsigned SPI_IRQ          = 32'd1;
    localparam int unsigned ETH_IRQ          = 32'd2;
    localparam int unsigned TIMER_FIRST_IRQ  = 32'd3;
    localparam int unsigned TIMER_LAST_IRQ   = 32'd6;
    localparam int unsigned LAST_IRQ         = TIMER_LAST_IRQ + 1;
    logic [ariane_soc::NumSources-1:0] irq_sources;

    // Unused interrupt sources
    assign irq_sources[ariane_soc::NumSources-1:LAST_IRQ] = '0;

    // APLIC configuration Bus (AXI => APB => REG)
    ariane_axi_soc::req_slv_t  aplic_cfg_req;
    ariane_axi_soc::resp_slv_t aplic_cfg_rsp;
    `AXI_ASSIGN_TO_REQ(aplic_cfg_req, aplic)
    `AXI_ASSIGN_FROM_RESP(aplic, aplic_cfg_rsp)

    REG_BUS #(
        .ADDR_WIDTH ( 32 ),
        .DATA_WIDTH ( 32 )
    ) aplic_reg_bus (clk_i);

    logic         aplic_penable;
    logic         aplic_pwrite;
    logic [31:0]  aplic_paddr;
    logic         aplic_psel;
    logic [31:0]  aplic_pwdata;
    logic [31:0]  aplic_prdata;
    logic         aplic_pready;
    logic         aplic_pslverr;

    axi2apb_64_32 #(
        .AXI4_ADDRESS_WIDTH ( AxiAddrWidth  ),
        .AXI4_RDATA_WIDTH   ( AxiDataWidth  ),
        .AXI4_WDATA_WIDTH   ( AxiDataWidth  ),
        .AXI4_ID_WIDTH      ( AxiIdWidth    ),
        .AXI4_USER_WIDTH    ( AxiUserWidth  ),
        .BUFF_DEPTH_SLAVE   ( 2             ),
        .APB_ADDR_WIDTH     ( 32            )
    ) i_axi2apb_64_32_aplic (
        .ACLK      ( clk_i          ),
        .ARESETn   ( rst_ni         ),
        .test_en_i ( 1'b0           ),
        // AW
        .AWID_i    ( aplic_cfg_req.aw.id     ),
        .AWADDR_i  ( aplic_cfg_req.aw.addr   ),
        .AWLEN_i   ( aplic_cfg_req.aw.len    ),
        .AWSIZE_i  ( aplic_cfg_req.aw.size   ),
        .AWBURST_i ( aplic_cfg_req.aw.burst  ),
        .AWLOCK_i  ( aplic_cfg_req.aw.lock   ),
        .AWCACHE_i ( aplic_cfg_req.aw.cache  ),
        .AWPROT_i  ( aplic_cfg_req.aw.prot   ),
        .AWREGION_i( aplic_cfg_req.aw.region ),
        .AWUSER_i  ( aplic_cfg_req.aw.user   ),
        .AWQOS_i   ( aplic_cfg_req.aw.qos    ),
        .AWVALID_i ( aplic_cfg_req.aw_valid  ),
        .AWREADY_o ( aplic_cfg_rsp.aw_ready ),
        // W
        .WDATA_i   ( aplic_cfg_req.w.data    ),
        .WSTRB_i   ( aplic_cfg_req.w.strb    ),
        .WLAST_i   ( aplic_cfg_req.w.last    ),
        .WUSER_i   ( aplic_cfg_req.w.user    ),
        .WVALID_i  ( aplic_cfg_req.w_valid   ),
        .WREADY_o  ( aplic_cfg_rsp.w_ready  ),
        // B
        .BID_o     ( aplic_cfg_rsp.b.id     ),
        .BRESP_o   ( aplic_cfg_rsp.b.resp   ),
        .BUSER_o   ( aplic_cfg_rsp.b.user   ),
        .BVALID_o  ( aplic_cfg_rsp.b_valid  ),
        .BREADY_i  ( aplic_cfg_req.b_ready   ),
        // AR
        .ARID_i    ( aplic_cfg_req.ar.id     ),
        .ARADDR_i  ( aplic_cfg_req.ar.addr   ),
        .ARLEN_i   ( aplic_cfg_req.ar.len    ),
        .ARSIZE_i  ( aplic_cfg_req.ar.size   ),
        .ARBURST_i ( aplic_cfg_req.ar.burst  ),
        .ARLOCK_i  ( aplic_cfg_req.ar.lock   ),
        .ARCACHE_i ( aplic_cfg_req.ar.cache  ),
        .ARPROT_i  ( aplic_cfg_req.ar.prot   ),
        .ARREGION_i( aplic_cfg_req.ar.region ),
        .ARUSER_i  ( aplic_cfg_req.ar.user   ),
        .ARQOS_i   ( aplic_cfg_req.ar.qos    ),
        .ARVALID_i ( aplic_cfg_req.ar_valid  ),
        .ARREADY_o ( aplic_cfg_rsp.ar_ready ),
        // R
        .RID_o     ( aplic_cfg_rsp.r.id     ),
        .RDATA_o   ( aplic_cfg_rsp.r.data   ),
        .RRESP_o   ( aplic_cfg_rsp.r.resp   ),
        .RLAST_o   ( aplic_cfg_rsp.r.last   ),
        .RUSER_o   ( aplic_cfg_rsp.r.user   ),
        .RVALID_o  ( aplic_cfg_rsp.r_valid  ),
        .RREADY_i  ( aplic_cfg_req.r_ready   ),
        // APB IF
        .PENABLE   ( aplic_penable   ),
        .PWRITE    ( aplic_pwrite    ),
        .PADDR     ( aplic_paddr     ),
        .PSEL      ( aplic_psel      ),
        .PWDATA    ( aplic_pwdata    ),
        .PRDATA    ( aplic_prdata    ),
        .PREADY    ( aplic_pready    ),
        .PSLVERR   ( aplic_pslverr   )
    );

    apb_to_reg i_aplic_apb_to_reg (
        .clk_i     ( clk_i         ),
        .rst_ni    ( rst_ni        ),
        .penable_i ( aplic_penable ),
        .pwrite_i  ( aplic_pwrite  ),
        .paddr_i   ( aplic_paddr   ),
        .psel_i    ( aplic_psel    ),
        .pwdata_i  ( aplic_pwdata  ),
        .prdata_o  ( aplic_prdata  ),
        .pready_o  ( aplic_pready  ),
        .pslverr_o ( aplic_pslverr ),
        .reg_o     ( aplic_reg_bus )
    );

    `REG_BUS_TYPEDEF_ALL(aplic_reg, ariane_axi_soc::addr_t, logic[31:0], logic[3:0])
    aplic_reg_req_t aplic_regmap_req;
    aplic_reg_rsp_t aplic_regmap_resp;
    `REG_BUS_ASSIGN_TO_REQ(aplic_regmap_req, aplic_reg_bus)
    `REG_BUS_ASSIGN_FROM_RSP(aplic_reg_bus, aplic_regmap_resp)

    // MSI Bus to signal interrupts to the IMSIC
    ariane_axi_soc::req_slv_t    msi_req;
    ariane_axi_soc::resp_slv_t   msi_resp;
    `AXI_ASSIGN_TO_REQ(msi_req, imsic)
    `AXI_ASSIGN_FROM_RESP(imsic, msi_resp)

    localparam imsic_protocol_pkg::protocol_cfg_t ImsicProtocolCfg = '{
        AXI_ADDR_WIDTH: AxiAddrWidth,
        AXI_DATA_WIDTH: AxiDataWidth,
        AXI_ID_WIDTH:   AxiIdWidth
    };

    assign irq_o = imsic_csr_o.Xeip_targets;
    
    aplic_top #(
        .AplicCfg       ( aplic_pkg::DefaultAplicCfg        ),
        .ImsicCfg       ( imsic_pkg::DefaultImsicCfg        ),
        .ProtocolCfg    ( ImsicProtocolCfg                  ),
        .reg_req_t      ( aplic_reg_req_t                   ),
        .reg_rsp_t      ( aplic_reg_rsp_t                   ),
        .axi_req_t      ( ariane_axi_soc::req_slv_t         ),
        .axi_resp_t     ( ariane_axi_soc::resp_slv_t        )
    ) aplic_top_embedded_i (
        .i_clk          ( clk_i                             ),
        .ni_rst         ( rst_ni                            ),
        .i_irq_sources  ( {irq_sources[ariane_soc::NumSources-2:0], 1'b0}),
        .i_req_cfg      ( aplic_regmap_req                  ),
        .o_resp_cfg     ( aplic_regmap_resp                 ),
        .i_imsic_csr    ( imsic_csr_i                       ),
        .o_imsic_csr    ( imsic_csr_o                       ),         
        .i_imsic_req    ( msi_req                           ),
        .o_imsic_resp   ( msi_resp                          )
    );

    // ---------------
    // 2. UART
    // ---------------
    logic         uart_penable;
    logic         uart_pwrite;
    logic [31:0]  uart_paddr;
    logic         uart_psel;
    logic [31:0]  uart_pwdata;
    logic [31:0]  uart_prdata;
    logic         uart_pready;
    logic         uart_pslverr;

    axi2apb_64_32 #(
        .AXI4_ADDRESS_WIDTH ( AxiAddrWidth ),
        .AXI4_RDATA_WIDTH   ( AxiDataWidth ),
        .AXI4_WDATA_WIDTH   ( AxiDataWidth ),
        .AXI4_ID_WIDTH      ( AxiIdWidth   ),
        .AXI4_USER_WIDTH    ( AxiUserWidth ),
        .BUFF_DEPTH_SLAVE   ( 2            ),
        .APB_ADDR_WIDTH     ( 32           )
    ) i_axi2apb_64_32_uart (
        .ACLK      ( clk_i          ),
        .ARESETn   ( rst_ni         ),
        .test_en_i ( 1'b0           ),
        .AWID_i    ( uart.aw_id     ),
        .AWADDR_i  ( uart.aw_addr   ),
        .AWLEN_i   ( uart.aw_len    ),
        .AWSIZE_i  ( uart.aw_size   ),
        .AWBURST_i ( uart.aw_burst  ),
        .AWLOCK_i  ( uart.aw_lock   ),
        .AWCACHE_i ( uart.aw_cache  ),
        .AWPROT_i  ( uart.aw_prot   ),
        .AWREGION_i( uart.aw_region ),
        .AWUSER_i  ( uart.aw_user   ),
        .AWQOS_i   ( uart.aw_qos    ),
        .AWVALID_i ( uart.aw_valid  ),
        .AWREADY_o ( uart.aw_ready  ),
        .WDATA_i   ( uart.w_data    ),
        .WSTRB_i   ( uart.w_strb    ),
        .WLAST_i   ( uart.w_last    ),
        .WUSER_i   ( uart.w_user    ),
        .WVALID_i  ( uart.w_valid   ),
        .WREADY_o  ( uart.w_ready   ),
        .BID_o     ( uart.b_id      ),
        .BRESP_o   ( uart.b_resp    ),
        .BVALID_o  ( uart.b_valid   ),
        .BUSER_o   ( uart.b_user    ),
        .BREADY_i  ( uart.b_ready   ),
        .ARID_i    ( uart.ar_id     ),
        .ARADDR_i  ( uart.ar_addr   ),
        .ARLEN_i   ( uart.ar_len    ),
        .ARSIZE_i  ( uart.ar_size   ),
        .ARBURST_i ( uart.ar_burst  ),
        .ARLOCK_i  ( uart.ar_lock   ),
        .ARCACHE_i ( uart.ar_cache  ),
        .ARPROT_i  ( uart.ar_prot   ),
        .ARREGION_i( uart.ar_region ),
        .ARUSER_i  ( uart.ar_user   ),
        .ARQOS_i   ( uart.ar_qos    ),
        .ARVALID_i ( uart.ar_valid  ),
        .ARREADY_o ( uart.ar_ready  ),
        .RID_o     ( uart.r_id      ),
        .RDATA_o   ( uart.r_data    ),
        .RRESP_o   ( uart.r_resp    ),
        .RLAST_o   ( uart.r_last    ),
        .RUSER_o   ( uart.r_user    ),
        .RVALID_o  ( uart.r_valid   ),
        .RREADY_i  ( uart.r_ready   ),
        .PENABLE   ( uart_penable   ),
        .PWRITE    ( uart_pwrite    ),
        .PADDR     ( uart_paddr     ),
        .PSEL      ( uart_psel      ),
        .PWDATA    ( uart_pwdata    ),
        .PRDATA    ( uart_prdata    ),
        .PREADY    ( uart_pready    ),
        .PSLVERR   ( uart_pslverr   )
    );

    if (InclUART) begin : gen_uart
        apb_uart i_apb_uart (
            .CLK     ( clk_i           ),
            .RSTN    ( rst_ni          ),
            .PSEL    ( uart_psel       ),
            .PENABLE ( uart_penable    ),
            .PWRITE  ( uart_pwrite     ),
            .PADDR   ( uart_paddr[4:2] ),
            .PWDATA  ( uart_pwdata     ),
            .PRDATA  ( uart_prdata     ),
            .PREADY  ( uart_pready     ),
            .PSLVERR ( uart_pslverr    ),
            .INT     ( irq_sources[UART_IRQ]  ),
            .OUT1N   (                 ), // keep open
            .OUT2N   (                 ), // keep open
            .RTSN    (                 ), // no flow control
            .DTRN    (                 ), // no flow control
            .CTSN    ( 1'b0            ),
            .DSRN    ( 1'b0            ),
            .DCDN    ( 1'b0            ),
            .RIN     ( 1'b0            ),
            .SIN     ( rx_i            ),
            .SOUT    ( tx_o            )
        );
    end else begin
        assign irq_sources[UART_IRQ] = 1'b0;
        /* pragma translate_off */
        mock_uart i_mock_uart (
            .clk_i     ( clk_i        ),
            .rst_ni    ( rst_ni       ),
            .penable_i ( uart_penable ),
            .pwrite_i  ( uart_pwrite  ),
            .paddr_i   ( uart_paddr   ),
            .psel_i    ( uart_psel    ),
            .pwdata_i  ( uart_pwdata  ),
            .prdata_o  ( uart_prdata  ),
            .pready_o  ( uart_pready  ),
            .pslverr_o ( uart_pslverr )
        );
        /* pragma translate_on */
    end

    // ---------------
    // 3. SPI
    // ---------------
    if (InclSPI) begin : gen_spi
        logic [31:0] s_axi_spi_awaddr;
        logic [7:0]  s_axi_spi_awlen;
        logic [2:0]  s_axi_spi_awsize;
        logic [1:0]  s_axi_spi_awburst;
        logic [0:0]  s_axi_spi_awlock;
        logic [3:0]  s_axi_spi_awcache;
        logic [2:0]  s_axi_spi_awprot;
        logic [3:0]  s_axi_spi_awregion;
        logic [3:0]  s_axi_spi_awqos;
        logic        s_axi_spi_awvalid;
        logic        s_axi_spi_awready;
        logic [31:0] s_axi_spi_wdata;
        logic [3:0]  s_axi_spi_wstrb;
        logic        s_axi_spi_wlast;
        logic        s_axi_spi_wvalid;
        logic        s_axi_spi_wready;
        logic [1:0]  s_axi_spi_bresp;
        logic        s_axi_spi_bvalid;
        logic        s_axi_spi_bready;
        logic [31:0] s_axi_spi_araddr;
        logic [7:0]  s_axi_spi_arlen;
        logic [2:0]  s_axi_spi_arsize;
        logic [1:0]  s_axi_spi_arburst;
        logic [0:0]  s_axi_spi_arlock;
        logic [3:0]  s_axi_spi_arcache;
        logic [2:0]  s_axi_spi_arprot;
        logic [3:0]  s_axi_spi_arregion;
        logic [3:0]  s_axi_spi_arqos;
        logic        s_axi_spi_arvalid;
        logic        s_axi_spi_arready;
        logic [31:0] s_axi_spi_rdata;
        logic [1:0]  s_axi_spi_rresp;
        logic        s_axi_spi_rlast;
        logic        s_axi_spi_rvalid;
        logic        s_axi_spi_rready;

        xlnx_axi_clock_converter i_xlnx_axi_clock_converter_spi (
            .s_axi_aclk     ( clk_i              ),
            .s_axi_aresetn  ( rst_ni             ),

            .s_axi_awid     ( spi.aw_id          ),
            .s_axi_awaddr   ( spi.aw_addr[31:0]  ),
            .s_axi_awlen    ( spi.aw_len         ),
            .s_axi_awsize   ( spi.aw_size        ),
            .s_axi_awburst  ( spi.aw_burst       ),
            .s_axi_awlock   ( spi.aw_lock        ),
            .s_axi_awcache  ( spi.aw_cache       ),
            .s_axi_awprot   ( spi.aw_prot        ),
            .s_axi_awregion ( spi.aw_region      ),
            .s_axi_awqos    ( spi.aw_qos         ),
            .s_axi_awvalid  ( spi.aw_valid       ),
            .s_axi_awready  ( spi.aw_ready       ),
            .s_axi_wdata    ( spi.w_data         ),
            .s_axi_wstrb    ( spi.w_strb         ),
            .s_axi_wlast    ( spi.w_last         ),
            .s_axi_wvalid   ( spi.w_valid        ),
            .s_axi_wready   ( spi.w_ready        ),
            .s_axi_bid      ( spi.b_id           ),
            .s_axi_bresp    ( spi.b_resp         ),
            .s_axi_bvalid   ( spi.b_valid        ),
            .s_axi_bready   ( spi.b_ready        ),
            .s_axi_arid     ( spi.ar_id          ),
            .s_axi_araddr   ( spi.ar_addr[31:0]  ),
            .s_axi_arlen    ( spi.ar_len         ),
            .s_axi_arsize   ( spi.ar_size        ),
            .s_axi_arburst  ( spi.ar_burst       ),
            .s_axi_arlock   ( spi.ar_lock        ),
            .s_axi_arcache  ( spi.ar_cache       ),
            .s_axi_arprot   ( spi.ar_prot        ),
            .s_axi_arregion ( spi.ar_region      ),
            .s_axi_arqos    ( spi.ar_qos         ),
            .s_axi_arvalid  ( spi.ar_valid       ),
            .s_axi_arready  ( spi.ar_ready       ),
            .s_axi_rid      ( spi.r_id           ),
            .s_axi_rdata    ( spi.r_data         ),
            .s_axi_rresp    ( spi.r_resp         ),
            .s_axi_rlast    ( spi.r_last         ),
            .s_axi_rvalid   ( spi.r_valid        ),
            .s_axi_rready   ( spi.r_ready        ),

            .m_axi_awaddr   ( s_axi_spi_awaddr   ),
            .m_axi_awlen    ( s_axi_spi_awlen    ),
            .m_axi_awsize   ( s_axi_spi_awsize   ),
            .m_axi_awburst  ( s_axi_spi_awburst  ),
            .m_axi_awlock   ( s_axi_spi_awlock   ),
            .m_axi_awcache  ( s_axi_spi_awcache  ),
            .m_axi_awprot   ( s_axi_spi_awprot   ),
            .m_axi_awregion ( s_axi_spi_awregion ),
            .m_axi_awqos    ( s_axi_spi_awqos    ),
            .m_axi_awvalid  ( s_axi_spi_awvalid  ),
            .m_axi_awready  ( s_axi_spi_awready  ),
            .m_axi_wdata    ( s_axi_spi_wdata    ),
            .m_axi_wstrb    ( s_axi_spi_wstrb    ),
            .m_axi_wlast    ( s_axi_spi_wlast    ),
            .m_axi_wvalid   ( s_axi_spi_wvalid   ),
            .m_axi_wready   ( s_axi_spi_wready   ),
            .m_axi_bresp    ( s_axi_spi_bresp    ),
            .m_axi_bvalid   ( s_axi_spi_bvalid   ),
            .m_axi_bready   ( s_axi_spi_bready   ),
            .m_axi_araddr   ( s_axi_spi_araddr   ),
            .m_axi_arlen    ( s_axi_spi_arlen    ),
            .m_axi_arsize   ( s_axi_spi_arsize   ),
            .m_axi_arburst  ( s_axi_spi_arburst  ),
            .m_axi_arlock   ( s_axi_spi_arlock   ),
            .m_axi_arcache  ( s_axi_spi_arcache  ),
            .m_axi_arprot   ( s_axi_spi_arprot   ),
            .m_axi_arregion ( s_axi_spi_arregion ),
            .m_axi_arqos    ( s_axi_spi_arqos    ),
            .m_axi_arvalid  ( s_axi_spi_arvalid  ),
            .m_axi_arready  ( s_axi_spi_arready  ),
            .m_axi_rdata    ( s_axi_spi_rdata    ),
            .m_axi_rresp    ( s_axi_spi_rresp    ),
            .m_axi_rlast    ( s_axi_spi_rlast    ),
            .m_axi_rvalid   ( s_axi_spi_rvalid   ),
            .m_axi_rready   ( s_axi_spi_rready   )
        );

        xlnx_axi_quad_spi i_xlnx_axi_quad_spi (
            .ext_spi_clk    ( clk_i                  ),
            .s_axi4_aclk    ( clk_i                  ),
            .s_axi4_aresetn ( rst_ni                 ),
            .s_axi4_awaddr  ( s_axi_spi_awaddr[23:0] ),
            .s_axi4_awlen   ( s_axi_spi_awlen        ),
            .s_axi4_awsize  ( s_axi_spi_awsize       ),
            .s_axi4_awburst ( s_axi_spi_awburst      ),
            .s_axi4_awlock  ( s_axi_spi_awlock       ),
            .s_axi4_awcache ( s_axi_spi_awcache      ),
            .s_axi4_awprot  ( s_axi_spi_awprot       ),
            .s_axi4_awvalid ( s_axi_spi_awvalid      ),
            .s_axi4_awready ( s_axi_spi_awready      ),
            .s_axi4_wdata   ( s_axi_spi_wdata        ),
            .s_axi4_wstrb   ( s_axi_spi_wstrb        ),
            .s_axi4_wlast   ( s_axi_spi_wlast        ),
            .s_axi4_wvalid  ( s_axi_spi_wvalid       ),
            .s_axi4_wready  ( s_axi_spi_wready       ),
            .s_axi4_bresp   ( s_axi_spi_bresp        ),
            .s_axi4_bvalid  ( s_axi_spi_bvalid       ),
            .s_axi4_bready  ( s_axi_spi_bready       ),
            .s_axi4_araddr  ( s_axi_spi_araddr[23:0] ),
            .s_axi4_arlen   ( s_axi_spi_arlen        ),
            .s_axi4_arsize  ( s_axi_spi_arsize       ),
            .s_axi4_arburst ( s_axi_spi_arburst      ),
            .s_axi4_arlock  ( s_axi_spi_arlock       ),
            .s_axi4_arcache ( s_axi_spi_arcache      ),
            .s_axi4_arprot  ( s_axi_spi_arprot       ),
            .s_axi4_arvalid ( s_axi_spi_arvalid      ),
            .s_axi4_arready ( s_axi_spi_arready      ),
            .s_axi4_rdata   ( s_axi_spi_rdata        ),
            .s_axi4_rresp   ( s_axi_spi_rresp        ),
            .s_axi4_rlast   ( s_axi_spi_rlast        ),
            .s_axi4_rvalid  ( s_axi_spi_rvalid       ),
            .s_axi4_rready  ( s_axi_spi_rready       ),

            .io0_i          ( '0                     ),
            .io0_o          ( spi_mosi               ),
            .io0_t          ( '0                     ),
            .io1_i          ( spi_miso               ),
            .io1_o          (                        ),
            .io1_t          ( '0                     ),
            .ss_i           ( '0                     ),
            .ss_o           ( spi_ss                 ),
            .ss_t           ( '0                     ),
            .sck_o          ( spi_clk_o              ),
            .sck_i          ( '0                     ),
            .sck_t          (                        ),
            .ip2intc_irpt   ( irq_sources[SPI_IRQ]   )
        );
        // assign irq_sources [SPI_IRQ] = 1'b0;
    end else begin
        assign spi_clk_o = 1'b0;
        assign spi_mosi = 1'b0;
        assign spi_ss = 1'b0;

        assign irq_sources [SPI_IRQ] = 1'b0;
        assign spi.aw_ready = 1'b1;
        assign spi.ar_ready = 1'b1;
        assign spi.w_ready = 1'b1;

        assign spi.b_valid = spi.aw_valid;
        assign spi.b_id = spi.aw_id;
        assign spi.b_resp = axi_pkg::RESP_SLVERR;
        assign spi.b_user = '0;

        assign spi.r_valid = spi.ar_valid;
        assign spi.r_resp = axi_pkg::RESP_SLVERR;
        assign spi.r_data = 'hdeadbeef;
        assign spi.r_last = 1'b1;
    end


    // ---------------
    // 4. Ethernet
    // ---------------
    if (0)
      begin
      end
    else
      begin
        assign irq_sources [ETH_IRQ] = 1'b0;
        assign ethernet.aw_ready = 1'b1;
        assign ethernet.ar_ready = 1'b1;
        assign ethernet.w_ready = 1'b1;

        assign ethernet.b_valid = ethernet.aw_valid;
        assign ethernet.b_id = ethernet.aw_id;
        assign ethernet.b_resp = axi_pkg::RESP_SLVERR;
        assign ethernet.b_user = '0;

        assign ethernet.r_valid = ethernet.ar_valid;
        assign ethernet.r_resp = axi_pkg::RESP_SLVERR;
        assign ethernet.r_data = 'hdeadbeef;
        assign ethernet.r_last = 1'b1;
    end

    // ---------------
    // 5. Timer
    // ---------------
    if (InclTimer) begin : gen_timer
        logic         timer_penable;
        logic         timer_pwrite;
        logic [31:0]  timer_paddr;
        logic         timer_psel;
        logic [31:0]  timer_pwdata;
        logic [31:0]  timer_prdata;
        logic         timer_pready;
        logic         timer_pslverr;

        axi2apb_64_32 #(
            .AXI4_ADDRESS_WIDTH ( AxiAddrWidth ),
            .AXI4_RDATA_WIDTH   ( AxiDataWidth ),
            .AXI4_WDATA_WIDTH   ( AxiDataWidth ),
            .AXI4_ID_WIDTH      ( AxiIdWidth   ),
            .AXI4_USER_WIDTH    ( AxiUserWidth ),
            .BUFF_DEPTH_SLAVE   ( 2            ),
            .APB_ADDR_WIDTH     ( 32           )
        ) i_axi2apb_64_32_timer (
            .ACLK      ( clk_i           ),
            .ARESETn   ( rst_ni          ),
            .test_en_i ( 1'b0            ),
            .AWID_i    ( timer.aw_id     ),
            .AWADDR_i  ( timer.aw_addr   ),
            .AWLEN_i   ( timer.aw_len    ),
            .AWSIZE_i  ( timer.aw_size   ),
            .AWBURST_i ( timer.aw_burst  ),
            .AWLOCK_i  ( timer.aw_lock   ),
            .AWCACHE_i ( timer.aw_cache  ),
            .AWPROT_i  ( timer.aw_prot   ),
            .AWREGION_i( timer.aw_region ),
            .AWUSER_i  ( timer.aw_user   ),
            .AWQOS_i   ( timer.aw_qos    ),
            .AWVALID_i ( timer.aw_valid  ),
            .AWREADY_o ( timer.aw_ready  ),
            .WDATA_i   ( timer.w_data    ),
            .WSTRB_i   ( timer.w_strb    ),
            .WLAST_i   ( timer.w_last    ),
            .WUSER_i   ( timer.w_user    ),
            .WVALID_i  ( timer.w_valid   ),
            .WREADY_o  ( timer.w_ready   ),
            .BID_o     ( timer.b_id      ),
            .BRESP_o   ( timer.b_resp    ),
            .BVALID_o  ( timer.b_valid   ),
            .BUSER_o   ( timer.b_user    ),
            .BREADY_i  ( timer.b_ready   ),
            .ARID_i    ( timer.ar_id     ),
            .ARADDR_i  ( timer.ar_addr   ),
            .ARLEN_i   ( timer.ar_len    ),
            .ARSIZE_i  ( timer.ar_size   ),
            .ARBURST_i ( timer.ar_burst  ),
            .ARLOCK_i  ( timer.ar_lock   ),
            .ARCACHE_i ( timer.ar_cache  ),
            .ARPROT_i  ( timer.ar_prot   ),
            .ARREGION_i( timer.ar_region ),
            .ARUSER_i  ( timer.ar_user   ),
            .ARQOS_i   ( timer.ar_qos    ),
            .ARVALID_i ( timer.ar_valid  ),
            .ARREADY_o ( timer.ar_ready  ),
            .RID_o     ( timer.r_id      ),
            .RDATA_o   ( timer.r_data    ),
            .RRESP_o   ( timer.r_resp    ),
            .RLAST_o   ( timer.r_last    ),
            .RUSER_o   ( timer.r_user    ),
            .RVALID_o  ( timer.r_valid   ),
            .RREADY_i  ( timer.r_ready   ),
            .PENABLE   ( timer_penable   ),
            .PWRITE    ( timer_pwrite    ),
            .PADDR     ( timer_paddr     ),
            .PSEL      ( timer_psel      ),
            .PWDATA    ( timer_pwdata    ),
            .PRDATA    ( timer_prdata    ),
            .PREADY    ( timer_pready    ),
            .PSLVERR   ( timer_pslverr   )
        );

        apb_timer #(
                .APB_ADDR_WIDTH ( 32 ),
                .TIMER_CNT      ( 2  )
        ) i_timer (
            .HCLK    ( clk_i            ),
            .HRESETn ( rst_ni           ),
            .PSEL    ( timer_psel       ),
            .PENABLE ( timer_penable    ),
            .PWRITE  ( timer_pwrite     ),
            .PADDR   ( timer_paddr      ),
            .PWDATA  ( timer_pwdata     ),
            .PRDATA  ( timer_prdata     ),
            .PREADY  ( timer_pready     ),
            .PSLVERR ( timer_pslverr    ),
            .irq_o   ( irq_sources[TIMER_LAST_IRQ:TIMER_FIRST_IRQ] )
        );
    end
endmodule
