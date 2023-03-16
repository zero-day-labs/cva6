// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Register Package auto-generated by `reggen` containing data structure
//
//
// Edited by: Manuel Rodríguez <manuel.cederog@gmail.com>
// Edited at: 13/10/2022
//
// Changes: Regtool/reggen does not allow to specify some particular details of the register map structure.
// Thus, it was necessary to edit some parts of the code:
//  - Register offsets
//  - Registers legal writability masks

`ifndef IOMMU_REG_PKG_DEF // if the already-compiled flag is not set...
`define IOMMU_REG_PKG_DEF // set the flag

package iommu_reg_pkg;

  // Address widths within the block
  parameter int BlockAw = 13;

  ////////////////////////////
  // Typedefs for registers //
  ////////////////////////////

  typedef struct packed {
    struct packed {
      logic [7:0]  q;
    } version;
    struct packed {
      logic        q;
    } sv32;
    struct packed {
      logic        q;
    } sv39;
    struct packed {
      logic        q;
    } sv48;
    struct packed {
      logic        q;
    } sv57;
    struct packed {
      logic        q;
    } svpbmt;
    struct packed {
      logic        q;
    } sv32x4;
    struct packed {
      logic        q;
    } sv39x4;
    struct packed {
      logic        q;
    } sv48x4;
    struct packed {
      logic        q;
    } sv57x4;
    struct packed {
      logic        q;
    } msi_flat;
    struct packed {
      logic        q;
    } msi_mrif;
    struct packed {
      logic        q;
    } amo;
    struct packed {
      logic        q;
    } ats;
    struct packed {
      logic        q;
    } t2gpa;
    struct packed {
      logic        q;
    } endi;
    struct packed {
      logic [1:0]  q;
    } igs;
    struct packed {
      logic        q;
    } hpm;
    struct packed {
      logic        q;
    } dbg;
    struct packed {
      logic [5:0]  q;
    } pas;
    struct packed {
      logic        q;
    } pd8;
    struct packed {
      logic        q;
    } pd17;
    struct packed {
      logic        q;
    } pd20;
  } iommu_reg2hw_capabilities_reg_t;

  typedef struct packed {
    struct packed {
      logic        q;
    } be;
    struct packed {
      logic        q;
    } wsi;
    struct packed {
      logic        q;
    } glx;
  } iommu_reg2hw_fctl_reg_t;

  typedef struct packed {
    struct packed {
      logic [3:0]  q;
    } iommu_mode;
    struct packed {
      logic        q;
    } busy;
    struct packed {
      logic [43:0] q;
    } ppn;
  } iommu_reg2hw_ddtp_reg_t;

  typedef struct packed {
    struct packed {
      logic [4:0]  q;
    } log2sz_1;
    struct packed {
      logic [43:0] q;
    } ppn;
  } iommu_reg2hw_cqb_reg_t;

  typedef struct packed {
    logic [31:0] q;
  } iommu_reg2hw_cqh_reg_t;

  typedef struct packed {
    logic [31:0] q;
  } iommu_reg2hw_cqt_reg_t;

  typedef struct packed {
    struct packed {
      logic [4:0]  q;
    } log2sz_1;
    struct packed {
      logic [43:0] q;
    } ppn;
  } iommu_reg2hw_fqb_reg_t;

  typedef struct packed {
    logic [31:0] q;
  } iommu_reg2hw_fqh_reg_t;

  typedef struct packed {
    logic [31:0] q;
  } iommu_reg2hw_fqt_reg_t;

  typedef struct packed {
    struct packed {
      logic        q;
    } cqen;
    struct packed {
      logic        q;
    } cie;
    struct packed {
      logic        q;
    } cqmf;
    struct packed {
      logic        q;
    } cmd_to;
    struct packed {
      logic        q;
    } cmd_ill;
    struct packed {
      logic        q;
    } fence_w_ip;
    struct packed {
      logic        q;
    } cqon;
    struct packed {
      logic        q;
    } busy;
  } iommu_reg2hw_cqcsr_reg_t;

  typedef struct packed {
    struct packed {
      logic        q;
    } fqen;
    struct packed {
      logic        q;
    } fie;
    struct packed {
      logic        q;
    } fqmf;
    struct packed {
      logic        q;
    } fqof;
    struct packed {
      logic        q;
    } fqon;
    struct packed {
      logic        q;
    } busy;
  } iommu_reg2hw_fqcsr_reg_t;

  typedef struct packed {
    struct packed {
      logic        q;
    } cip;
    struct packed {
      logic        q;
    } fip;
    struct packed {
      logic        q;
    } pmip;
    struct packed {
      logic        q;
    } pip;
  } iommu_reg2hw_ipsr_reg_t;

  typedef struct packed {
    struct packed {
      logic [3:0]  q;
    } civ;
    struct packed {
      logic [3:0]  q;
    } fiv;
    struct packed {
      logic [3:0]  q;
    } pmiv;
    struct packed {
      logic [3:0]  q;
    } piv;
  } iommu_reg2hw_icvec_reg_t;

  typedef struct packed {
    struct packed {
      logic [53:0] q;
    } addr;
  } iommu_reg2hw_msi_addr_0_reg_t;

  typedef struct packed {
    logic [31:0] q;
  } iommu_reg2hw_msi_data_0_reg_t;

  typedef struct packed {
    logic        q;
  } iommu_reg2hw_msi_vec_ctl_0_reg_t;

  typedef struct packed {
    struct packed {
      logic [53:0] q;
    } addr;
  } iommu_reg2hw_msi_addr_1_reg_t;

  typedef struct packed {
    logic [31:0] q;
  } iommu_reg2hw_msi_data_1_reg_t;

  typedef struct packed {
    logic        q;
  } iommu_reg2hw_msi_vec_ctl_1_reg_t;

  typedef struct packed {
    struct packed {
      logic [53:0] q;
    } addr;
  } iommu_reg2hw_msi_addr_2_reg_t;

  typedef struct packed {
    logic [31:0] q;
  } iommu_reg2hw_msi_data_2_reg_t;

  typedef struct packed {
    logic        q;
  } iommu_reg2hw_msi_vec_ctl_2_reg_t;

  typedef struct packed {
    struct packed {
      logic [53:0] q;
    } addr;
  } iommu_reg2hw_msi_addr_3_reg_t;

  typedef struct packed {
    logic [31:0] q;
  } iommu_reg2hw_msi_data_3_reg_t;

  typedef struct packed {
    logic        q;
  } iommu_reg2hw_msi_vec_ctl_3_reg_t;

  typedef struct packed {
    struct packed {
      logic [53:0] q;
    } addr;
  } iommu_reg2hw_msi_addr_4_reg_t;

  typedef struct packed {
    logic [31:0] q;
  } iommu_reg2hw_msi_data_4_reg_t;

  typedef struct packed {
    logic        q;
  } iommu_reg2hw_msi_vec_ctl_4_reg_t;

  typedef struct packed {
    struct packed {
      logic [53:0] q;
    } addr;
  } iommu_reg2hw_msi_addr_5_reg_t;

  typedef struct packed {
    logic [31:0] q;
  } iommu_reg2hw_msi_data_5_reg_t;

  typedef struct packed {
    logic        q;
  } iommu_reg2hw_msi_vec_ctl_5_reg_t;

  typedef struct packed {
    struct packed {
      logic [53:0] q;
    } addr;
  } iommu_reg2hw_msi_addr_6_reg_t;

  typedef struct packed {
    logic [31:0] q;
  } iommu_reg2hw_msi_data_6_reg_t;

  typedef struct packed {
    logic        q;
  } iommu_reg2hw_msi_vec_ctl_6_reg_t;

  typedef struct packed {
    struct packed {
      logic [53:0] q;
    } addr;
  } iommu_reg2hw_msi_addr_7_reg_t;

  typedef struct packed {
    logic [31:0] q;
  } iommu_reg2hw_msi_data_7_reg_t;

  typedef struct packed {
    logic        q;
  } iommu_reg2hw_msi_vec_ctl_7_reg_t;

  typedef struct packed {
    struct packed {
      logic [53:0] q;
    } addr;
  } iommu_reg2hw_msi_addr_8_reg_t;

  typedef struct packed {
    logic [31:0] q;
  } iommu_reg2hw_msi_data_8_reg_t;

  typedef struct packed {
    logic        q;
  } iommu_reg2hw_msi_vec_ctl_8_reg_t;

  typedef struct packed {
    struct packed {
      logic [53:0] q;
    } addr;
  } iommu_reg2hw_msi_addr_9_reg_t;

  typedef struct packed {
    logic [31:0] q;
  } iommu_reg2hw_msi_data_9_reg_t;

  typedef struct packed {
    logic        q;
  } iommu_reg2hw_msi_vec_ctl_9_reg_t;

  typedef struct packed {
    struct packed {
      logic [53:0] q;
    } addr;
  } iommu_reg2hw_msi_addr_10_reg_t;

  typedef struct packed {
    logic [31:0] q;
  } iommu_reg2hw_msi_data_10_reg_t;

  typedef struct packed {
    logic        q;
  } iommu_reg2hw_msi_vec_ctl_10_reg_t;

  typedef struct packed {
    struct packed {
      logic [53:0] q;
    } addr;
  } iommu_reg2hw_msi_addr_11_reg_t;

  typedef struct packed {
    logic [31:0] q;
  } iommu_reg2hw_msi_data_11_reg_t;

  typedef struct packed {
    logic        q;
  } iommu_reg2hw_msi_vec_ctl_11_reg_t;

  typedef struct packed {
    struct packed {
      logic [53:0] q;
    } addr;
  } iommu_reg2hw_msi_addr_12_reg_t;

  typedef struct packed {
    logic [31:0] q;
  } iommu_reg2hw_msi_data_12_reg_t;

  typedef struct packed {
    logic        q;
  } iommu_reg2hw_msi_vec_ctl_12_reg_t;

  typedef struct packed {
    struct packed {
      logic [53:0] q;
    } addr;
  } iommu_reg2hw_msi_addr_13_reg_t;

  typedef struct packed {
    logic [31:0] q;
  } iommu_reg2hw_msi_data_13_reg_t;

  typedef struct packed {
    logic        q;
  } iommu_reg2hw_msi_vec_ctl_13_reg_t;

  typedef struct packed {
    struct packed {
      logic [53:0] q;
    } addr;
  } iommu_reg2hw_msi_addr_14_reg_t;

  typedef struct packed {
    logic [31:0] q;
  } iommu_reg2hw_msi_data_14_reg_t;

  typedef struct packed {
    logic        q;
  } iommu_reg2hw_msi_vec_ctl_14_reg_t;

  typedef struct packed {
    struct packed {
      logic [53:0] q;
    } addr;
  } iommu_reg2hw_msi_addr_15_reg_t;

  typedef struct packed {
    logic [31:0] q;
  } iommu_reg2hw_msi_data_15_reg_t;

  typedef struct packed {
    logic        q;
  } iommu_reg2hw_msi_vec_ctl_15_reg_t;

  typedef struct packed {
    struct packed {
      logic        d;
      logic        de;
    } be;
    struct packed {
      logic        d;
      logic        de;
    } wsi;
    struct packed {
      logic        d;
      logic        de;
    } glx;
  } iommu_hw2reg_fctl_reg_t;

  typedef struct packed {
    struct packed {
      logic [3:0]  d;
      logic        de;
    } iommu_mode;
    struct packed {
      logic        d;
      logic        de;
    } busy;
    struct packed {
      logic [43:0] d;
      logic        de;
    } ppn;
  } iommu_hw2reg_ddtp_reg_t;

  typedef struct packed {
    struct packed {
      logic [4:0]  d;
      logic        de;
    } log2sz_1;
    struct packed {
      logic [43:0] d;
      logic        de;
    } ppn;
  } iommu_hw2reg_cqb_reg_t;

  typedef struct packed {
    logic [31:0] d;
    logic        de;
  } iommu_hw2reg_cqh_reg_t;

  typedef struct packed {
    logic [31:0] d;
    logic        de;
  } iommu_hw2reg_cqt_reg_t;

  typedef struct packed {
    struct packed {
      logic [4:0]  d;
      logic        de;
    } log2sz_1;
    struct packed {
      logic [43:0] d;
      logic        de;
    } ppn;
  } iommu_hw2reg_fqb_reg_t;

  typedef struct packed {
    logic [31:0] d;
    logic        de;
  } iommu_hw2reg_fqh_reg_t;

  typedef struct packed {
    logic [31:0] d;
    logic        de;
  } iommu_hw2reg_fqt_reg_t;

  typedef struct packed {
    struct packed {
      logic        d;
      logic        de;
    } cqen;
    struct packed {
      logic        d;
      logic        de;
    } cie;
    struct packed {
      logic        d;
      logic        de;
    } cqmf;
    struct packed {
      logic        d;
      logic        de;
    } cmd_to;
    struct packed {
      logic        d;
      logic        de;
    } cmd_ill;
    struct packed {
      logic        d;
      logic        de;
    } fence_w_ip;
    struct packed {
      logic        d;
      logic        de;
    } cqon;
    struct packed {
      logic        d;
      logic        de;
    } busy;
  } iommu_hw2reg_cqcsr_reg_t;

  typedef struct packed {
    struct packed {
      logic        d;
      logic        de;
    } fqen;
    struct packed {
      logic        d;
      logic        de;
    } fie;
    struct packed {
      logic        d;
      logic        de;
    } fqmf;
    struct packed {
      logic        d;
      logic        de;
    } fqof;
    struct packed {
      logic        d;
      logic        de;
    } fqon;
    struct packed {
      logic        d;
      logic        de;
    } busy;
  } iommu_hw2reg_fqcsr_reg_t;

  typedef struct packed {
    struct packed {
      logic        d;
      logic        de;
    } cip;
    struct packed {
      logic        d;
      logic        de;
    } fip;
    struct packed {
      logic        d;
      logic        de;
    } pmip;
    struct packed {
      logic        d;
      logic        de;
    } pip;
  } iommu_hw2reg_ipsr_reg_t;

  typedef struct packed {
    struct packed {
      logic [3:0]  d;
      logic        de;
    } civ;
    struct packed {
      logic [3:0]  d;
      logic        de;
    } fiv;
    struct packed {
      logic [3:0]  d;
      logic        de;
    } pmiv;
    struct packed {
      logic [3:0]  d;
      logic        de;
    } piv;
  } iommu_hw2reg_icvec_reg_t;

  typedef struct packed {
    struct packed {
      logic [53:0] d;
      logic        de;
    } addr;
  } iommu_hw2reg_msi_addr_0_reg_t;

  typedef struct packed {
    logic [31:0] d;
    logic        de;
  } iommu_hw2reg_msi_data_0_reg_t;

  typedef struct packed {
    logic        d;
    logic        de;
  } iommu_hw2reg_msi_vec_ctl_0_reg_t;

  typedef struct packed {
    struct packed {
      logic [53:0] d;
      logic        de;
    } addr;
  } iommu_hw2reg_msi_addr_1_reg_t;

  typedef struct packed {
    logic [31:0] d;
    logic        de;
  } iommu_hw2reg_msi_data_1_reg_t;

  typedef struct packed {
    logic        d;
    logic        de;
  } iommu_hw2reg_msi_vec_ctl_1_reg_t;

  typedef struct packed {
    struct packed {
      logic [53:0] d;
      logic        de;
    } addr;
  } iommu_hw2reg_msi_addr_2_reg_t;

  typedef struct packed {
    logic [31:0] d;
    logic        de;
  } iommu_hw2reg_msi_data_2_reg_t;

  typedef struct packed {
    logic        d;
    logic        de;
  } iommu_hw2reg_msi_vec_ctl_2_reg_t;

  typedef struct packed {
    struct packed {
      logic [53:0] d;
      logic        de;
    } addr;
  } iommu_hw2reg_msi_addr_3_reg_t;

  typedef struct packed {
    logic [31:0] d;
    logic        de;
  } iommu_hw2reg_msi_data_3_reg_t;

  typedef struct packed {
    logic        d;
    logic        de;
  } iommu_hw2reg_msi_vec_ctl_3_reg_t;

  typedef struct packed {
    struct packed {
      logic [53:0] d;
      logic        de;
    } addr;
  } iommu_hw2reg_msi_addr_4_reg_t;

  typedef struct packed {
    logic [31:0] d;
    logic        de;
  } iommu_hw2reg_msi_data_4_reg_t;

  typedef struct packed {
    logic        d;
    logic        de;
  } iommu_hw2reg_msi_vec_ctl_4_reg_t;

  typedef struct packed {
    struct packed {
      logic [53:0] d;
      logic        de;
    } addr;
  } iommu_hw2reg_msi_addr_5_reg_t;

  typedef struct packed {
    logic [31:0] d;
    logic        de;
  } iommu_hw2reg_msi_data_5_reg_t;

  typedef struct packed {
    logic        d;
    logic        de;
  } iommu_hw2reg_msi_vec_ctl_5_reg_t;

  typedef struct packed {
    struct packed {
      logic [53:0] d;
      logic        de;
    } addr;
  } iommu_hw2reg_msi_addr_6_reg_t;

  typedef struct packed {
    logic [31:0] d;
    logic        de;
  } iommu_hw2reg_msi_data_6_reg_t;

  typedef struct packed {
    logic        d;
    logic        de;
  } iommu_hw2reg_msi_vec_ctl_6_reg_t;

  typedef struct packed {
    struct packed {
      logic [53:0] d;
      logic        de;
    } addr;
  } iommu_hw2reg_msi_addr_7_reg_t;

  typedef struct packed {
    logic [31:0] d;
    logic        de;
  } iommu_hw2reg_msi_data_7_reg_t;

  typedef struct packed {
    logic        d;
    logic        de;
  } iommu_hw2reg_msi_vec_ctl_7_reg_t;

  typedef struct packed {
    struct packed {
      logic [53:0] d;
      logic        de;
    } addr;
  } iommu_hw2reg_msi_addr_8_reg_t;

  typedef struct packed {
    logic [31:0] d;
    logic        de;
  } iommu_hw2reg_msi_data_8_reg_t;

  typedef struct packed {
    logic        d;
    logic        de;
  } iommu_hw2reg_msi_vec_ctl_8_reg_t;

  typedef struct packed {
    struct packed {
      logic [53:0] d;
      logic        de;
    } addr;
  } iommu_hw2reg_msi_addr_9_reg_t;

  typedef struct packed {
    logic [31:0] d;
    logic        de;
  } iommu_hw2reg_msi_data_9_reg_t;

  typedef struct packed {
    logic        d;
    logic        de;
  } iommu_hw2reg_msi_vec_ctl_9_reg_t;

  typedef struct packed {
    struct packed {
      logic [53:0] d;
      logic        de;
    } addr;
  } iommu_hw2reg_msi_addr_10_reg_t;

  typedef struct packed {
    logic [31:0] d;
    logic        de;
  } iommu_hw2reg_msi_data_10_reg_t;

  typedef struct packed {
    logic        d;
    logic        de;
  } iommu_hw2reg_msi_vec_ctl_10_reg_t;

  typedef struct packed {
    struct packed {
      logic [53:0] d;
      logic        de;
    } addr;
  } iommu_hw2reg_msi_addr_11_reg_t;

  typedef struct packed {
    logic [31:0] d;
    logic        de;
  } iommu_hw2reg_msi_data_11_reg_t;

  typedef struct packed {
    logic        d;
    logic        de;
  } iommu_hw2reg_msi_vec_ctl_11_reg_t;

  typedef struct packed {
    struct packed {
      logic [53:0] d;
      logic        de;
    } addr;
  } iommu_hw2reg_msi_addr_12_reg_t;

  typedef struct packed {
    logic [31:0] d;
    logic        de;
  } iommu_hw2reg_msi_data_12_reg_t;

  typedef struct packed {
    logic        d;
    logic        de;
  } iommu_hw2reg_msi_vec_ctl_12_reg_t;

  typedef struct packed {
    struct packed {
      logic [53:0] d;
      logic        de;
    } addr;
  } iommu_hw2reg_msi_addr_13_reg_t;

  typedef struct packed {
    logic [31:0] d;
    logic        de;
  } iommu_hw2reg_msi_data_13_reg_t;

  typedef struct packed {
    logic        d;
    logic        de;
  } iommu_hw2reg_msi_vec_ctl_13_reg_t;

  typedef struct packed {
    struct packed {
      logic [53:0] d;
      logic        de;
    } addr;
  } iommu_hw2reg_msi_addr_14_reg_t;

  typedef struct packed {
    logic [31:0] d;
    logic        de;
  } iommu_hw2reg_msi_data_14_reg_t;

  typedef struct packed {
    logic        d;
    logic        de;
  } iommu_hw2reg_msi_vec_ctl_14_reg_t;

  typedef struct packed {
    struct packed {
      logic [53:0] d;
      logic        de;
    } addr;
  } iommu_hw2reg_msi_addr_15_reg_t;

  typedef struct packed {
    logic [31:0] d;
    logic        de;
  } iommu_hw2reg_msi_data_15_reg_t;

  typedef struct packed {
    logic        d;
    logic        de;
  } iommu_hw2reg_msi_vec_ctl_15_reg_t;

  // Register -> HW type
  typedef struct packed {
    iommu_reg2hw_capabilities_reg_t capabilities; // [1772:1736]
    iommu_reg2hw_fctl_reg_t fctl; // [1735:1733]
    iommu_reg2hw_ddtp_reg_t ddtp; // [1732:1684]
    iommu_reg2hw_cqb_reg_t cqb; // [1683:1635]
    iommu_reg2hw_cqh_reg_t cqh; // [1634:1603]
    iommu_reg2hw_cqt_reg_t cqt; // [1602:1571]
    iommu_reg2hw_fqb_reg_t fqb; // [1570:1522]
    iommu_reg2hw_fqh_reg_t fqh; // [1521:1490]
    iommu_reg2hw_fqt_reg_t fqt; // [1489:1458]
    iommu_reg2hw_cqcsr_reg_t cqcsr; // [1457:1450]
    iommu_reg2hw_fqcsr_reg_t fqcsr; // [1449:1444]
    iommu_reg2hw_ipsr_reg_t ipsr; // [1443:1440]
    iommu_reg2hw_icvec_reg_t icvec; // [1439:1424]
    iommu_reg2hw_msi_addr_0_reg_t msi_addr_0; // [1423:1368]
    iommu_reg2hw_msi_data_0_reg_t msi_data_0; // [1367:1336]
    iommu_reg2hw_msi_vec_ctl_0_reg_t msi_vec_ctl_0; // [1335:1335]
    iommu_reg2hw_msi_addr_1_reg_t msi_addr_1; // [1334:1279]
    iommu_reg2hw_msi_data_1_reg_t msi_data_1; // [1278:1247]
    iommu_reg2hw_msi_vec_ctl_1_reg_t msi_vec_ctl_1; // [1246:1246]
    iommu_reg2hw_msi_addr_2_reg_t msi_addr_2; // [1245:1190]
    iommu_reg2hw_msi_data_2_reg_t msi_data_2; // [1189:1158]
    iommu_reg2hw_msi_vec_ctl_2_reg_t msi_vec_ctl_2; // [1157:1157]
    iommu_reg2hw_msi_addr_3_reg_t msi_addr_3; // [1156:1101]
    iommu_reg2hw_msi_data_3_reg_t msi_data_3; // [1100:1069]
    iommu_reg2hw_msi_vec_ctl_3_reg_t msi_vec_ctl_3; // [1068:1068]
    iommu_reg2hw_msi_addr_4_reg_t msi_addr_4; // [1067:1012]
    iommu_reg2hw_msi_data_4_reg_t msi_data_4; // [1011:980]
    iommu_reg2hw_msi_vec_ctl_4_reg_t msi_vec_ctl_4; // [979:979]
    iommu_reg2hw_msi_addr_5_reg_t msi_addr_5; // [978:923]
    iommu_reg2hw_msi_data_5_reg_t msi_data_5; // [922:891]
    iommu_reg2hw_msi_vec_ctl_5_reg_t msi_vec_ctl_5; // [890:890]
    iommu_reg2hw_msi_addr_6_reg_t msi_addr_6; // [889:834]
    iommu_reg2hw_msi_data_6_reg_t msi_data_6; // [833:802]
    iommu_reg2hw_msi_vec_ctl_6_reg_t msi_vec_ctl_6; // [801:801]
    iommu_reg2hw_msi_addr_7_reg_t msi_addr_7; // [800:745]
    iommu_reg2hw_msi_data_7_reg_t msi_data_7; // [744:713]
    iommu_reg2hw_msi_vec_ctl_7_reg_t msi_vec_ctl_7; // [712:712]
    iommu_reg2hw_msi_addr_8_reg_t msi_addr_8; // [711:656]
    iommu_reg2hw_msi_data_8_reg_t msi_data_8; // [655:624]
    iommu_reg2hw_msi_vec_ctl_8_reg_t msi_vec_ctl_8; // [623:623]
    iommu_reg2hw_msi_addr_9_reg_t msi_addr_9; // [622:567]
    iommu_reg2hw_msi_data_9_reg_t msi_data_9; // [566:535]
    iommu_reg2hw_msi_vec_ctl_9_reg_t msi_vec_ctl_9; // [534:534]
    iommu_reg2hw_msi_addr_10_reg_t msi_addr_10; // [533:478]
    iommu_reg2hw_msi_data_10_reg_t msi_data_10; // [477:446]
    iommu_reg2hw_msi_vec_ctl_10_reg_t msi_vec_ctl_10; // [445:445]
    iommu_reg2hw_msi_addr_11_reg_t msi_addr_11; // [444:389]
    iommu_reg2hw_msi_data_11_reg_t msi_data_11; // [388:357]
    iommu_reg2hw_msi_vec_ctl_11_reg_t msi_vec_ctl_11; // [356:356]
    iommu_reg2hw_msi_addr_12_reg_t msi_addr_12; // [355:300]
    iommu_reg2hw_msi_data_12_reg_t msi_data_12; // [299:268]
    iommu_reg2hw_msi_vec_ctl_12_reg_t msi_vec_ctl_12; // [267:267]
    iommu_reg2hw_msi_addr_13_reg_t msi_addr_13; // [266:211]
    iommu_reg2hw_msi_data_13_reg_t msi_data_13; // [210:179]
    iommu_reg2hw_msi_vec_ctl_13_reg_t msi_vec_ctl_13; // [178:178]
    iommu_reg2hw_msi_addr_14_reg_t msi_addr_14; // [177:122]
    iommu_reg2hw_msi_data_14_reg_t msi_data_14; // [121:90]
    iommu_reg2hw_msi_vec_ctl_14_reg_t msi_vec_ctl_14; // [89:89]
    iommu_reg2hw_msi_addr_15_reg_t msi_addr_15; // [88:33]
    iommu_reg2hw_msi_data_15_reg_t msi_data_15; // [32:1]
    iommu_reg2hw_msi_vec_ctl_15_reg_t msi_vec_ctl_15; // [0:0]
  } iommu_reg2hw_t;

  // HW -> register type
  typedef struct packed {
    iommu_hw2reg_fctl_reg_t fctl; // [1787:1782]
    iommu_hw2reg_ddtp_reg_t ddtp; // [1781:1730]
    iommu_hw2reg_cqb_reg_t cqb; // [1729:1679]
    iommu_hw2reg_cqh_reg_t cqh; // [1678:1646]
    iommu_hw2reg_cqt_reg_t cqt; // [1645:1613]
    iommu_hw2reg_fqb_reg_t fqb; // [1612:1562]
    iommu_hw2reg_fqh_reg_t fqh; // [1561:1529]
    iommu_hw2reg_fqt_reg_t fqt; // [1528:1496]
    iommu_hw2reg_cqcsr_reg_t cqcsr; // [1495:1480]
    iommu_hw2reg_fqcsr_reg_t fqcsr; // [1479:1468]
    iommu_hw2reg_ipsr_reg_t ipsr; // [1467:1460]
    iommu_hw2reg_icvec_reg_t icvec; // [1459:1440]
    iommu_hw2reg_msi_addr_0_reg_t msi_addr_0; // [1439:1385]
    iommu_hw2reg_msi_data_0_reg_t msi_data_0; // [1384:1352]
    iommu_hw2reg_msi_vec_ctl_0_reg_t msi_vec_ctl_0; // [1351:1350]
    iommu_hw2reg_msi_addr_1_reg_t msi_addr_1; // [1349:1295]
    iommu_hw2reg_msi_data_1_reg_t msi_data_1; // [1294:1262]
    iommu_hw2reg_msi_vec_ctl_1_reg_t msi_vec_ctl_1; // [1261:1260]
    iommu_hw2reg_msi_addr_2_reg_t msi_addr_2; // [1259:1205]
    iommu_hw2reg_msi_data_2_reg_t msi_data_2; // [1204:1172]
    iommu_hw2reg_msi_vec_ctl_2_reg_t msi_vec_ctl_2; // [1171:1170]
    iommu_hw2reg_msi_addr_3_reg_t msi_addr_3; // [1169:1115]
    iommu_hw2reg_msi_data_3_reg_t msi_data_3; // [1114:1082]
    iommu_hw2reg_msi_vec_ctl_3_reg_t msi_vec_ctl_3; // [1081:1080]
    iommu_hw2reg_msi_addr_4_reg_t msi_addr_4; // [1079:1025]
    iommu_hw2reg_msi_data_4_reg_t msi_data_4; // [1024:992]
    iommu_hw2reg_msi_vec_ctl_4_reg_t msi_vec_ctl_4; // [991:990]
    iommu_hw2reg_msi_addr_5_reg_t msi_addr_5; // [989:935]
    iommu_hw2reg_msi_data_5_reg_t msi_data_5; // [934:902]
    iommu_hw2reg_msi_vec_ctl_5_reg_t msi_vec_ctl_5; // [901:900]
    iommu_hw2reg_msi_addr_6_reg_t msi_addr_6; // [899:845]
    iommu_hw2reg_msi_data_6_reg_t msi_data_6; // [844:812]
    iommu_hw2reg_msi_vec_ctl_6_reg_t msi_vec_ctl_6; // [811:810]
    iommu_hw2reg_msi_addr_7_reg_t msi_addr_7; // [809:755]
    iommu_hw2reg_msi_data_7_reg_t msi_data_7; // [754:722]
    iommu_hw2reg_msi_vec_ctl_7_reg_t msi_vec_ctl_7; // [721:720]
    iommu_hw2reg_msi_addr_8_reg_t msi_addr_8; // [719:665]
    iommu_hw2reg_msi_data_8_reg_t msi_data_8; // [664:632]
    iommu_hw2reg_msi_vec_ctl_8_reg_t msi_vec_ctl_8; // [631:630]
    iommu_hw2reg_msi_addr_9_reg_t msi_addr_9; // [629:575]
    iommu_hw2reg_msi_data_9_reg_t msi_data_9; // [574:542]
    iommu_hw2reg_msi_vec_ctl_9_reg_t msi_vec_ctl_9; // [541:540]
    iommu_hw2reg_msi_addr_10_reg_t msi_addr_10; // [539:485]
    iommu_hw2reg_msi_data_10_reg_t msi_data_10; // [484:452]
    iommu_hw2reg_msi_vec_ctl_10_reg_t msi_vec_ctl_10; // [451:450]
    iommu_hw2reg_msi_addr_11_reg_t msi_addr_11; // [449:395]
    iommu_hw2reg_msi_data_11_reg_t msi_data_11; // [394:362]
    iommu_hw2reg_msi_vec_ctl_11_reg_t msi_vec_ctl_11; // [361:360]
    iommu_hw2reg_msi_addr_12_reg_t msi_addr_12; // [359:305]
    iommu_hw2reg_msi_data_12_reg_t msi_data_12; // [304:272]
    iommu_hw2reg_msi_vec_ctl_12_reg_t msi_vec_ctl_12; // [271:270]
    iommu_hw2reg_msi_addr_13_reg_t msi_addr_13; // [269:215]
    iommu_hw2reg_msi_data_13_reg_t msi_data_13; // [214:182]
    iommu_hw2reg_msi_vec_ctl_13_reg_t msi_vec_ctl_13; // [181:180]
    iommu_hw2reg_msi_addr_14_reg_t msi_addr_14; // [179:125]
    iommu_hw2reg_msi_data_14_reg_t msi_data_14; // [124:92]
    iommu_hw2reg_msi_vec_ctl_14_reg_t msi_vec_ctl_14; // [91:90]
    iommu_hw2reg_msi_addr_15_reg_t msi_addr_15; // [89:35]
    iommu_hw2reg_msi_data_15_reg_t msi_data_15; // [34:2]
    iommu_hw2reg_msi_vec_ctl_15_reg_t msi_vec_ctl_15; // [1:0]
  } iommu_hw2reg_t;

  // Register offsets
  parameter logic [BlockAw-1:0] IOMMU_CAPABILITIES_OFFSET = 12'h 0;
  parameter logic [BlockAw-1:0] IOMMU_FCTL_OFFSET = 12'h 8;
  parameter logic [BlockAw-1:0] IOMMU_DDTP_OFFSET = 12'h 10;
  parameter logic [BlockAw-1:0] IOMMU_CQB_OFFSET = 12'h 18;
  parameter logic [BlockAw-1:0] IOMMU_CQH_OFFSET = 12'h 20;
  parameter logic [BlockAw-1:0] IOMMU_CQT_OFFSET = 12'h 24;
  parameter logic [BlockAw-1:0] IOMMU_FQB_OFFSET = 12'h 28;
  parameter logic [BlockAw-1:0] IOMMU_FQH_OFFSET = 12'h 30;
  parameter logic [BlockAw-1:0] IOMMU_FQT_OFFSET = 12'h 34;
  parameter logic [BlockAw-1:0] IOMMU_CQCSR_OFFSET = 12'h 48;
  parameter logic [BlockAw-1:0] IOMMU_FQCSR_OFFSET = 12'h 4c;
  parameter logic [BlockAw-1:0] IOMMU_IPSR_OFFSET = 12'h 54;
  parameter logic [BlockAw-1:0] IOMMU_ICVEC_OFFSET = 12'h 2f8;
  parameter logic [BlockAw-1:0] IOMMU_MSI_ADDR_0_OFFSET = 12'h 300;
  parameter logic [BlockAw-1:0] IOMMU_MSI_DATA_0_OFFSET = 12'h 308;
  parameter logic [BlockAw-1:0] IOMMU_MSI_VEC_CTL_0_OFFSET = 12'h 30c;
  parameter logic [BlockAw-1:0] IOMMU_MSI_ADDR_1_OFFSET = 12'h 310;
  parameter logic [BlockAw-1:0] IOMMU_MSI_DATA_1_OFFSET = 12'h 318;
  parameter logic [BlockAw-1:0] IOMMU_MSI_VEC_CTL_1_OFFSET = 12'h 31c;
  parameter logic [BlockAw-1:0] IOMMU_MSI_ADDR_2_OFFSET = 12'h 320;
  parameter logic [BlockAw-1:0] IOMMU_MSI_DATA_2_OFFSET = 12'h 328;
  parameter logic [BlockAw-1:0] IOMMU_MSI_VEC_CTL_2_OFFSET = 12'h 32c;
  parameter logic [BlockAw-1:0] IOMMU_MSI_ADDR_3_OFFSET = 12'h 330;
  parameter logic [BlockAw-1:0] IOMMU_MSI_DATA_3_OFFSET = 12'h 338;
  parameter logic [BlockAw-1:0] IOMMU_MSI_VEC_CTL_3_OFFSET = 12'h 33c;
  parameter logic [BlockAw-1:0] IOMMU_MSI_ADDR_4_OFFSET = 12'h 340;
  parameter logic [BlockAw-1:0] IOMMU_MSI_DATA_4_OFFSET = 12'h 348;
  parameter logic [BlockAw-1:0] IOMMU_MSI_VEC_CTL_4_OFFSET = 12'h 34c;
  parameter logic [BlockAw-1:0] IOMMU_MSI_ADDR_5_OFFSET = 12'h 350;
  parameter logic [BlockAw-1:0] IOMMU_MSI_DATA_5_OFFSET = 12'h 358;
  parameter logic [BlockAw-1:0] IOMMU_MSI_VEC_CTL_5_OFFSET = 12'h 35c;
  parameter logic [BlockAw-1:0] IOMMU_MSI_ADDR_6_OFFSET = 12'h 360;
  parameter logic [BlockAw-1:0] IOMMU_MSI_DATA_6_OFFSET = 12'h 368;
  parameter logic [BlockAw-1:0] IOMMU_MSI_VEC_CTL_6_OFFSET = 12'h 36c;
  parameter logic [BlockAw-1:0] IOMMU_MSI_ADDR_7_OFFSET = 12'h 370;
  parameter logic [BlockAw-1:0] IOMMU_MSI_DATA_7_OFFSET = 12'h 378;
  parameter logic [BlockAw-1:0] IOMMU_MSI_VEC_CTL_7_OFFSET = 12'h 37c;
  parameter logic [BlockAw-1:0] IOMMU_MSI_ADDR_8_OFFSET = 12'h 380;
  parameter logic [BlockAw-1:0] IOMMU_MSI_DATA_8_OFFSET = 12'h 388;
  parameter logic [BlockAw-1:0] IOMMU_MSI_VEC_CTL_8_OFFSET = 12'h 38c;
  parameter logic [BlockAw-1:0] IOMMU_MSI_ADDR_9_OFFSET = 12'h 390;
  parameter logic [BlockAw-1:0] IOMMU_MSI_DATA_9_OFFSET = 12'h 398;
  parameter logic [BlockAw-1:0] IOMMU_MSI_VEC_CTL_9_OFFSET = 12'h 39c;
  parameter logic [BlockAw-1:0] IOMMU_MSI_ADDR_10_OFFSET = 12'h 3a0;
  parameter logic [BlockAw-1:0] IOMMU_MSI_DATA_10_OFFSET = 12'h 3a8;
  parameter logic [BlockAw-1:0] IOMMU_MSI_VEC_CTL_10_OFFSET = 12'h 3ac;
  parameter logic [BlockAw-1:0] IOMMU_MSI_ADDR_11_OFFSET = 12'h 3b0;
  parameter logic [BlockAw-1:0] IOMMU_MSI_DATA_11_OFFSET = 12'h 3b8;
  parameter logic [BlockAw-1:0] IOMMU_MSI_VEC_CTL_11_OFFSET = 12'h 3bc;
  parameter logic [BlockAw-1:0] IOMMU_MSI_ADDR_12_OFFSET = 12'h 3c0;
  parameter logic [BlockAw-1:0] IOMMU_MSI_DATA_12_OFFSET = 12'h 3c8;
  parameter logic [BlockAw-1:0] IOMMU_MSI_VEC_CTL_12_OFFSET = 12'h 3cc;
  parameter logic [BlockAw-1:0] IOMMU_MSI_ADDR_13_OFFSET = 12'h 3d0;
  parameter logic [BlockAw-1:0] IOMMU_MSI_DATA_13_OFFSET = 12'h 3d8;
  parameter logic [BlockAw-1:0] IOMMU_MSI_VEC_CTL_13_OFFSET = 12'h 3dc;
  parameter logic [BlockAw-1:0] IOMMU_MSI_ADDR_14_OFFSET = 12'h 3e0;
  parameter logic [BlockAw-1:0] IOMMU_MSI_DATA_14_OFFSET = 12'h 3e8;
  parameter logic [BlockAw-1:0] IOMMU_MSI_VEC_CTL_14_OFFSET = 12'h 3ec;
  parameter logic [BlockAw-1:0] IOMMU_MSI_ADDR_15_OFFSET = 12'h 3f0;
  parameter logic [BlockAw-1:0] IOMMU_MSI_DATA_15_OFFSET = 12'h 3f8;
  parameter logic [BlockAw-1:0] IOMMU_MSI_VEC_CTL_15_OFFSET = 12'h 3fc;

  // Register width information to check illegal writes
  parameter logic [7:0] IOMMU_PERMIT [61] = '{
    8'b 00111111, // index[ 0] IOMMU_CAPABILITIES
    8'b 00000001, // index[ 1] IOMMU_FCTL
    8'b 01111111, // index[ 2] IOMMU_DDTP
    8'b 01111111, // index[ 3] IOMMU_CQB
    8'b 00001111, // index[ 4] IOMMU_CQH
    8'b 00001111, // index[ 5] IOMMU_CQT
    8'b 01111111, // index[ 6] IOMMU_FQB
    8'b 00001111, // index[ 7] IOMMU_FQH
    8'b 00001111, // index[ 8] IOMMU_FQT
    8'b 00000111, // index[ 9] IOMMU_CQCSR
    8'b 00000111, // index[10] IOMMU_FQCSR
    8'b 00000001, // index[11] IOMMU_IPSR
    8'b 00000011, // index[12] IOMMU_ICVEC
    8'b 01111111, // index[13] IOMMU_MSI_ADDR_0
    8'b 00001111, // index[14] IOMMU_MSI_DATA_0
    8'b 00000001, // index[15] IOMMU_MSI_VEC_CTL_0
    8'b 01111111, // index[13] IOMMU_MSI_ADDR_0
    8'b 00001111, // index[14] IOMMU_MSI_DATA_0
    8'b 00000001, // index[15] IOMMU_MSI_VEC_CTL_0
    8'b 01111111, // index[13] IOMMU_MSI_ADDR_0
    8'b 00001111, // index[14] IOMMU_MSI_DATA_0
    8'b 00000001, // index[15] IOMMU_MSI_VEC_CTL_0
    8'b 01111111, // index[13] IOMMU_MSI_ADDR_0
    8'b 00001111, // index[14] IOMMU_MSI_DATA_0
    8'b 00000001, // index[15] IOMMU_MSI_VEC_CTL_0
    8'b 01111111, // index[13] IOMMU_MSI_ADDR_0
    8'b 00001111, // index[14] IOMMU_MSI_DATA_0
    8'b 00000001, // index[15] IOMMU_MSI_VEC_CTL_0
    8'b 01111111, // index[13] IOMMU_MSI_ADDR_0
    8'b 00001111, // index[14] IOMMU_MSI_DATA_0
    8'b 00000001, // index[15] IOMMU_MSI_VEC_CTL_0
    8'b 01111111, // index[13] IOMMU_MSI_ADDR_0
    8'b 00001111, // index[14] IOMMU_MSI_DATA_0
    8'b 00000001, // index[15] IOMMU_MSI_VEC_CTL_0
    8'b 01111111, // index[13] IOMMU_MSI_ADDR_0
    8'b 00001111, // index[14] IOMMU_MSI_DATA_0
    8'b 00000001, // index[15] IOMMU_MSI_VEC_CTL_0
    8'b 01111111, // index[13] IOMMU_MSI_ADDR_0
    8'b 00001111, // index[14] IOMMU_MSI_DATA_0
    8'b 00000001, // index[15] IOMMU_MSI_VEC_CTL_0
    8'b 01111111, // index[13] IOMMU_MSI_ADDR_0
    8'b 00001111, // index[14] IOMMU_MSI_DATA_0
    8'b 00000001, // index[15] IOMMU_MSI_VEC_CTL_0
    8'b 01111111, // index[13] IOMMU_MSI_ADDR_0
    8'b 00001111, // index[14] IOMMU_MSI_DATA_0
    8'b 00000001, // index[15] IOMMU_MSI_VEC_CTL_0
    8'b 01111111, // index[13] IOMMU_MSI_ADDR_0
    8'b 00001111, // index[14] IOMMU_MSI_DATA_0
    8'b 00000001, // index[15] IOMMU_MSI_VEC_CTL_0
    8'b 01111111, // index[13] IOMMU_MSI_ADDR_0
    8'b 00001111, // index[14] IOMMU_MSI_DATA_0
    8'b 00000001, // index[15] IOMMU_MSI_VEC_CTL_0
    8'b 01111111, // index[13] IOMMU_MSI_ADDR_0
    8'b 00001111, // index[14] IOMMU_MSI_DATA_0
    8'b 00000001, // index[15] IOMMU_MSI_VEC_CTL_0
    8'b 01111111, // index[13] IOMMU_MSI_ADDR_0
    8'b 00001111, // index[14] IOMMU_MSI_DATA_0
    8'b 00000001, // index[15] IOMMU_MSI_VEC_CTL_0
    8'b 01111111, // index[13] IOMMU_MSI_ADDR_0
    8'b 00001111, // index[14] IOMMU_MSI_DATA_0
    8'b 00000001 // index[15] IOMMU_MSI_VEC_CTL_0
  };

endpackage

`endif