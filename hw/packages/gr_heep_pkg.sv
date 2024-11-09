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
  localparam int unsigned CpuCorevPulp = 32'd0;
  localparam int unsigned CpuCorevXif = 32'd0;
  localparam int unsigned CpuFpu = 32'd0;
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
  localparam int unsigned ExtXbarNSlave = 32'd0;
  localparam int unsigned ExtXbarNMasterRnd = ExtXbarNMaster > 0 ? ExtXbarNMaster : 32'd1;
  localparam int unsigned ExtXbarNSlaveRnd = ExtXbarNSlave > 0 ? ExtXbarNSlave : 32'd1;
  localparam int unsigned LogExtXbarNMaster = ExtXbarNMaster > 32'd1 ? $clog2(
      ExtXbarNMaster
  ) : 32'd1;
  localparam int unsigned LogExtXbarNSlave = ExtXbarNSlave > 32'd1 ? $clog2(ExtXbarNSlave) : 32'd1;


  // --------------------
  // EXTERNAL PERIPHERALS
  // --------------------

  // Number of external peripherals
  localparam int unsigned ExtPeriphNSlave = 32'd0;
  localparam int unsigned LogExtPeriphNSlave = (ExtPeriphNSlave > 32'd1) ? $clog2(
      ExtPeriphNSlave
  ) : 32'd1;
  localparam int unsigned ExtPeriphNSlaveRnd = (ExtPeriphNSlave > 32'd1) ? ExtPeriphNSlave : 32'd1;


  localparam int unsigned ExtInterrupts = 32'd0;

endpackage

