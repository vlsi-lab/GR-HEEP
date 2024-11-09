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
// File: cnt_tb.cpp
// Author(s):
//   Luigi Giuffrida
//   Michele Caon
// Date: 08/11/2024
// Description: TB for the OBI counter

#include <iostream>
#include <getopt.h>
#include <random>
#include <time.h>

// Verilator libraries
#include <verilated.h>
#include <verilated_fst_c.h>

// DUT header
#include "Vcnt_obi.h"
#include "cnt_control_reg.h"

// Testbench components
#include "tb_macros.hh"
#include "tb_components.hh"

// Defines
// -------
#define FST_FILENAME "logs/waves.fst"
#define END_OF_RESET_TIME 5
#define MAX_SIM_CYCLES 2e6
#define MAX_SIM_TIME (MAX_SIM_CYCLES * 2)
#define WATCHDOG_TIMEOUT 100 // cycles to wait for a program step to complete
#define END_OF_TEST_TIMEOUT 10 // cycles between done assertion and simulation end
#define RUN_CYCLES 500

// Generate clock and reset
void clkGen(Vcnt_obi *dut);
void rstDut(Vcnt_obi *dut, vluint64_t sim_time);

// Generate OBI transactions
ReqTx *genWriteReqTx(const vluint32_t addr_offs, const vluint32_t wdata, vluint8_t be);
ReqTx *genReadReqTx(const vluint32_t addr_offs);

// Run a number of cycles
void runCycles(unsigned int ncycles, Vcnt_obi *dut, uint8_t gen_waves, VerilatedFstC *trace);

// Global variables
vluint64_t sim_cycles = 0;
TbLogger logger;    // testbench logger

int main(int argc, char *argv[])
{
    // Define command-line options
    const option longopts[] = {
        {"log_level", required_argument, NULL, 'l'},
        {"gen_waves", required_argument, NULL, 'w'},
        {"seed", required_argument, NULL, 's'},
        {NULL, 0, NULL, 0}
    };

    // Process command-line options
    // ----------------------------
    int opt; // current option
    int prg_seed = time(NULL);
    bool gen_waves = true;
    while ((opt = getopt_long(argc, argv, "l:w:", longopts, NULL)) >= 0)
    {
        switch (opt)
        {
        case 'l': // set the log level
            logger.setLogLvl(optarg);
            TB_CONFIG("Log level set to %s", optarg);
            break;
        case 'w': // generate waves
            if (!strcmp(optarg, "true")) {
                gen_waves = 1;
                TB_CONFIG("Waves enabled");
            }
            else {
                gen_waves = 0;
                TB_CONFIG("Waves disabled");
            }
            break;
        case 's': // set the seed
            prg_seed = atoi(optarg);
            TB_CONFIG("Seed set to %d", prg_seed);
            break;
        default:
            TB_ERR("ERROR: unrecognised option %c.\n", opt);
            exit(EXIT_FAILURE);
        }
    }

    // Create Verilator simulation context
    VerilatedContext *cntx = new VerilatedContext;

    // Pass simulation context to the logger
    logger.setSimContext(cntx);

    if (gen_waves)
    {
        Verilated::mkdir("logs");
        cntx->traceEverOn(true);
    }

    // Instantiate DUT
    Vcnt_obi *dut = new Vcnt_obi(cntx);

    // Set the file to store the waveforms in
    VerilatedFstC *trace = NULL;
    if (gen_waves)
    {
        trace = new VerilatedFstC;
        dut->trace(trace, 10);
        trace->open(FST_FILENAME);
    }

    // TB components
    Drv *drv = new Drv(dut);
    Scb *scb = new Scb();
    ReqMonitor *reqMon = new ReqMonitor(dut, scb);
    RspMonitor *rspMon = new RspMonitor(dut, scb);

    // Initialize PRG
    srand(prg_seed);

    // Simulation program
    // ------------------
    unsigned int step_cnt = 0;
    unsigned int prev_step_cnt = 0; // previous test program step counter
    unsigned int watchdog = 0; // watchdog counter
    bool end_of_test = false;
    unsigned int exit_timer = 0; // exit timer
    bool req_accepted = false; // OBI request accepted flag
    bool irq_received = false; // interrupt received flag
    vluint32_t data = 0;
    vluint32_t rdata = 0;
    vluint32_t thr = rand() % 63 + 1;
    ReqTx *req = NULL;

    TB_LOG(LOG_LOW, "Starting simulation...");
    while (!cntx->gotFinish() && cntx->time() < MAX_SIM_TIME)
    {
        // Generate clock and reset
        rstDut(dut, cntx->time());
        clkGen(dut);

        // Evaluate simulation step
        dut->eval();

        if (dut->clk_i == 1 && cntx->time() > END_OF_RESET_TIME)
        {
            switch (step_cnt)
            {
            // Set the counter threshold
            case 0:
                if (!req_accepted) {
                    data = thr;
                    TB_LOG(LOG_HIGH, "## Writing counter threshold to '%u'...", data);
                    req = genWriteReqTx(CNT_CONTROL_THRESHOLD_REG_OFFSET, data, 0xf);
                    break;
                }
                req_accepted = false;
                step_cnt++;
            
            // Read back the threshold value
            case 1:
                if (!req_accepted) {
                    TB_LOG(LOG_HIGH, "## Reading counter threshold...");
                    req = genReadReqTx(CNT_CONTROL_THRESHOLD_REG_OFFSET);
                    break;
                }
                scb->scheduleCheck(data);
                req_accepted = false;
                step_cnt++; // and fall through
            
            // Read the current counter value
            case 2:
                step_cnt++;
                break;

            // Read the TC bit
            case 3:
                if (!req_accepted) {
                    TB_LOG(LOG_HIGH, "## Reading TC bit...");
                    req = genReadReqTx(CNT_CONTROL_STATUS_REG_OFFSET);
                    break;
                }
                scb->scheduleCheck(0);
                req_accepted = false;
                step_cnt++; // and fall through

            // Set the counter enable bit
            case 4:
                if (!req_accepted) {
                    TB_LOG(LOG_HIGH, "## Enabling counter...");
                    data = 1 << CNT_CONTROL_CONTROL_ENABLE_BIT;
                    req = genWriteReqTx(CNT_CONTROL_CONTROL_REG_OFFSET, data, 0x1);
                    break;
                }
                req_accepted = false;
                step_cnt++; // and fall through

            // Read back the control register
            case 5:
                if (!req_accepted) {
                    TB_LOG(LOG_HIGH, "## Reading control register...");
                    req = genReadReqTx(CNT_CONTROL_CONTROL_REG_OFFSET);
                    break;
                }
                scb->scheduleCheck(data);
                req_accepted = false;
                step_cnt++; // and fall through

            // Wait some cycles
            case 6 ... 10:
                step_cnt++;
                break;

            // Read counter value
            case 11:
                step_cnt++;
                break;

            // Wait for interrupt
            case 12:
                if (!irq_received) break;
                TB_LOG(LOG_LOW, "## Interrupt received!");
                step_cnt++;

            // Read counter value
            case 13:
                step_cnt++;
                break;

            // Disable the counter
            case 14:
                if (!req_accepted) {
                    TB_LOG(LOG_HIGH, "## Disabling counter...");
                    data = 0;
                    req = genWriteReqTx(CNT_CONTROL_CONTROL_REG_OFFSET, data, 0x1);
                    break;
                }
                req_accepted = false;
                step_cnt++; // and fall through

            // Wait some cycles
            case 15 ... 19:
                step_cnt++;
                break;

            // Read the counter value
            case 20:
                step_cnt++;
                break;

            // Read the TC bit
            case 21:
                if (!req_accepted) {
                    TB_LOG(LOG_HIGH, "## Reading TC bit...");
                    req = genReadReqTx(CNT_CONTROL_STATUS_REG_OFFSET);
                    break;
                }
                scb->scheduleCheck(1);
                req_accepted = false;
                step_cnt++; // and fall through

            // Clear the counter
            case 22:
                if (!req_accepted) {
                    TB_LOG(LOG_HIGH, "## Clearing counter...");
                    data = 1 << CNT_CONTROL_CONTROL_CLEAR_BIT;
                    req = genWriteReqTx(CNT_CONTROL_CONTROL_REG_OFFSET, data, 0x1);
                    break;
                }
                req_accepted = false;
                step_cnt++; // and fall through

            // Wait one cycle
            case 23:
                step_cnt++;
                break;

            // Read the counter value
            case 24:
                step_cnt++;
                break;

            // Wait some cycles
            case 25 ... 29:
                step_cnt++;
                break;

            // Set a new threshold
            case 30:
                if (!req_accepted) {
                    thr = rand() % 63 + 1;
                    TB_LOG(LOG_HIGH, "## Writing counter threshold to '%u'...", thr);
                    req = genWriteReqTx(CNT_CONTROL_THRESHOLD_REG_OFFSET, thr, 0xf);
                    break;
                }
                req_accepted = false;
                step_cnt++; // and fall through

            // Read back the threshold value
            case 31:
                if (!req_accepted) {
                    TB_LOG(LOG_HIGH, "## Reading counter threshold...");
                    req = genReadReqTx(CNT_CONTROL_THRESHOLD_REG_OFFSET);
                    break;
                }
                scb->scheduleCheck(thr);
                req_accepted = false;
                step_cnt++; // and fall through

            // Restart the counter
            case 32:
                if (!req_accepted) {
                    TB_LOG(LOG_HIGH, "## Enabling counter...");
                    data = 1 << CNT_CONTROL_CONTROL_ENABLE_BIT;
                    req = genWriteReqTx(CNT_CONTROL_CONTROL_REG_OFFSET, data, 0x1);
                    break;
                }
                req_accepted = false;
                step_cnt++; // and fall through

            // Wait for TC in polling
            case 33:
                if (!req_accepted) {
                    TB_LOG(LOG_FULL, "## Polling TC bit...");
                    req = genReadReqTx(CNT_CONTROL_STATUS_REG_OFFSET);
                    break;
                }
                req_accepted = false;
                step_cnt++; // and fall through
            
            // Wait for TC in polling
            case 34:
                if (rdata & (1 << CNT_CONTROL_STATUS_TC_BIT)) {
                    TB_LOG(LOG_LOW, "## TC bit set!");
                    step_cnt++;
                    break;
                }
                TB_LOG(LOG_FULL, "## Polling TC bit...");
                req = genReadReqTx(CNT_CONTROL_STATUS_REG_OFFSET);
                break;

            // Clear TC bit
            case 35:
                if (!req_accepted) {
                    TB_LOG(LOG_HIGH, "## Clearing TC bit...");
                    data = 1 << CNT_CONTROL_STATUS_TC_BIT;
                    req = genWriteReqTx(CNT_CONTROL_STATUS_REG_OFFSET, data, 0x1);
                    break;
                }
                req_accepted = false;
                step_cnt++; // and fall through

            default:
                // Set exit flag
                end_of_test = true;
                break;
            }
            
            // Drive DUT inputs
            drv->drive(req);
            delete req;
            req = NULL;

            // Update input signals
            dut->eval();

            // Monitor DUT signals
            reqMon->monitor();
            rspMon->monitor();
            if (rspMon->isDataReady()) rdata = rspMon->getData();
            req_accepted = reqMon->accepted();
            irq_received = rspMon->irq();

            // Trigger scheduled checks
            if (scb->checkData() != 0) end_of_test = true;

            // Check for exit conditions
            if (prev_step_cnt != step_cnt) watchdog = 0;
            else watchdog++;
            if (watchdog > WATCHDOG_TIMEOUT) {
                TB_WARN("Watchdog timeout reached: terminating simulation.");
                scb->notifyError();
                break;
            }
            prev_step_cnt = step_cnt;
            if (end_of_test)
            {
                if (exit_timer++ == END_OF_TEST_TIMEOUT) {
                    TB_LOG(LOG_MEDIUM, "End of simulation reached: terminating.");
                    break;
                }
            }
        }

        // Dump waveforms and advance simulation time
        if (gen_waves) trace->dump(cntx->time());
        if (dut->clk_i == 1) sim_cycles++;
        cntx->timeInc(1);
    }

    // Simulation complete
    dut->final();

    // Print simulation summary
    if (scb->getErrNum() > 0)
    {
        TB_ERR("CHECKS FAILED > errors: %u/%u", scb->getErrNum(), scb->getTxNum());
        if (gen_waves) trace->close();
        exit(EXIT_SUCCESS);
    }
    else 
    {
        TB_SUCCESS(LOG_LOW, "CHECKS PASSED > errors: %u (checked %u transactions)", scb->getErrNum(), scb->getTxNum());
    }

    // Clean up and exit
    if (gen_waves) trace->close();
    delete dut;
    delete cntx;
    delete req;

    return 0;
}

void clkGen(Vcnt_obi *dut)
{
    dut->clk_i ^= 1;
}

void rstDut(Vcnt_obi *dut, vluint64_t sim_time)
{
    dut->rst_ni = 1;
    if (sim_time > 1 && sim_time < END_OF_RESET_TIME)
    {
        dut->rst_ni = 0;
    }
}

void runCycles(unsigned int ncycles, Vcnt_obi *dut, uint8_t gen_waves, VerilatedFstC *trace)
{
    VerilatedContext *cntx = dut->contextp();
    for (unsigned int i = 0; i < (2 * ncycles); i++)
    {
        // Generate clock
        clkGen(dut);

        // Evaluate the DUT
        dut->eval();

        // Save waveforms
        if (gen_waves)
            trace->dump(cntx->time());
        if (dut->clk_i == 1)
            sim_cycles++;
        cntx->timeInc(1);
    }
}

// Issue write OBI transaction
ReqTx *genWriteReqTx(const vluint32_t addr_offs, const vluint32_t wdata, vluint8_t be)
{
    ReqTx *req = new ReqTx;

    // OBI write request
    req->obi_req.req = 1;
    req->obi_req.we = 1;
    req->obi_req.be = be;
    req->obi_req.addr = addr_offs;
    req->obi_req.wdata = wdata;

    return req;
}

// Issue read OBI transaction
ReqTx *genReadReqTx(const vluint32_t addr_offs)
{
    ReqTx *req = new ReqTx;

    // OBI read request
    req->obi_req.req = 1;
    req->obi_req.we = 0;
    req->obi_req.be = 0xf;
    req->obi_req.addr = addr_offs;
    req->obi_req.wdata = 0;

    return req;
}
