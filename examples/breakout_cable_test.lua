local lm      = require "libmoon"
local mg      = require "moongen"
local memory  = require "memory"
local device  = require "device"
local stats   = require "stats"
local log     = require "log"
local timer   = require "timer"

local DST_MAC  = "aa:bb:cc:dd:ee:ff"
local SRC_PORT  = 36666
local DST_PORT  = 6666
local PKT_SIZE  = 125   -- 60 for 10 Gbps saturation; 125 for 25 Gbps saturation

local TIME_PER_TEST = 5   -- in seconds

-- the following lookup should be set as per the cabling and routing rules in Tofino
-- (1) Dry run MoonGen to see the MAC addresses for the devices (ports)
-- (2) Check routing rules to see dstIP for the corresponding MAC addresses
DEV_IP_LOOKUP = {[0] = "71.1.1.2", [1] = "72.1.1.2", [2] = "81.1.1.2", [3] = "82.1.1.2"}

function master(txPort, rxPort)
    if not txPort or not rxPort then
        return print("usage: txPort rxPort")
    end

    local txDev = device.config{port = txPort, txQueues = 1, disableOffloads = true}
    local rxDev = device.config{port = rxPort, rxQueues = 1, disableOffloads = true}
    device.waitForLinks()

    stats.startStatsTask{txDevices = {txDev}, rxDevices = {rxDev}}

    local srcIP = DEV_IP_LOOKUP[txPort]
    local dstIP = DEV_IP_LOOKUP[rxPort]
    
    printf("START of the test: %s (dev: %d) --> %s (dev: %d)", srcIP, txPort, dstIP, rxPort)
    mg.startTask("loadSlave", txDev:getTxQueue(0), txDev, srcIP, dstIP)
    mg.startTask("receiveSlave", rxDev:getRxQueue(0))
    lm.sleepMillisIdle((TIME_PER_TEST + 1) * 1000)
    printf("END of the test: %s --> %s", srcIP, dstIP)

    -- mg.waitForTasks()

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

    local send_timer = timer:new(TIME_PER_TEST)
    while send_timer:running() do
        bufs:alloc(PKT_SIZE)
        queue:send(bufs)
    end
end


function receiveSlave(rxQueue)
    local mempool = memory.createMemPool()
    local rxBufs = mempool:bufArray()

    local recv_timer = timer:new(TIME_PER_TEST)
    while recv_timer:running() do
        local rx = rxQueue:tryRecv(rxBufs, 4096)
        rxBufs:freeAll()
    end
end

