local BAUDRATE_4800 = 206 --208uS = 4800  baud
local BAUDRATE_9600 = 103 --104uS = 9600  baud
local BAUDRATE_19200 = 51 --52uS  = 19200 baud

local BIT_TIME        = BAUDRATE_9600
local STARTBIT_TIME   = BIT_TIME - BIT_TIME/10
local STOPBIT_TIME    = BIT_TIME + BIT_TIME

local TxArray         = {}
local TxBusy          = false

local mode, output = gpio.mode, gpio.OUTPUT
local setcpufreq = node.setcpufreq

TESTPIN = 1
mode(TESTPIN, output)

function SerialSendDone()
    return TxBusy == false
end

function SerialOutDone() 
    TxBusy = false
    setcpufreq(node.CPU80MHZ) -- Done with uart data, slow down
end

function uart_tx_bit_bang_array(pinumber,number)
    local write, serout = gpio.write, gpio.serout
    local isclear, isset, rshift = bit.isclear, bit.isset, bit.rshift
    local tx_times = {}
    local Expect_0 = true
    local TimePos  = 1
    TxBusy         = true
    
    for i=1,number do                       -- Every character:startbit,8*databit,stopbit
        tx_times[TimePos] = STARTBIT_TIME   -- Startbit
        Expect_0 = true
        val = TxArray[i]
        for j=1,8 do                        -- 8 bits
            if Expect_0 then
                if isclear(val, 0) then 
                    tx_times[TimePos] = tx_times[TimePos] + BIT_TIME
                else
                    TimePos = TimePos + 1             
                    tx_times[TimePos] = BIT_TIME
                    Expect_0 = false
                end
            else
                if isset(val, 0) then 
                    tx_times[TimePos] = tx_times[TimePos] + BIT_TIME
                else             
                    TimePos = TimePos + 1             
                    tx_times[TimePos] = BIT_TIME
                    Expect_0 = true              
                end
            end
            val = rshift(val, 1)
        end
        
        if Expect_0 then                    -- Stopbit
            TimePos = TimePos + 1             
            tx_times[TimePos] = STOPBIT_TIME 
        else
            tx_times[TimePos] = tx_times[TimePos] + STOPBIT_TIME
        end
        TimePos = TimePos + 1
    end
    
    serout(pinumber,0,tx_times,1,SerialOutDone)      
end

function SendStringToSoftUart(pinumber,TxStringIn)
    local length = string.len(TxStringIn)
    for i=1,length do
        TxArray[i] = TxStringIn:byte(i)
    end
    setcpufreq(node.CPU160MHZ)  
    uart_tx_bit_bang_array(pinumber,length)
end

function SendDataToSoftUart(pinumber,TxArrayIn,Number)
    for i=1,Number do
        TxArray[i] = TxArrayIn[i]
    end 
    setcpufreq(node.CPU160MHZ)
    uart_tx_bit_bang_array(pinumber,Number)
end
