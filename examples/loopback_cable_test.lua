local mg      = require "moongen"
local memory  = require "memory"
local device  = require "device"
local stats   = require "stats"
local log     = require "log"

local DST_MAC  = "aa:bb:cc:dd:ee:ff"
local SRC_PORT  = 36666
local DST_PORT  = 6666
local PKT_SIZE  = 60

function master(txPort, srcIP, rxPort, dstIP)
    if not txPort or not srcIP or not rxPort or not dstIP then
        return print("usage: txPort srcIP rxPort dstIP")
    end

    local txDev = device.config{port = txPort, txQueues = 1, disableOffloads = true}
    local rxDev = device.config{port = rxPort, rxQueues = 1, disableOffloads = true}
    device.waitForLinks()

    stats.startStatsTask{txDevices = {txDev}, rxDevices = {rxDev}}
    
    mg.startTask("loadSlave", txDev:getTxQueue(0), txDev, srcIP, dstIP)
    mg.startTask("receiveSlave", rxDev:getRxQueue(0))
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


function receiveSlave(rxQueue)
    local mempool = memory.createMemPool()
    local rxBufs = mempool:bufArray()

    while mg.running() do
        local rx = rxQueue:tryRecv(rxBufs, 4096)
        rxBufs:freeAll()
    end
end

