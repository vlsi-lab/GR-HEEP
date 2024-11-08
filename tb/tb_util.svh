// Copyright 2022 OpenHW Group
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

// GR-HEEP top-level

`ifdef RTL_SIMULATION

`ifdef VERILATOR
`define TOP u_gr_heep_top
`else
`define TOP u_tb_system.u_gr_heep_top
`endif

// task for loading 'mem' with SystemVerilog system task $readmemh()
export "DPI-C" task tb_readHEX;
export "DPI-C" task tb_loadHEX;
export "DPI-C" task tb_getMemSize;
export "DPI-C" task tb_set_exit_loop;

import core_v_mini_mcu_pkg::*;

function int tb_check_if_any_not_X(logic [31:0] input_word);
  for(int unsigned i = 0; i < 32; i=i+1) begin
    if ( input_word[i] !== 1'bx ) return 1;
  end
  return 0;
endfunction


task tb_getMemSize;
  output int mem_size;
  mem_size  = core_v_mini_mcu_pkg::MEM_SIZE;
endtask

task tb_readHEX;
  input string file;
  output logic [7:0] stimuli[core_v_mini_mcu_pkg::MEM_SIZE];
  $readmemh(file, stimuli);
endtask

task tb_loadHEX;
  input string file;
  //whether to use debug to write to memories
  logic [7:0] stimuli[core_v_mini_mcu_pkg::MEM_SIZE];
  int i, stimuli_base, w_addr, NumBytes;

  tb_readHEX(file, stimuli);
  tb_getMemSize(NumBytes);

`ifdef LOADHEX_DBG

`ifdef VERILATOR
  $fatal("ERR! LOADHEX_DBG not supported in Verilator");
`endif

  for (i = 0; i < NumBytes; i = i + 4) begin

    if( tb_check_if_any_not_X({stimuli[i+3], stimuli[i+2], stimuli[i+1], stimuli[i]}) ) begin
      @(posedge `TOP.u_core_v_mini_mcu.clk_i);
      addr = i;
      #1;
      // write to memory
      force `TOP.u_core_v_mini_mcu.debug_subsystem_i.dm_obi_top_i.master_req_o = 1'b1;
      force `TOP.u_core_v_mini_mcu.debug_subsystem_i.dm_obi_top_i.master_addr_o = addr;
      force `TOP.u_core_v_mini_mcu.debug_subsystem_i.dm_obi_top_i.master_we_o = 1'b1;
      force `TOP.u_core_v_mini_mcu.debug_subsystem_i.dm_obi_top_i.master_be_o = 4'b1111;
      force `TOP.u_core_v_mini_mcu.debug_subsystem_i.dm_obi_top_i.master_wdata_o = {
        stimuli[i+3], stimuli[i+2], stimuli[i+1], stimuli[i]
      };

      while(!`TOP.u_core_v_mini_mcu.debug_subsystem_i.dm_obi_top_i.master_gnt_i) begin
        @(posedge `TOP.u_core_v_mini_mcu.clk_i);
      end

      #1;
      force `TOP.u_core_v_mini_mcu.debug_subsystem_i.dm_obi_top_i.master_req_o = 1'b0;

      wait (`TOP.u_core_v_mini_mcu.debug_subsystem_i.dm_obi_top_i.master_rvalid_i);

      #1;
    end

  end

  release `TOP.u_core_v_mini_mcu.debug_subsystem_i.dm_obi_top_i.master_req_o;
  release `TOP.u_core_v_mini_mcu.debug_subsystem_i.dm_obi_top_i.master_addr_o;
  release `TOP.u_core_v_mini_mcu.debug_subsystem_i.dm_obi_top_i.master_we_o;
  release `TOP.u_core_v_mini_mcu.debug_subsystem_i.dm_obi_top_i.master_be_o;
  release `TOP.u_core_v_mini_mcu.debug_subsystem_i.dm_obi_top_i.master_wdata_o;

`else // LOADHEX_DBG

  for (i=0; i < 32768; i = i + 4) begin
    if (((i/4) & 0) == 0) begin
      w_addr = ((i/4) >> 0) % 8192;
      tb_writetoSram0(w_addr, stimuli[i+3], stimuli[i+2],
                                          stimuli[i+1], stimuli[i]);
    end
  end
  for (i=32768; i < 65536; i = i + 4) begin
    if (((i/4) & 0) == 0) begin
      w_addr = ((i/4) >> 0) % 8192;
      tb_writetoSram1(w_addr, stimuli[i+3], stimuli[i+2],
                                          stimuli[i+1], stimuli[i]);
    end
  end
  for (i=65536; i < 98304; i = i + 4) begin
    if (((i/4) & 1) == 0) begin
      w_addr = ((i/4) >> 1) % 4096;
      tb_writetoSram2(w_addr, stimuli[i+3], stimuli[i+2],
                                          stimuli[i+1], stimuli[i]);
    end
  end
  for (i=65536; i < 98304; i = i + 4) begin
    if (((i/4) & 1) == 1) begin
      w_addr = ((i/4) >> 1) % 4096;
      tb_writetoSram3(w_addr, stimuli[i+3], stimuli[i+2],
                                          stimuli[i+1], stimuli[i]);
    end
  end

`ifndef VERILATOR
  // Release memory signals
  tb_releaseSram0();
  tb_releaseSram1();
  tb_releaseSram2();
  tb_releaseSram3();

`endif // VERILATOR

`endif // LOADHEX_DBG
endtask


task tb_writetoSram0;
  input int addr;
  input [7:0] val3;
  input [7:0] val2;
  input [7:0] val1;
  input [7:0] val0;
`ifdef VCS
  force `TOP.u_core_v_mini_mcu.memory_subsystem_i.ram0_i.tc_ram_i.sram[addr] = {
    val3, val2, val1, val0
  };
  release `TOP.u_core_v_mini_mcu.memory_subsystem_i.ram0_i.tc_ram_i.sram[addr];
`else
  `TOP.u_core_v_mini_mcu.memory_subsystem_i.ram0_i.tc_ram_i.sram[addr] = {
    val3, val2, val1, val0
  };
`endif
endtask
task tb_writetoSram1;
  input int addr;
  input [7:0] val3;
  input [7:0] val2;
  input [7:0] val1;
  input [7:0] val0;
`ifdef VCS
  force `TOP.u_core_v_mini_mcu.memory_subsystem_i.ram1_i.tc_ram_i.sram[addr] = {
    val3, val2, val1, val0
  };
  release `TOP.u_core_v_mini_mcu.memory_subsystem_i.ram1_i.tc_ram_i.sram[addr];
`else
  `TOP.u_core_v_mini_mcu.memory_subsystem_i.ram1_i.tc_ram_i.sram[addr] = {
    val3, val2, val1, val0
  };
`endif
endtask
task tb_writetoSram2;
  input int addr;
  input [7:0] val3;
  input [7:0] val2;
  input [7:0] val1;
  input [7:0] val0;
`ifdef VCS
  force `TOP.u_core_v_mini_mcu.memory_subsystem_i.ram2_i.tc_ram_i.sram[addr] = {
    val3, val2, val1, val0
  };
  release `TOP.u_core_v_mini_mcu.memory_subsystem_i.ram2_i.tc_ram_i.sram[addr];
`else
  `TOP.u_core_v_mini_mcu.memory_subsystem_i.ram2_i.tc_ram_i.sram[addr] = {
    val3, val2, val1, val0
  };
`endif
endtask
task tb_writetoSram3;
  input int addr;
  input [7:0] val3;
  input [7:0] val2;
  input [7:0] val1;
  input [7:0] val0;
`ifdef VCS
  force `TOP.u_core_v_mini_mcu.memory_subsystem_i.ram3_i.tc_ram_i.sram[addr] = {
    val3, val2, val1, val0
  };
  release `TOP.u_core_v_mini_mcu.memory_subsystem_i.ram3_i.tc_ram_i.sram[addr];
`else
  `TOP.u_core_v_mini_mcu.memory_subsystem_i.ram3_i.tc_ram_i.sram[addr] = {
    val3, val2, val1, val0
  };
`endif
endtask

`ifndef VERILATOR

task tb_releaseSram0;
  release `TOP.u_core_v_mini_mcu.memory_subsystem_i.ram0_i.tc_ram_i.sram;
endtask
task tb_releaseSram1;
  release `TOP.u_core_v_mini_mcu.memory_subsystem_i.ram1_i.tc_ram_i.sram;
endtask
task tb_releaseSram2;
  release `TOP.u_core_v_mini_mcu.memory_subsystem_i.ram2_i.tc_ram_i.sram;
endtask
task tb_releaseSram3;
  release `TOP.u_core_v_mini_mcu.memory_subsystem_i.ram3_i.tc_ram_i.sram;
endtask

`endif // VERILATOR

task tb_set_exit_loop;
`ifdef VCS
  force `TOP.u_core_v_mini_mcu.ao_peripheral_subsystem_i.soc_ctrl_i.testbench_set_exit_loop[0] = 1'b1;
  release `TOP.u_core_v_mini_mcu.ao_peripheral_subsystem_i.soc_ctrl_i.testbench_set_exit_loop[0];
`elsif VERILATOR
  `TOP.u_core_v_mini_mcu.ao_peripheral_subsystem_i.soc_ctrl_i.testbench_set_exit_loop[0] = 1'b1;
`else
    `TOP.u_core_v_mini_mcu.ao_peripheral_subsystem_i.soc_ctrl_i.testbench_set_exit_loop[0] = 1'b1;
`endif
endtask
`endif //RTL_SIMULATION

