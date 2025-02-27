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
// File: handler.c
// Author(s):
//   Michele Caon
// Date: 11/11/2024
// Description: External interrupt handlers

#include "handler.h"
#include "rv_plic.h"
#include "csr.h"

/**********************************/
/* ---- FUNCTION DEFINITIONS ---- */
/**********************************/

int ext_irq_init(void) {
    // Initialize PLIC for external interrupts
    if (plic_Init() != kPlicOk)
        return -1;

    // Enable global interrupts
    CSR_SET_BITS(CSR_REG_MSTATUS, 0x8); // mstatus.mie: globally enable machine-level interrupts
    CSR_SET_BITS(CSR_REG_MIE, (1 << 11)); // mie.meie: enable machine-level external interrupts

    // Return success
    return 0;
}