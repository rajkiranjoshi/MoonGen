local mg      = require "moongen"
local memory  = require "memory"
local device  = require "device"
-- local ts      = require "timestamping"
local stats   = require "stats"
-- local hist    = require "histogram"
local log     = require "log"
-- local limiter = require "software-ratecontrol"

local DST_MAC   = "aa:aa:aa:aa:aa:aa"
local SRC_IP    = "20.1.1.2"
local DST_IP    = "40.1.1.2"
local SRC_PORT  = 36666
local DST_PORT  = 6666
local PKT_SIZE  = 60

function master(txPort, rate)
    if not txPort or not rate then
        return print("usage: txPort rate(Gbps)")
    end
    txPort = txPort or 0
    rate = rate or 10

    local txDev = device.config{port = txPort, txQueues = 1, disableOffloads = true}
    device.waitForLinks()
    

    stats.startStatsTask{txDevices = {txDev}}

    mg.startTask("loadSlave", txDev:getTxQueue(0), txDev, rate, SRC_IP)
    mg.waitForTasks()
end


function loadSlave(queue, txDev, rate, srcIP)
    local mem = memory.createMemPool(4096, function(buf)
        buf:getTestPacket():fill{
            ethSrc = txDev,
            ethDst = DST_MAC,
            ip4Src = srcIP,
            ip4Dst = DST_IP,
            PKT_NUMBER = 25,
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

