#include "tb_components.hh"
#include "tb_macros.hh"

ReqTx::ReqTx()
{
    this->obi_req = {0};
    this->reg_req = {0};
}

ReqTx::~ReqTx()
{
}

void ReqTx::reset()
{
    this->obi_req = {0};
    this->reg_req = {0};
}

RspTx::RspTx()
{
}

RspTx::~RspTx()
{
}

Drv::Drv(Vcnt_obi *dut)
{
    this->dut = dut;
}

Drv::~Drv()
{
}

void Drv::drive(ReqTx *req)
{
    this->dut->reg_valid_i = 0;

    if (req != NULL)
    {
        this->dut->reg_valid_i = req->reg_req.valid;
        this->dut->reg_write_i = req->reg_req.write;
        this->dut->reg_wstrb_i = req->reg_req.wstrb;
        this->dut->reg_addr_i = req->reg_req.addr;
        this->dut->reg_wdata_i = req->reg_req.wdata;
    }
}

Scb::Scb()
{
    this->tx_num = 0;
    this->err_num = 0;
}

Scb::~Scb()
{
}

void Scb::writeReq(ReqTx *req)
{
    this->req_q.push_back(req);
}

void Scb::writeRsp(RspTx *rsp)
{
    // Push the sampled response
    this->rsp_q.push_back(rsp);
}

bool Scb::scheduleCheck(vluint32_t exp_value)
{
    TB_DEBUG("SCB > Scheduling read data check: 0x%08x", exp_value);

    // Push the new expected result
    this->exp_q.push_back(exp_value);
    return false;
}

int Scb::checkData()
{
    vluint32_t exp_value;
    RspTx *rsp;
    log_lvl_t log_lvl = LOG_MEDIUM;

    TB_DEBUG("SCB > response queue size: %d | result queue size: %d", this->rsp_q.size(), this->exp_q.size());

    // Check if read data shall be checked
    if (this->exp_q.empty())
    {
        // If no check is scheduled, consume unused responses
        while (this->rsp_q.size() > 0)
        {
            rsp = this->rsp_q.front();
            this->rsp_q.pop_front();
            delete rsp;
        }
        return 0;
    }

    // If the response is not available yet, return and wait for the next cycle
    if (this->rsp_q.empty()) return 0;

    // Else, pop received data and the expected value
    rsp = this->rsp_q.front();
    this->rsp_q.pop_front();
    exp_value = this->exp_q.front();
    this->exp_q.pop_front();

    // Check that the received data has the expected value
    this->tx_num++;
    if (rsp->reg_rsp.rdata != exp_value)
    {
        TB_ERR("SCB > Received data (0x%08x) does not match the expected value (0x%08x)", rsp->reg_rsp.rdata, exp_value);
        this->err_num++;
        delete rsp;
        return -1;
    }

    // Reduce verbosity if data is zero
    if (exp_value == 0) log_lvl = LOG_HIGH;
    
    TB_SUCCESS(log_lvl, "SCB > Received data: 0x%08x (expected: 0x%08x)", rsp->reg_rsp.rdata, exp_value);

    // Clean up
    delete rsp;
    return 0;
}

void Scb::notifyError()
{
    this->err_num++;
}

unsigned int Scb::getTxNum()
{
    return this->tx_num;
}

unsigned int Scb::getErrNum()
{
    return this->err_num;
}

int Scb::isDone()
{
    return this->req_q.empty() && this->rsp_q.empty();
}

void Scb::clearQueues()
{
    while (!this->req_q.empty())
    {
        ReqTx *req = this->req_q.front();
        this->req_q.pop_front();
        delete req;
    }
    while (!this->rsp_q.empty())
    {
        RspTx *rsp = this->rsp_q.front();
        this->rsp_q.pop_front();
        delete rsp;
    }
    while (!this->exp_q.empty())
    {
        this->exp_q.pop_front();
    }
    this->err_num++;
}

void Scb::popReq()
{
    if (this->req_q.empty()) return;
    ReqTx *req = this->req_q.front();
    this->req_q.pop_front();
    delete req;
}

ReqMonitor::ReqMonitor(Vcnt_obi *dut, Scb *scb)
{
    this->dut = dut;
    this->scb = scb;
}

ReqMonitor::~ReqMonitor()
{
}

void ReqMonitor::monitor()
{
    log_lvl_t log_lvl = LOG_HIGH;

    // Check if there's a new request
    if (dut->reg_valid_i && dut->reg_ready_o)
    {
        // Fetch the data from the DUT interface
        ReqTx *req = new ReqTx();
        req->reg_req.valid = dut->reg_valid_i;
        req->reg_req.write = dut->reg_write_i;
        req->reg_req.wstrb = dut->reg_wstrb_i;
        req->reg_req.addr = dut->reg_addr_i;
        req->reg_req.wdata = dut->reg_wdata_i;

        // Print the request content
        TB_LOG(LOG_HIGH, "REG REQ > %-5s | valid: %u | write: %u | wstrb: 0x%1x | addr: 0x%08x | wdata: 0x%08x", (req->reg_req.write) ? "WRITE" : "READ", req->reg_req.valid, req->reg_req.write, req->reg_req.wstrb, req->reg_req.addr, req->reg_req.wdata);
        
        // Send the request to the scoreboard
        delete req;
    }
}

bool ReqMonitor::accepted()
{
    return dut->reg_valid_i & dut->reg_ready_o;
}

RspMonitor::RspMonitor(Vcnt_obi *dut, Scb *scb)
{
    this->dut = dut;
    this->scb = scb;
    for (int i = 0; i < 2; i++)
    {
        this->pending_read_req[i] = false;
    }
}

RspMonitor::~RspMonitor()
{
}

void RspMonitor::monitor()
{
    // Check for new read request
    bool new_read_req = dut->obi_req_i & dut->obi_gnt_o & !dut->obi_we_i;
    
    // Check for correctly delivered response
    if (this->pending_read_req[1] && !dut->obi_rvalid_o && dut->obi_req_i & dut->obi_gnt_o)
    {
        TB_ERR("RSP > Response not delivered");
        this->scb->notifyError();
        this->pending_read_req[1] = this->pending_read_req[0];
        this->pending_read_req[0] = new_read_req;
        // Clear any pending check in the scoreboard
        this->scb->popReq();
        return;
    }

    // Ignore the response if there's no pending read request
    if (!this->pending_read_req[0] || !dut->obi_rvalid_o) 
    {
        this->pending_read_req[1] = this->pending_read_req[0];
        this->pending_read_req[0] = new_read_req;
        return;
    }
    
    // Fetch the data from the DUT interface
    RspTx *rsp = new RspTx();
    rsp->obi_rsp.rvalid = dut->obi_rvalid_o;
    rsp->obi_rsp.rdata = dut->obi_rdata_o;

    // Print the response content
    TB_LOG(LOG_HIGH, "OBI RSP > rvalid: %u | rdata: 0x%08x", rsp->obi_rsp.rvalid, rsp->obi_rsp.rdata);

    // Send the response to the scoreboard
    this->scb->writeRsp(rsp);

    // Update previous read request flag
    this->pending_read_req[1] = false; // clear previous request
    this->pending_read_req[0] = new_read_req;
}

bool RspMonitor::isDataReady()
{
    return this->dut->obi_rvalid_o;
}

bool RspMonitor::irq()
{
    return this->dut->tc_int_o;
}

vluint32_t RspMonitor::getData()
{
    return dut->obi_rdata_o;
}
