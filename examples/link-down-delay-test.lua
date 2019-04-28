local mg      = require "moongen"
local memory  = require "memory"
local device  = require "device"
-- local ts      = require "timestamping"
local stats   = require "stats"
-- local hist    = require "histogram"
local log     = require "log"
-- local limiter = require "software-ratecontrol"

local DST_MAC   = "bb:bb:bb:bb:bb:bb"
local SRC_IP    = "20.1.1.2"
local DST_IP    = "30.1.1.2"
local SRC_PORT  = 36666
local DST_PORT  = 6666
local PKT_SIZE  = 60

function master(txPort)
    if not txPort then
        return print("usage: txPort")
    end
    txPort = txPort or 0

    local txDev = device.config{port = txPort, txQueues = 1, disableOffloads = true}
    device.waitForLinks()

    stats.startStatsTask{txDevices = {txDev}}

    mg.startTask("loadSlave", txDev:getTxQueue(0), txDev)
    mg.waitForTasks()
end


function loadSlave(queue, txDev)
    local mem = memory.createMemPool(4096, function(buf)
        buf:getUdpPacket():fill{
            ethSrc = txDev,
            ethDst = DST_MAC,
            ip4Src = SRC_IP,
            ip4Dst = DST_IP,
            udpSrc = SRC_PORT,
            udpDst = DST_PORT,
            pktLength = PKT_SIZE
        }
    end)
    
    local bufs = mem:bufArray()
    -- queue:setRate(rate * 1000)
    -- mg.sleepMillis(100) -- for good meaasure
    while mg.running() do
        bufs:alloc(PKT_SIZE)
        queue:send(bufs)
    end
    
end

