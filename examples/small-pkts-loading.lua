local mg      = require "moongen"
local memory  = require "memory"
local device  = require "device"
-- local ts      = require "timestamping"
local stats   = require "stats"
-- local hist    = require "histogram"
local log     = require "log"
-- local limiter = require "software-ratecontrol"

local DST_MAC   = "aa:aa:aa:aa:aa:aa"
local SRC_IP1    = "50.1.1.2"
local SRC_IP2    = "60.1.1.2"
local DST_IP    = "10.1.1.2"
local SRC_PORT  = 36666
local DST_PORT  = 6666
local PKT_SIZE  = 60

function master(txPort1, txPort2, rate)
    if not txPort1 or not txPort2 or not rate then
        return print("usage: txPort1 txPort2 rate(Gbps)")
    end
    txPort1 = txPort1 or 0
    txPort2 = txPort2 or 1
    rate = rate or 10

    local txDev1 = device.config{port = txPort1, txQueues = 1, disableOffloads = true}
    device.waitForLinks()
    local txDev2 = device.config{port = txPort2, txQueues = 1, disableOffloads = true}
    device.waitForLinks()

    stats.startStatsTask{txDevices = {txDev1, txDev2}}

    mg.startTask("loadSlave", txDev1:getTxQueue(0), txDev1, rate, SRC_IP1)
    mg.startTask("loadSlave", txDev2:getTxQueue(0), txDev2, rate, SRC_IP2)
    mg.waitForTasks()
end


function loadSlave(queue, txDev, rate, srcIP)
    local mem = memory.createMemPool(4096, function(buf)
        buf:getUdpPacket():fill{
            ethSrc = txDev,
            ethDst = DST_MAC,
            ip4Src = srcIP,
            ip4Dst = DST_IP,
            udpSrc = SRC_PORT,
            udpDst = DST_PORT,
            pktLength = PKT_SIZE
        }
    end)
    
    local bufs = mem:bufArray()
    queue:setRate(rate * 1000)
    mg.sleepMillis(100) -- for good meaasure
    while mg.running() do
        bufs:alloc(PKT_SIZE)
        queue:send(bufs)
    end
    
end

