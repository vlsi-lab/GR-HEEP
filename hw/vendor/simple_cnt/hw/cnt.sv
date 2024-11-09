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
// File: cnt.sv
// Author(s):
//   Luigi Giuffrida
//   Michele Caon
// Date: 08/11/2024
// Description: Simple up counter with programmable threshold

module cnt #(
  // Counter bitwidth
  parameter int W = 16
) (
  input logic clk_i,
  input logic rst_ni,

  input  logic         en_i,      // counter enable
  input  logic         clr_i,     // reset counter to zero
  input  logic         ld_i,      // counter load
  input  logic [W-1:0] ld_val_i,  // value to load
  input  logic [W-1:0] thr_i,     // counter threshold
  output logic [W-1:0] cnt_o,     // current counter value
  output logic         tc_o       // threshold crossed
);
  // INTERNAL SIGNALS
  logic [W-1:0] cnt_val;  // current counter value
  logic         tc;  // terminal count

  // COUNTER LOGIC
  always_ff @(posedge clk_i or negedge rst_ni) begin  // asynchronous reset
    if (!rst_ni) cnt_val <= 'h0;
    else begin  // synchronous clear and count
      if (clr_i) cnt_val <= 'h0;
      else if (ld_i) cnt_val <= ld_val_i;
      else if (en_i) begin
        if (tc) cnt_val <= 'h0;
        else cnt_val <= cnt_val + 'h1;
      end
    end
  end

  assign tc    = (cnt_val == thr_i);

  // OUTPUT ASSIGNMENTS
  assign cnt_o = cnt_val;
  assign tc_o  = tc;
endmodule
