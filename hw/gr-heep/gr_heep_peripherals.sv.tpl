// Copyright 2024 Politecnico di Torino and Universidad Politecnica de Madrid.
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
//   Luigi Giuffrida, Iñigo Díez de Ulzurrun
// Date: 08/11/2024
// Description: Template for the GR-heep peripherals module

<%
    gr_heep = xheep.get_extension("gr-heep")
    xif = xheep.xif()
    cpu = xheep.cpu()
%>

module gr_heep_peripherals (
    input logic clk_i,
    input logic rst_ni${'' if ((gr_heep["xbar_nmasters"] + gr_heep["xbar_nslaves"] + gr_heep["periph_nslaves"] + gr_heep["ext_interrupts"] == 0) and (xif is None)) else ','}
    
    % if (gr_heep["xbar_nmasters"] > 0):
        // External peripherals master ports
        output xheep_obi_pkg::xheep_obi_req_t  [gr_heep_pkg::ExtXbarNMasterRnd-1:0] gr_heep_master_req_o,
        input xheep_obi_pkg::xheep_obi_rsp_t [gr_heep_pkg::ExtXbarNMasterRnd-1:0] gr_heep_master_resp_i${'' if ((gr_heep["xbar_nslaves"] + gr_heep["periph_nslaves"] + gr_heep["ext_interrupts"] == 0) and (xif is None)) else ','}
    % endif
    % if (gr_heep["xbar_nslaves"] > 0):
        // External peripherals slave ports
        input xheep_obi_pkg::xheep_obi_req_t  [gr_heep_pkg::ExtXbarNSlaveRnd-1:0] gr_heep_slave_req_i,
        output xheep_obi_pkg::xheep_obi_rsp_t [gr_heep_pkg::ExtXbarNSlaveRnd-1:0] gr_heep_slave_resp_o${'' if ((gr_heep["periph_nslaves"] + gr_heep["ext_interrupts"] == 0) and (xif is None)) else ','}
    % endif
    % if (gr_heep["periph_nslaves"] > 0):
        // External peripherals configuration ports
        input xheep_reg_pkg::xheep_reg_req_t gr_heep_peripheral_req_i,
        output xheep_reg_pkg::xheep_reg_rsp_t gr_heep_peripheral_rsp_o${'' if ((gr_heep["ext_interrupts"] == 0) and (xif is None)) else ','}
    % endif
    % if (gr_heep["ext_interrupts"] > 0):
        // External peripherals interrupt ports
        output logic [gr_heep_pkg::ExtInterrupts-1:0] gr_heep_peripheral_vec_int_o,
        output logic     gr_heep_peripheral_int_o${'' if (xif is None) else ','}
    % endif
    % if (xif):
        if_xif.coproc_compressed        xif_compressed_if,
        if_xif.coproc_issue             xif_issue_if,
        if_xif.coproc_commit            xif_commit_if,
        if_xif.coproc_mem               xif_mem_if,
        if_xif.coproc_mem_result        xif_mem_result_if,
        if_xif.coproc_result            xif_result_if
    % endif
);

  % if (xif and cpu.name == "cv32e20" ):

    // CVE2 X-IF signals
    logic                    cve2_x_issue_valid;
    logic                    cve2_x_issue_ready;
    cve2_pkg::x_issue_req_t  cve2_x_issue_req;
    cve2_pkg::x_issue_resp_t cve2_x_issue_resp;
    cve2_pkg::x_register_t   cve2_x_register;
    logic                    cve2_x_register_valid;

    logic                    cve2_x_commit_valid;
    cve2_pkg::x_commit_t     cve2_x_commit;

    logic                    cve2_x_result_valid;
    logic                    cve2_x_result_ready;
    cve2_pkg::x_result_t     cve2_x_result;
    
    // Issue/Register Interface <--> Issue Interface
    assign cve2_x_issue_valid = xif_issue_if.issue_valid;
    assign xif_issue_if.issue_ready = cve2_x_issue_ready;
    assign cve2_x_issue_req.instr = xif_issue_if.issue_req.instr;
    assign cve2_x_issue_req.id = xif_issue_if.issue_req.id;
    assign cve2_x_issue_req.hartid = '0;
    assign xif_issue_if.issue_resp.accept = cve2_x_issue_resp.accept;
    assign xif_issue_if.issue_resp.writeback = cve2_x_issue_resp.writeback;
    assign xif_issue_if.issue_resp.dualwrite = '0;
    assign xif_issue_if.issue_resp.dualread = '0;
    assign xif_issue_if.issue_resp.loadstore = '0;
    assign xif_issue_if.issue_resp.ecswrite = '0;
    assign xif_issue_if.issue_resp.exc = '0;
    % if (xif.x_num_rs == 3):
        assign cve2_x_register.rs = xif_issue_if.issue_req.rs;
        assign cve2_x_register.rs_valid = xif_issue_if.issue_req.rs_valid;
    % else:
        assign cve2_x_register.rs[0] = xif_issue_if.issue_req.rs[0];
        assign cve2_x_register.rs[1] = xif_issue_if.issue_req.rs[1];
        assign cve2_x_register.rs_valid[1:0] = xif_issue_if.issue_req.rs_valid[1:0];
    % endif
    assign cve2_x_register.hartid = '0;
    assign cve2_x_register.id = '0;
    assign cve2_x_register_valid = xif_issue_if.issue_valid;
    
    // Commit Interface
    assign cve2_x_commit_valid = xif_commit_if.commit_valid;
    assign cve2_x_commit.hartid = '0;
    assign cve2_x_commit.id = xif_commit_if.commit.id;
    assign cve2_x_commit.commit_kill = xif_commit_if.commit.commit_kill;

    // Result Interface
    assign cve2_x_result_ready = xif_result_if.result_ready;
    assign xif_result_if.result_valid = cve2_x_result_valid;
    assign xif_result_if.result.id = cve2_x_result.id;
    assign xif_result_if.result.data = cve2_x_result.data;
    assign xif_result_if.result.rd = cve2_x_result.rd;
    assign xif_result_if.result.we = cve2_x_result.we;
    
    // Tie off unused fields to avoid X propagation in simulation
    assign xif_result_if.result.ecsdata = '0;
    assign xif_result_if.result.ecswe   = '0;
    assign xif_result_if.result.exc     = '0;
    assign xif_result_if.result.exccode = '0;
    assign xif_result_if.result.err     = '0;
    assign xif_result_if.result.dbg     = '0;
  % endif

  % if (gr_heep["ext_interrupts"] > 0):
    logic [gr_heep_pkg::ExtInterrupts-1:0] gr_heep_peripheral_vec_int;
    assign gr_heep_peripheral_vec_int_o = gr_heep_peripheral_vec_int;
    assign gr_heep_peripheral_int_o = |gr_heep_peripheral_vec_int;
  % endif

  % if (gr_heep["periph_nslaves"] > 0):
    xheep_reg_pkg::xheep_reg_req_t [gr_heep_pkg::ExtPeriphNSlaveRnd-1:0] gr_heep_peripheral_req;
    xheep_reg_pkg::xheep_reg_rsp_t [gr_heep_pkg::ExtPeriphNSlaveRnd-1:0] gr_heep_peripheral_rsp;

    logic [gr_heep_pkg::LogExtPeriphNSlave-1:0] ext_periph_select;

    // External bus for register interfaces
    addr_decode #(
        .NoIndices(gr_heep_pkg::ExtPeriphNSlave),
        .NoRules(gr_heep_pkg::ExtPeriphNSlave),
        .addr_t(logic [31:0]),
        .rule_t(addr_map_rule_pkg::addr_map_rule_t)
    ) addr_decode_gr_heep_ext_periph_i (
        .addr_i(gr_heep_peripheral_req_i.addr),
        .addr_map_i(gr_heep_pkg::ExtPeriphAddrRules),
        .idx_o(ext_periph_select),
        .dec_valid_o(),
        .dec_error_o(),
        .en_default_idx_i(1'b1),
        .default_idx_i(gr_heep_pkg::LogExtPeriphNSlave'(gr_heep_pkg::ExtPeriphDefaultIdx))
    );

    reg_demux #(
        .NoPorts(gr_heep_pkg::ExtPeriphNSlaveRnd),
        .req_t  (xheep_reg_pkg::xheep_reg_req_t),
        .rsp_t  (xheep_reg_pkg::xheep_reg_rsp_t)
    ) reg_demux_i (
        .clk_i,
        .rst_ni,
        .in_select_i(ext_periph_select),
        .in_req_i(gr_heep_peripheral_req_i),
        .in_rsp_o(gr_heep_peripheral_rsp_o),
        .out_req_o(gr_heep_peripheral_req),
        .out_rsp_i(gr_heep_peripheral_rsp)
    );

    // Instantiate here the external peripherals
    % for a_slave in gr_heep["peripherals"]:
        // % if (a_slave['name'] == "TestIp"):
        //   // Test IP
        //   test_ip test_ip_i (
        //       .clk_i,
        //       .rst_ni(rst_ni),
        //       .reg_req_i(gr_heep_peripheral_req[gr_heep_pkg::TestIpPeriphIdx]),
        //       .reg_rsp_o(gr_heep_peripheral_rsp[gr_heep_pkg::TestIpPeriphIdx]),
        //       .read_req_i(gr_heep_slave_req_i[gr_heep_pkg::TestIpIdx]),
        //       .read_resp_o(gr_heep_slave_resp_o[gr_heep_pkg::TestIpIdx]),
        //       .gr_heep_peripheral_vec_int[0]
        //   );
        // % endif
    % endfor
  % endif

  % if (cpu.name == "cv32e40px" and xif):
    // Example coprocessor CV-X-IF v0.2 compliant.
    // xif_copro #(
    //     .INPUT_BUFFER_DEPTH(1),
    //     .FORWARDING(1)
    // ) xif_copro_i (
    //     .clk_i(clk_i),
    //     .rst_ni(rst_ni),
    //     .xif_compressed_if(xif_compressed_if),
    //     .xif_issue_if(xif_issue_if),
    //     .xif_commit_if(xif_commit_if),
    //     .xif_mem_if(xif_mem_if),
    //     .xif_mem_result_if(xif_mem_result_if),
    //     .xif_result_if(xif_result_if)
    // );
  % endif

  % if (cpu.name == "cv32e20" and xif):
    // Example coprocessor CV-X-IF v1.0 compliant.
    // cvxif_example_coprocessor #(
    //     .NrRgprPorts(cve2_pkg::X_NUM_RS),
    //     .XLEN(cve2_pkg::X_RFR_WIDTH),
    //     .readregflags_t(cve2_pkg::readregflags_t),
    //     .writeregflags_t(cve2_pkg::writeregflags_t),
    //     .id_t(cve2_pkg::id_t),
    //     .hartid_t(cve2_pkg::hartid_t),
    //     .x_issue_req_t(cve2_pkg::x_issue_req_t),
    //     .x_issue_resp_t(cve2_pkg::x_issue_resp_t),
    //     .x_register_t(cve2_pkg::x_register_t),
    //     .x_commit_t(cve2_pkg::x_commit_t),
    //     .x_result_t(cve2_pkg::x_result_t)
    // ) i_coprocessor (
    //     .clk_i(clk_i),
    //     .rst_ni(rst_ni),
    //     .x_issue_valid_i(cve2_x_issue_valid),
    //     .x_issue_ready_o(cve2_x_issue_ready),
    //     .x_issue_req_i(cve2_x_issue_req),
    //     .x_issue_resp_o(cve2_x_issue_resp),
    //     .x_register_i(cve2_x_register),
    //     .x_register_valid_i(cve2_x_register_valid),
    //     .x_commit_valid_i(cve2_x_commit_valid),
    //     .x_commit_i(cve2_x_commit),
    //     .x_result_valid_o(cve2_x_result_valid),
    //     .x_result_ready_i(cve2_x_result_ready),
    //     .x_result_o(cve2_x_result)
    // );
  % endif

endmodule
