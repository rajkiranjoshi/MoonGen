local mg      = require "moongen"
local memory  = require "memory"
local device  = require "device"
local ts      = require "timestamping"
local stats   = require "stats"
local hist    = require "histogram"
local log     = require "log"

local PKT_SIZE	= 60
local MAC1  = "3C:FD:FE:B7:E7:F4"
local MAC2  = "3C:FD:FE:B7:E7:F5"
local MAC3  = "3C:FD:FE:B7:E8:E8"
local MAC4  = "3C:FD:FE:B7:E8:E9"
local IP1   = "10.1.1.2"
local IP2   = "20.1.1.2"
local IP3   = "30.1.1.2"
local IP4   = "40.1.1.2"
local SRC_PORT  = 36666
local DST_PORT  = 6666


function master(txPort1, txPort2, txPort3, txPort4, rate)
	if not txPort1 or not txPort2 or not txPort2 or not txPort3 or not txPort4 or not rate then
		return print("usage: txPort1 txPort2 txPort3 txPort4 rate(Gbps)")
	end
	rate = rate or 10
	
	local txDev1 = device.config{port = txPort1, txQueues = 1, disableOffloads = true}
	local txDev2 = device.config{port = txPort2, txQueues = 1, disableOffloads = true}
	local txDev3 = device.config{port = txPort3, txQueues = 1, disableOffloads = true}
	local txDev4 = device.config{port = txPort4, txQueues = 1, disableOffloads = true}
	device.waitForLinks()
	stats.startStatsTask{txDevices = {txDev1,txDev2,txDev3,txDev4}}

	mg.startTask("loadSlave", txDev1:getTxQueue(0), txDev1, rate, IP1, IP2, MAC2)
    mg.startTask("loadSlave", txDev2:getTxQueue(0), txDev2, rate, IP2, IP1, MAC1)
    mg.startTask("loadSlave", txDev3:getTxQueue(0), txDev3, rate, IP3, IP4, MAC4)
    mg.startTask("loadSlave", txDev4:getTxQueue(0), txDev3, rate, IP4, IP3, MAC3)

	mg.waitForTasks()
end


function loadSlave(queue, txDev, rate, srcIP, dstIP, dstMAC)
    local mem = memory.createMemPool(4096, function(buf)
        buf:getUdpPacket():fill{
            ethSrc = txDev,
            ethDst = dstMAC,
            ip4Src = srcIP,
            ip4Dst = dstIP,
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
