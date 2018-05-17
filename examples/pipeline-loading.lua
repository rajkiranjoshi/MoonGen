local mg      = require "moongen"
local memory  = require "memory"
local device  = require "device"
local ts      = require "timestamping"
local stats   = require "stats"
local hist    = require "histogram"
local log     = require "log"
local limiter = require "software-ratecontrol"

local DST_MAC   = "ee:ee:ee:ee:ee:ee"
local SRC_IP    = "50.1.1.2"
local DST_IP    = "60.1.1.2"
local SRC_PORT  = 1234
local DST_PORT  = 319
local PKT_SIZE  = 1500

function master(txPort, rate)
    if not txPort or not rate then
        return print("usage: txPort rate(Mpps)")
    end
    txPort = txPort or 0
    rate = rate or 6

    local txDev = device.config{port = txPort, txQueues = 1, disableOffloads = true}
    device.waitForLinks()
    stats.startStatsTask{txDevices = {txDev}}
    mg.startTask("loadSlave", txDev:getTxQueue(0), txDev, rate)
    mg.waitForTasks()
end


function loadSlave(queue, txDev, rate)
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
    queue:setRate(rate * (PKT_SIZE + 4) * 8)
    mg.sleepMillis(100) -- for good meaasure
    while mg.running() do
        bufs:alloc(PKT_SIZE)
        queue:send(bufs)
    end
    
end

