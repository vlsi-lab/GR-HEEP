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
// File: cnt_obi_to_reg.sv
// Author(s):
//   Michele Caon
// Date: 07/11/2024
// Description: OBI to register interface bridge

module cnt_obi_to_reg #(
  parameter int unsigned DW = 32,  // data width
  // OBI request type, expected to contain:
  //    logic           req     > request
  //    logic           we      > write enable
  //    logic [BEW-1:0] be      > byte enable
  //    logic  [AW-1:0] addr    > target address
  //    logic  [DW-1:0] wdata   > data to write
  parameter type obi_req_t = cnt_obi_pkg::obi_req_t,
  // OBI response type, expected to contain:
  //    logic           gnt     > request accepted
  //    logic           rvalid  > read data is valid
  //    logic  [DW-1:0] rdata   > read data
  parameter type obi_rsp_t = cnt_obi_pkg::obi_resp_t,
  // Register request type, expected to contain:
  //    logic           valid   > request
  //    logic           write   > write enable
  //    logic [BEW-1:0] wstrb   > write strobe (byte enable)
  //    logic  [AW-1:0] addr    > target address
  //    logic  [DW-1:0] wdata   > data to write
  parameter type reg_req_t = cnt_reg_pkg::reg_req_t,
  // Register response type, expected to contain:
  //    logic           error   > an error occured (discarded for OBI)
  //    logic           ready   > request accepted
  //    logic  [DW-1:0] rdata   > read data
  parameter type reg_rsp_t = cnt_reg_pkg::reg_resp_t
) (
  input logic clk_i,
  input logic rst_ni,

  // OBI interface
  input  obi_req_t obi_req_i,  // OBI bus request
  output obi_rsp_t obi_rsp_o,  // OBI bus response

  // Register interface
  output reg_req_t reg_req_o,  // register interface request
  input  reg_rsp_t reg_rsp_i   // register interface response
);
  // INTERNAL SIGNALS
  // ----------------
  logic rvalid_d, rvalid_q;
  logic [DW-1:0] rdata_d, rdata_q;

  // OBI response register
  // ---------------------
  assign rvalid_d = obi_rsp_o.gnt;
  assign rdata_d  = reg_rsp_i.rdata;
  always_ff @(posedge clk_i or negedge rst_ni) begin : rvalid_ff
    if (!rst_ni) begin
      rvalid_q <= 1'b0;
      rdata_q  <= '0;
    end else begin
      rvalid_q <= rvalid_d;
      rdata_q  <= rdata_d;
    end
  end

  // OUTPUT EVALUTATION
  // ------------------
  // OBI request to register request
  assign reg_req_o.valid  = obi_req_i.req;
  assign reg_req_o.write  = obi_req_i.we;
  assign reg_req_o.wstrb  = obi_req_i.be;
  assign reg_req_o.addr   = obi_req_i.addr;
  assign reg_req_o.wdata  = obi_req_i.wdata;

  // Register response to OBI response
  assign obi_rsp_o.gnt    = obi_req_i.req & reg_rsp_i.ready;
  assign obi_rsp_o.rvalid = rvalid_q;
  assign obi_rsp_o.rdata  = rdata_q;
endmodule
