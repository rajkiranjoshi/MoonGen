local mg      = require "moongen"
local memory  = require "memory"
local device  = require "device"
-- local ts      = require "timestamping"
local stats   = require "stats"
-- local hist    = require "histogram"
local log     = require "log"
-- local limiter = require "software-ratecontrol"

local DST_MAC   = "b0:bb:bb:bb:bb:bf" -- special for linkfailure delay expt
local SRC_IP    = "20.1.1.2"
local dst_ip1   = "40.1.1.2"
--local dst_ip2   = "30.1.1.2"
local SRC_PORT  = 36666
local DST_PORT  = 6666
local PKT_SIZE  = 60

function master(txPort1, rate1) -- , txPort2, rate2)
    if not txPort1 or not rate1 then -- or not txPort2 or not rate2 then
        return print("usage: txPort1(normal) rate1") --  txPort2(backup) rate2")
    end

    local txDev1 = device.config{port = txPort1, txQueues = 1, disableOffloads = true}
--    local txDev2 = device.config{port = txPort2, txQueues = 1, disableOffloads = true}
    device.waitForLinks()

    stats.startStatsTask{txDevices = {txDev1}} -- ,txDev2}}

    mg.startTask("loadSlave", txDev1:getTxQueue(0), txDev1, rate1, dst_ip1)
--    mg.startTask("loadSlave", txDev2:getTxQueue(0), txDev2, rate2, dst_ip2)
    mg.waitForTasks()
end


function loadSlave(queue, txDev, rate, dst_ip)
    local mem = memory.createMemPool(4096, function(buf)
        buf:getUdpPacket():fill{
            ethSrc = txDev,
            ethDst = DST_MAC,
            ip4Src = SRC_IP,
            ip4Dst = dst_ip,
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

