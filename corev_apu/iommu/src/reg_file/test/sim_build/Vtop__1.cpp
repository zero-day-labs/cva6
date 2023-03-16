// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design implementation internals
// See Vtop.h for the primary calling header

#include "Vtop.h"
#include "Vtop__Syms.h"

#include "verilated_dpi.h"

void Vtop::_eval(Vtop__Syms* __restrict vlSymsp) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtop::_eval\n"); );
    Vtop* const __restrict vlTOPp VL_ATTR_UNUSED = vlSymsp->TOPp;
    // Body
    vlTOPp->_combo__TOP__3(vlSymsp);
    if ((((IData)(vlTOPp->clk_i) & (~ (IData)(vlTOPp->__Vclklast__TOP__clk_i))) 
         | ((~ (IData)(vlTOPp->rst_ni)) & (IData)(vlTOPp->__Vclklast__TOP__rst_ni)))) {
        vlTOPp->_sequent__TOP__4(vlSymsp);
    }
    vlTOPp->_combo__TOP__5(vlSymsp);
    // Final
    vlTOPp->__Vclklast__TOP__clk_i = vlTOPp->clk_i;
    vlTOPp->__Vclklast__TOP__rst_ni = vlTOPp->rst_ni;
}

VL_INLINE_OPT QData Vtop::_change_request(Vtop__Syms* __restrict vlSymsp) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtop::_change_request\n"); );
    Vtop* const __restrict vlTOPp VL_ATTR_UNUSED = vlSymsp->TOPp;
    // Body
    return (vlTOPp->_change_request_1(vlSymsp));
}

VL_INLINE_OPT QData Vtop::_change_request_1(Vtop__Syms* __restrict vlSymsp) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtop::_change_request_1\n"); );
    Vtop* const __restrict vlTOPp VL_ATTR_UNUSED = vlSymsp->TOPp;
    // Body
    // Change detection
    QData __req = false;  // Logically a bool
    return __req;
}

#ifdef VL_DEBUG
void Vtop::_eval_debug_assertions() {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtop::_eval_debug_assertions\n"); );
    // Body
    if (VL_UNLIKELY((clk_i & 0xfeU))) {
        Verilated::overWidthError("clk_i");}
    if (VL_UNLIKELY((rst_ni & 0xfeU))) {
        Verilated::overWidthError("rst_ni");}
    if (VL_UNLIKELY((s_axil_awaddr & 0xe000U))) {
        Verilated::overWidthError("s_axil_awaddr");}
    if (VL_UNLIKELY((s_axil_awprot & 0xf8U))) {
        Verilated::overWidthError("s_axil_awprot");}
    if (VL_UNLIKELY((s_axil_awvalid & 0xfeU))) {
        Verilated::overWidthError("s_axil_awvalid");}
    if (VL_UNLIKELY((s_axil_wvalid & 0xfeU))) {
        Verilated::overWidthError("s_axil_wvalid");}
    if (VL_UNLIKELY((s_axil_bready & 0xfeU))) {
        Verilated::overWidthError("s_axil_bready");}
    if (VL_UNLIKELY((s_axil_araddr & 0xe000U))) {
        Verilated::overWidthError("s_axil_araddr");}
    if (VL_UNLIKELY((s_axil_arprot & 0xf8U))) {
        Verilated::overWidthError("s_axil_arprot");}
    if (VL_UNLIKELY((s_axil_arvalid & 0xfeU))) {
        Verilated::overWidthError("s_axil_arvalid");}
    if (VL_UNLIKELY((s_axil_rready & 0xfeU))) {
        Verilated::overWidthError("s_axil_rready");}
}
#endif  // VL_DEBUG
