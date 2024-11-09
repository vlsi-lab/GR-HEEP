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
// File: tb_components.hh
// Author(s):
//   Michele Caon
// Date: 08/11/2024
// Description: Testbench components

#if !defined(TB_COMPONENTS_HH_)
#define TB_COMPONENTS_HH_

#include <verilated.h>
#include "Vcnt_obi.h"
#include "obi.hh"
#include "reg.hh"

class ReqTx
{
public:
    obi_req_t obi_req;
    reg_req_t reg_req;

    ReqTx();
    ~ReqTx();

    void reset();
};

class RspTx
{
public:
    obi_rsp_t obi_rsp;
    reg_rsp_t reg_rsp;

    RspTx();
    ~RspTx();
};

class Drv
{
private:
    Vcnt_obi *dut;

public:
    Drv(Vcnt_obi *dut);
    ~Drv();

    void drive(ReqTx *req);
};

class Scb
{
private:
    std::deque<ReqTx *> req_q;
    std::deque<RspTx *> rsp_q;
    std::deque<vluint32_t> exp_q;
    unsigned int tx_num;
    unsigned int err_num;

public:
    Scb();
    ~Scb();

    void writeReq(ReqTx *req);
    void writeRsp(RspTx *rsp);

    bool scheduleCheck(vluint32_t exp_value);
    int checkData();
    int isDone();

    void clearQueues();
    void popReq();
    
    void notifyError();
    unsigned int getTxNum();
    unsigned int getErrNum();
};

class ReqMonitor
{
private:
    Vcnt_obi *dut;
    Scb *scb;

public:
    ReqMonitor(Vcnt_obi *dut, Scb *scb);
    ~ReqMonitor();

    void monitor();
    bool accepted();
};

class RspMonitor
{
private:
    Vcnt_obi *dut;
    Scb *scb;
    bool pending_read_req[2]; // at most two outstanding requests

public:
    RspMonitor(Vcnt_obi *dut, Scb *scb);
    ~RspMonitor();

    void monitor();
    bool isDataReady();
    bool irq();
    vluint32_t getData();
};

#endif // TB_COMPONENTS_HH_
