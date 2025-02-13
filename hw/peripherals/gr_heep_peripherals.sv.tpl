// Copyright 2024 Politecnico di Torino and EPFL
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 2.0 (the "License"); you may not use this file except in
// compliance with the License. You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-2.0. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//
// File: gr_heep_peripherals.sv
// Author(s):
//   Luigi Giuffrida
//   David Mallasén
// Date: 08/11/2024
// Description: Template for the GR-heep peripherals module

module gr_heep_peripherals (
    input logic clk_i,
    input logic rst_ni,

    /* verilator lint_off UNUSED */

    // External peripherals master ports
    output obi_pkg::obi_req_t  [gr_heep_pkg::ExtXbarNMasterRnd-1:0] gr_heep_master_req_o,
    input obi_pkg::obi_resp_t [gr_heep_pkg::ExtXbarNMasterRnd-1:0] gr_heep_master_resp_i,

    // External peripherals slave ports
    input obi_pkg::obi_req_t  [gr_heep_pkg::ExtXbarNSlaveRnd-1:0] gr_heep_slave_req_i,
    output obi_pkg::obi_resp_t [gr_heep_pkg::ExtXbarNSlaveRnd-1:0] gr_heep_slave_resp_o,

    // External peripherals configuration ports
    input reg_pkg::reg_req_t [gr_heep_pkg::ExtPeriphNSlaveRnd-1:0] gr_heep_peripheral_req_i,
    output reg_pkg::reg_rsp_t [gr_heep_pkg::ExtPeriphNSlaveRnd-1:0] gr_heep_peripheral_rsp_o,

    /* verilator lint_on UNUSED */

    // External peripherals interrupt ports
    output logic [gr_heep_pkg::ExtInterrupts-1:0] gr_heep_peripheral_int_o
);

  // Assign default values to the output signals. To be modified if the
  // peripherals are instantiated.
  assign gr_heep_master_req_o = '0;
  assign gr_heep_slave_resp_o = '0;
  assign gr_heep_peripheral_rsp_o = '0;
  assign gr_heep_peripheral_int_o = '0;

  // Instantiate here the external peripherals

endmodule
