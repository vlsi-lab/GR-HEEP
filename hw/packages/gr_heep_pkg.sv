// Copyright 2024 Politecnico di Torino.
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// File: gr_heep_pkg.sv
// Author: Luigi Giuffrida
// Date: 16/10/2024
// Description: GR-HEEP pkg

package gr_heep_pkg;

  import addr_map_rule_pkg::*;
  import core_v_mini_mcu_pkg::*;

  // ---------------
  // CORE-V-MINI-MCU
  // ---------------

  // CPU
  localparam int unsigned CpuCorevPulp = 32'd1;
  localparam int unsigned CpuCorevXif = 32'd1;
  localparam int unsigned CpuFpu = 32'd1;
  localparam int unsigned CpuRiscvZfinx = 32'd0;

  // SPC
  localparam int unsigned AoSPCNum = 32'd1;

  localparam int unsigned DMAMasterPortsNum = DMA_NUM_MASTER_PORTS;
  localparam int unsigned DMACHNum = DMA_CH_NUM;

  // --------------------
  // CV-X-IF COPROCESSORS
  // --------------------



  // ----------------
  // EXTERNAL OBI BUS
  // ----------------

  // Number of masters and slaves
  localparam int unsigned ExtXbarNMaster = 32'd0;
  localparam int unsigned ExtXbarNSlave = 32'd1;
  localparam int unsigned ExtXbarNMasterRnd = ExtXbarNMaster > 0 ? ExtXbarNMaster : 32'd1;
  localparam int unsigned ExtXbarNSlaveRnd = ExtXbarNSlave > 0 ? ExtXbarNSlave : 32'd1;
  localparam int unsigned LogExtXbarNMaster = ExtXbarNMaster > 32'd1 ? $clog2(
      ExtXbarNMaster
  ) : 32'd1;
  localparam int unsigned LogExtXbarNSlave = ExtXbarNSlave > 32'd1 ? $clog2(ExtXbarNSlave) : 32'd1;



  // Memory map
  // ----------
  // SimpleCnt
  localparam int unsigned SimpleCntIdx = 32'd0;
  localparam logic [31:0] SimpleCntStartAddr = EXT_SLAVE_START_ADDRESS + 32'h0;
  localparam logic [31:0] SimpleCntSize = 32'h65536;
  localparam logic [31:0] SimpleCntEndAddr = SimpleCntStartAddr + 32'h65536;

  // External slaves address map
  localparam addr_map_rule_t [ExtXbarNSlave-1:0] ExtSlaveAddrRules = '{
      '{idx: SimpleCntIdx, start_addr: SimpleCntStartAddr, end_addr: SimpleCntEndAddr}
  };

  localparam int unsigned ExtSlaveDefaultIdx = 32'd0;


  // --------------------
  // EXTERNAL PERIPHERALS
  // --------------------

  // Number of external peripherals
  localparam int unsigned ExtPeriphNSlave = 32'd1;
  localparam int unsigned LogExtPeriphNSlave = (ExtPeriphNSlave > 32'd1) ? $clog2(
      ExtPeriphNSlave
  ) : 32'd1;
  localparam int unsigned ExtPeriphNSlaveRnd = (ExtPeriphNSlave > 32'd1) ? ExtPeriphNSlave : 32'd1;



  // Memory map
  // ----------
  // SimpleCnt
  localparam int unsigned SimpleCntIdx = 32'd0;
  localparam logic [31:0] SimpleCntStartAddr = PERIPH_SLAVE_START_ADDRESS + 32'h0;
  localparam logic [31:0] SimpleCntSize = 32'h4096;
  localparam logic [31:0] SimpleCntEndAddr = SimpleCntStartAddr + 32'h4096;

  // External peripherals address map
  localparam addr_map_rule_t [ExtPeriphNSlave-1:0] ExtPeriphAddrRules = '{
      '{idx: SimpleCntIdx, start_addr: SimpleCntStartAddr, end_addr: SimpleCntEndAddr}
  };

  localparam int unsigned ExtPeriphDefaultIdx = 32'd0;


  localparam int unsigned ExtInterrupts = 32'd1;

endpackage

