// Copyright 2024 Politecnico di Torino.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 2.0 (the "License"); you may not use this file except in
// compliance with the License. You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-2.0. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//
// File: cnt_control_reg.sv
// Author(s):
//   Michele Caon
// Date: 07/11/2024
// Description: Counter control register wrapper

module cnt_control_reg (
  input logic clk_i,
  input logic rst_ni,

  // Register interface
  input  cnt_reg_pkg::reg_req_t  req_i,  // from host system
  output cnt_reg_pkg::reg_resp_t rsp_o,  // to host system

  // Counter control signals
  input  logic        cnt_tc_i,   // counter terminal count
  output logic        cnt_en_o,   // counter enable
  output logic        cnt_clr_o,  // counter clear
  output logic [31:0] cnt_thr_o   // counter threshold
);
  // INTERNAL SIGNALS
  // ----------------
  // Registers <--> Hanrdware counter
  cnt_control_reg_pkg::cnt_control_reg2hw_t reg2hw;
  cnt_control_reg_pkg::cnt_control_hw2reg_t hw2reg;
  cnt_reg_pkg::reg_req_t                    ctl_reg_req;
  cnt_reg_pkg::reg_resp_t                   ctl_reg_rsp;

  // -----------------
  // CONTROL REGISTERS
  // -----------------
  // Counter terminal count
  // NOTE: The threshold is set when the counter crosses the threshold, and
  // cleared when the counter is cleared.
  assign hw2reg.status.d         = cnt_tc_i & ~reg2hw.control.clear.q;
  assign hw2reg.status.de        = cnt_tc_i || reg2hw.control.clear.q;

  // Always auto-reset the clear bit
  assign hw2reg.control.clear.d  = 1'b0;
  assign hw2reg.control.clear.de = 1'b1;

  // OBI bridge
  cnt_obi_to_reg #(
    .DW       (32),
    .obi_req_t(cnt_obi_pkg::obi_req_t),
    .obi_rsp_t(cnt_obi_pkg::obi_resp_t),
    .reg_req_t(cnt_reg_pkg::reg_req_t),
    .reg_rsp_t(cnt_reg_pkg::reg_resp_t)
  ) u_cnt_obi_to_reg (
    .clk_i    (clk_i),
    .rst_ni   (rst_ni),
    .obi_req_i(req_i),
    .obi_rsp_o(rsp_o),
    .reg_req_o(ctl_reg_req),
    .reg_rsp_i(ctl_reg_rsp)
  );

  // Registers top module
  cnt_control_reg_top #(
    .reg_req_t(cnt_reg_pkg::reg_req_t),
    .reg_rsp_t(cnt_reg_pkg::reg_resp_t)
  ) u_cnt_control_reg_top (
    .clk_i    (clk_i),
    .rst_ni   (rst_ni),
    .reg_req_i(ctl_reg_req),
    .reg_rsp_o(ctl_reg_rsp),
    .reg2hw   (reg2hw),
    .hw2reg   (hw2reg),
    .devmode_i(1'b0)
  );

  // --------------
  // OUTPUT CONTROL
  // --------------
  // To the hardware counter
  assign cnt_en_o  = reg2hw.control.enable.q;
  assign cnt_clr_o = reg2hw.control.clear.q;
  assign cnt_thr_o = reg2hw.threshold.q;
endmodule
