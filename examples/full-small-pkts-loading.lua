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
local PKT_SIZE  = 60

-- the following lookup should be set as per the cabling and routing rules in Tofino
-- (1) Dry run MoonGen to see the MAC addresses for the devices (ports)
-- (2) Check routing rules to see dstIP for the corresponding MAC addresses
DEV_IP_LOOKUP = {[0] = "81.1.1.2", [1] = "82.1.1.2"}  -- [0] = "71.1.1.2", [1] = "72.1.1.2", 


function master(txPort1, txPort2)
    if not txPort1 or not txPort2 then
        return print("usage: txPort1 txPort2")
    end
    

    local txDev1 = device.config{port = txPort1, txQueues = 2, disableOffloads = true}
    local txDev2 = device.config{port = txPort2, txQueues = 2, disableOffloads = true}
    device.waitForLinks()

    local srcIP1 = DEV_IP_LOOKUP[txPort1]
    local dstIP1 = DEV_IP_LOOKUP[txPort2]

    local srcIP2 = DEV_IP_LOOKUP[txPort2]
    local dstIP2 = DEV_IP_LOOKUP[txPort1]

    stats.startStatsTask{txDevices = {txDev1, txDev2}}
    mg.startTask("loadSlave", txDev1:getTxQueue(0), txDev1, srcIP1, dstIP1)
    mg.startTask("loadSlave", txDev1:getTxQueue(1), txDev1, srcIP1, dstIP1)
    mg.startTask("loadSlave", txDev2:getTxQueue(0), txDev2, srcIP2, dstIP2)
    mg.startTask("loadSlave", txDev2:getTxQueue(1), txDev2, srcIP2, dstIP2)
    mg.waitForTasks()
end


function loadSlave(queue, txDev, src_ip, dst_ip)
    local mem = memory.createMemPool(4096, function(buf)
        buf:getUdpPacket():fill{
            ethSrc = txDev,
            ethDst = DST_MAC,
            ip4Src = src_ip,
            ip4Dst = dst_ip,
            udpSrc = SRC_PORT,
            udpDst = DST_PORT,
            pktLength = PKT_SIZE
        }
    end)
    
    local bufs = mem:bufArray()

    while mg.running() do
        bufs:alloc(PKT_SIZE)
        queue:send(bufs)
    end
end

