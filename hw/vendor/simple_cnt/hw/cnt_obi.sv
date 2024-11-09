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
// File: cnt_obi.sv
// Author(s):
//   Michele Caon
// Date: 07/11/2024
// Description: OBI bus wrapper for the simple counter

module cnt_obi #(
  parameter int unsigned W = 32  // counter bitwidth (max: 32)
) (
  input logic clk_i,
  input logic rst_ni,

  // OBI interface (counter value)
  input  logic        obi_req_i,
  input  logic        obi_we_i,
  input  logic [ 3:0] obi_be_i,
  input  logic [31:0] obi_addr_i,
  input  logic [31:0] obi_wdata_i,
  output logic        obi_gnt_o,
  output logic        obi_rvalid_o,
  output logic [31:0] obi_rdata_o,

  // Register Interface (configuration registers)
  input  logic        reg_valid_i,
  input  logic        reg_write_i,
  input  logic [ 3:0] reg_wstrb_i,
  input  logic [31:0] reg_addr_i,
  input  logic [31:0] reg_wdata_i,
  output logic        reg_error_o,
  output logic        reg_ready_o,
  output logic [31:0] reg_rdata_o,

  // Terminal count interrupt
  output logic tc_int_o  // interrupt to host system
);
  // INTERNAL SIGNALS
  // ----------------
  // Bus request and response
  logic                           obi_gnt;
  logic                           obi_rvalid_q;
  logic                   [W-1:0] obi_rdata_q;
  cnt_reg_pkg::reg_req_t          reg_req;  // from host system
  cnt_reg_pkg::reg_resp_t         reg_rsp;  // to host system

  // Registers <--> Hanrdware counter
  logic                           cnt_en;
  logic                           cnt_clr;
  logic                           cnt_ld;
  logic                   [W-1:0] cnt_ld_val;
  logic                   [W-1:0] cnt_val;
  logic                   [ 31:0] cnt_thr;
  logic                           cnt_tc;

  // --------------
  // COUNTER MODULE
  // --------------
  // Counter instance
  cnt #(
    .W(W)
  ) u_cnt (
    .clk_i   (clk_i),
    .rst_ni  (rst_ni),
    .en_i    (cnt_en),
    .clr_i   (cnt_clr),
    .ld_i    (cnt_ld),
    .ld_val_i(cnt_ld_val),
    .thr_i   (cnt_thr[W-1:0]),
    .cnt_o   (cnt_val),
    .tc_o    (cnt_tc)
  );

  // Interrupt to host system
  assign tc_int_o   = cnt_tc;

  // OBI bridge to counter value
  // ---------------------------
  // Bus write request logic
  assign cnt_ld     = obi_req_i & obi_we_i & (&obi_be_i) & ~(|obi_addr_i);
  assign cnt_ld_val = obi_wdata_i[W-1:0];

  // Bus response logic
  assign obi_gnt    = obi_req_i & ~cnt_clr;  // accept a load request if not being cleared
  always_ff @(posedge clk_i or negedge rst_ni) begin : rvalid_ff
    if (!rst_ni) begin
      obi_rvalid_q <= 1'b0;
      obi_rdata_q  <= '0;
    end else begin
      obi_rvalid_q <= obi_gnt;  // always one cycle after the request transaction
      obi_rdata_q  <= cnt_val;  // always one cycle after the request transaction
    end
  end

  // Bus signals
  assign obi_gnt_o = obi_gnt;
  assign obi_rvalid_o = obi_rvalid_q;
  assign obi_rdata_o = {{32 - W{1'b0}}, obi_rdata_q};

  // -----------------
  // CONTROL REGISTERS
  // -----------------
  // Bus request
  assign reg_req = '{
          valid: reg_valid_i,
          write: reg_write_i,
          wstrb: reg_wstrb_i,
          addr: reg_addr_i,
          wdata: reg_wdata_i
      };

  // Control registers
  cnt_control_reg u_cnt_control_reg (
    .clk_i    (clk_i),
    .rst_ni   (rst_ni),
    .req_i    (reg_req),
    .rsp_o    (reg_rsp),
    .cnt_tc_i (cnt_tc),
    .cnt_en_o (cnt_en),
    .cnt_clr_o(cnt_clr),
    .cnt_thr_o(cnt_thr)
  );

  // Bus response
  assign reg_error_o = reg_rsp.error;
  assign reg_ready_o = reg_rsp.ready;
  assign reg_rdata_o = reg_rsp.rdata;

  // ----------
  // ASSERTIONS
  // ----------
`ifndef SYNTHESIS
  initial begin
    assert (W > 0 && W <= 32)
    else $error("Counter width must be in [1,32]");
  end
`endif  /* SYNTHESIS */
endmodule
