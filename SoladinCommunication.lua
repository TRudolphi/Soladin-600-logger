dofile("SoftSerial.lc")

SOLADIN_HYSTORICAL_DATA = tonumber("9A",16)
SOLADIN_READ_VERSION    = tonumber("B4",16)
SOLADIN_READ_DATA       = tonumber("B6",16)
--SOLADIN_READ_MAX        = tonumber("B9",16)
SOLADIN_INIT            = tonumber("C1",16)

INIT            = 0 -- bitposition 0               
READVERSION     = 1
READDATA        = 2
READHYSTORICAL  = 3

--SERVERACTIVE    = 4

TX_PIN1 = 5
gpio.write(TX_PIN1,1)
gpio.mode(TX_PIN1, gpio.OUTPUT)

TX_PIN2 = 6
gpio.write(TX_PIN2,1)
gpio.mode(TX_PIN2, gpio.OUTPUT)

RX_PIN  = 7
gpio.mode(RX_PIN, gpio.INPUT, gpio.PULLUP)

LED_PIN = 3
gpio.mode(LED_PIN, gpio.OUTPUT)

RS232_pointer = 0 
RS232_buffer  = {} 

for i=0, 34 do
    RS232_buffer[i] = 0
end

--[[
RS232_buffer[2]  = tonumber("11",16)
RS232_buffer[4]  = tonumber("B6",16)
RS232_buffer[5]  = tonumber("F3",16)
RS232_buffer[8]  = tonumber("04",16)
RS232_buffer[9]  = tonumber("03",16)
RS232_buffer[10] = tonumber("35",16)
RS232_buffer[12] = tonumber("8A",16)
RS232_buffer[13] = tonumber("13",16)
RS232_buffer[14] = tonumber("F4",16)
RS232_buffer[18] = tonumber("24",16)
RS232_buffer[20] = tonumber("90",16)
RS232_buffer[21] = tonumber("0B",16)
RS232_buffer[23] = tonumber("1F",16)
RS232_buffer[24] = tonumber("DB",16)
RS232_buffer[25] = tonumber("BC",16)
RS232_buffer[26] = tonumber("01",16)
RS232_buffer[30] = tonumber("FD",16)

 00 00 11 00 B6 F3 00 00 04 03 35 00 8A 13 F4
 00 00 00 24 00 90 0B 00 1F DB BC 01 00 00 00 FD       
--]]

ReceiveData    = 0 
ReceiveTimeOut = 0

Soladin1Present = false
Soladin2Present = false
SendSoladinZeroVals = 5 -- When soladins stops communicating, set voltage to 0 and this x time to Thingspeak

-- Flags          = {0,0}
PVVoltage      = {0,0}
PVCurrent      = {0,0}
--MainsFrequency = 0
MainsVoltage   = 228
GridPower      = {0,0}
TotalPower     = {0,0}
Temperature    = {20,20}

MeanPower      = {0,0}        
Samples        = 0
TotalWattCumulative = 0
DoSaveFile     = false
DoSample       = false
DoSaveTotal    = false
DoSendData     = false
TriggerSendMeanData = false
DoSendMeanData = false
SendZeroMean   = 0

HystoricalPower = {0,0,0,0,0,0,0,0,0,0} -- 10 days

HystoricalPowerSoladin1 = 0
HystoricalPowerSoladin2 = 0
--HystoricalPower         = 0

--[[OperatingTime  = {0,0}

SoladinVersions = {}
 for i=0,2 do
  SoladinVersions[i] = {}     -- create a new row
   for j=0,2 do
    SoladinVersions[i][j] = 0
   end
  end
--]]

HystoricalDay   = 1

NoCommCounter1  = 5
NoCommCounter2  = 5

LoggerState     = 0
DoSoladin       = 0

DayHystoricalSend = 0
Day             = 100
Hour            = 0
Min             = 4
Sec             = 30
SecondPrescaler = 0

crc = 0
i = 0  

function HandleResponce(NumberOfBytes)
    local SerialWrite = uart.write    
    if NumberOfBytes == 0 then
        SerialWrite(DEBUGPORT, "No data..\n")
        if ReceiveData == 1 then
            if NoCommCounter1 > 0 then
                NoCommCounter1 = NoCommCounter1 - 1
                if NoCommCounter1 == 0 then
                    PVVoltage[ReceiveData] = 0
                    PVCurrent[ReceiveData] = 0
                    GridPower[ReceiveData] = 0
                    Soladin1Present        = false
                end
            end
        else
            if NoCommCounter2 > 0 then
                NoCommCounter2 = NoCommCounter2 - 1
                if NoCommCounter2 == 0 then
                    PVVoltage[ReceiveData] = 0
                    PVCurrent[ReceiveData] = 0
                    GridPower[ReceiveData] = 0
                    Soladin2Present        = false
                end
            end
        end
    else
        crc = 0
        SerialWrite(DEBUGPORT, "Soladin " .. ReceiveData .. " Rec: " )
        for i=0, NumberOfBytes - 2 do
            crc = crc + RS232_buffer[i]
            SerialWrite(DEBUGPORT, string.format("%02X.",RS232_buffer[i]))
        end
        SerialWrite(DEBUGPORT, string.format("%02X\n",RS232_buffer[NumberOfBytes - 1]))
        if crc%256 ~= RS232_buffer[NumberOfBytes - 1] then
            SerialWrite(DEBUGPORT, "Wrong CRC\n")
            return 1
        end    

        SendSoladinZeroVals = 5
        if ReceiveData == 1 then
            NoCommCounter1 = 5 
        else
            NoCommCounter2 = 5 
        end
  
        if RS232_buffer[4] == SOLADIN_HYSTORICAL_DATA then 
            if ReceiveData == 1 then
                Soladin1Present = true 
                HystoricalPowerSoladin1 = RS232_buffer[7] -- kWh * 100
                HystoricalPowerSoladin1 = bit.lshift(HystoricalPowerSoladin1, 8)
                HystoricalPowerSoladin1 = HystoricalPowerSoladin1 + RS232_buffer[6]
            else
                Soladin2Present = true 
                HystoricalPower[HystoricalDay] = RS232_buffer[7] -- kWh * 100
                HystoricalPower[HystoricalDay] = bit.lshift(HystoricalPower[HystoricalDay], 8)
                HystoricalPower[HystoricalDay] = HystoricalPower[HystoricalDay] + RS232_buffer[6]
                HystoricalPower[HystoricalDay] = HystoricalPower[HystoricalDay] + HystoricalPowerSoladin1
--                SerialWrite(DEBUGPORT, HystoricalPower[HystoricalDay] * 10 .. "\n")
--                SerialWrite(DEBUGPORT, TotalWattCumulative / 12 .. "\n")
--                HystoricalPowerSoladin2 = RS232_buffer[7] -- kWh * 100
--                HystoricalPowerSoladin2 = bit.lshift(HystoricalPowerSoladin2, 8)
--                HystoricalPowerSoladin2 = HystoricalPowerSoladin2 + RS232_buffer[6]
                
--                HystoricalPower = HystoricalPowerSoladin1 + HystoricalPowerSoladin2
--                SerialWrite(DEBUGPORT, HystoricalPower * 10 .. "\n")                
                if (HystoricalDay == 1) and (TotalWattCumulative / 120 < HystoricalPower[HystoricalDay]) then
                    TotalWattCumulative = HystoricalPower[HystoricalDay] * 120
                end
--                SerialWrite(DEBUGPORT, TotalWattCumulative / 12 .. '  ' .. HystoricalPower[1] * 10 .. "\n")  
            end
        end
          
        if RS232_buffer[4] == SOLADIN_READ_VERSION then
            if ReceiveData == 1 then
                Soladin1Present = true 
            else
                Soladin2Present = true 
            end
--            SoladinVersions[ReceiveData][0] = RS232_buffer[16] 
--            SoladinVersions[ReceiveData][1] = RS232_buffer[15] 
        end  
          
        if RS232_buffer[4] == SOLADIN_READ_DATA then 
            if ReceiveData == 1 then
                Soladin1Present = true 
            else
                Soladin2Present = true 
            end
--            Flags[ReceiveData]        = RS232_buffer[7]
--            Flags[ReceiveData]        = bit.lshift(Flags[ReceiveData-1], 8)
--            Flags[ReceiveData]        = Flags[ReceiveData-1] + RS232_buffer[6]  
                   
            PVVoltage[ReceiveData]    = RS232_buffer[9]
            PVVoltage[ReceiveData]    = bit.lshift(PVVoltage[ReceiveData],8)
            PVVoltage[ReceiveData]    = PVVoltage[ReceiveData] + RS232_buffer[8]   -- is Volt * 10  
            PVVoltage[ReceiveData]    = PVVoltage[ReceiveData] + 5
            PVVoltage[ReceiveData]    = PVVoltage[ReceiveData] / 10                -- In volt
          
            PVCurrent[ReceiveData]    = RS232_buffer[11]
            PVCurrent[ReceiveData]    = bit.lshift(PVCurrent[ReceiveData],8)
            PVCurrent[ReceiveData]    = PVCurrent[ReceiveData] + RS232_buffer[10]   -- In mA / 10
            PVCurrent[ReceiveData]    = PVCurrent[ReceiveData] * 10                 -- In mA
          
--            MainsFrequency              = RS232_buffer[13]
--            MainsFrequency              = bit.lshift(MainsFrequency, 8)
--            MainsFrequency              = MainsFrequency + RS232_buffer[12]   -- In Herz * 100
                 
            MainsVoltage              = RS232_buffer[15]
            MainsVoltage              = bit.lshift(MainsVoltage, 8)
            MainsVoltage              = MainsVoltage + RS232_buffer[14]   -- In Volt
--print(MainsVoltage)
            GridPower[ReceiveData]    = RS232_buffer[19]
            GridPower[ReceiveData]    = bit.lshift(GridPower[ReceiveData], 8 )
            GridPower[ReceiveData]    = GridPower[ReceiveData] + RS232_buffer[18]   -- In Watt
--print(GridPower[ReceiveData])          
            TotalPower[ReceiveData]   = RS232_buffer[22]
            TotalPower[ReceiveData]   = bit.lshift(TotalPower[ReceiveData], 8)
            TotalPower[ReceiveData]   = TotalPower[ReceiveData] + RS232_buffer[21]  
            TotalPower[ReceiveData]   = bit.lshift(TotalPower[ReceiveData], 8)
            TotalPower[ReceiveData]   = TotalPower[ReceiveData] + RS232_buffer[20]   -- In KW * 100
          
            Temperature[ReceiveData]  = RS232_buffer[23]   -- In graden Celcius
--[[          
            OperatingTime[ReceiveData]   = RS232_buffer[27]
            OperatingTime[ReceiveData] <<= 8
            OperatingTime[ReceiveData]  += RS232_buffer[26]  
            OperatingTime[ReceiveData] <<= 8
            OperatingTime[ReceiveData]  += RS232_buffer[25]  
            OperatingTime[ReceiveData] <<= 8
            OperatingTime[ReceiveData]  += RS232_buffer[24]   -- In Minutes
--]]
        end  
          
--    case SOLADIN_READ_MAX: 
--          break;
          
        if RS232_buffer[4] == SOLADIN_INIT then 
            SerialWrite(DEBUGPORT, "SOLADIN_INIT\n")
            if ReceiveData == 1 then
                Soladin1Present = true 
            else
                Soladin2Present = true 
            end
        end
  end
end

function Soladin600Commands(RS232Channel, command, commanddata)
    local SendData = {0,0,0,0,0,0,0,0,0,0}  
     
    gpio.write(LED_PIN,1)      
    if command == SOLADIN_INIT then
        SendData[1] = 0
        if RS232Channel == 1 then
            Soladin1Present = false         
        else
            Soladin2Present = false   
        end
    else
        SendData[1] = 0x11
    end  

    crc = (SendData[1] + command + commanddata) % 256
    SendData[5] = command
    SendData[6] = commanddata
    SendData[9] = crc
    if RS232Channel == 1 then
        SendDataToSoftUart(TX_PIN2,SendData,9)         
    else
        SendDataToSoftUart(TX_PIN1,SendData,9)  
    end
    
    RS232_pointer  = 0  
    ReceiveData    = RS232Channel -- 1 or 2
    ReceiveTimeOut = 15 -- 150 ms to receive the message (praktijk is ong 70ms)  
    
    uart.on("data", 1, ReceiveRS232Data, 0) -- event at every char, not to LUA
end

function ReceiveRS232Data(data) -- After max 150ms data available
    if ReceiveData > 0 then
        -- Communicating with the Soladins
        RS232_buffer[RS232_pointer] = tonumber(string.byte(data))
        RS232_pointer = RS232_pointer + 1
    end
end

function DoSoladinInit()
    DoSoladin = bit.set(DoSoladin, INIT)
end

function DoSoladinReadData()
    DoSoladin = bit.set(DoSoladin, READDATA)
end

function DoSoladinHystorical()
    DoSoladin = bit.set(DoSoladin, READHYSTORICAL)
    HystoricalDay = 1
    HystoricalPowerSoladin1 = 0
end

function Clock()
    if Sec == 59 then
        Sec = 0
        if Min == 59 then
            Min = 0
            if Hour == 23 then
                Hour = 0
            else
                Hour = Hour + 1    
            end
        else
            Min = Min + 1
        end    
    else
        Sec = Sec + 1
    end        
end

function Timer10ms()
    local SerialWrite = uart.write
    local isset = bit.isset
    local clear = bit.clear
    
    if SecondPrescaler > 0 then
        SecondPrescaler = SecondPrescaler - 1;
    else
        SecondPrescaler = 99
        Clock()
        if Hour > 4 then
            if Sec%20 == 0 then
                -- Every 20 seconds take a sample
                if DoSample == true then
                    DoSample = false
                    
                    DoSoladinReadData()
                    
                    DoSendData = true

                end     
            else
                DoSample = true   
                
                if (Soladin1Present == true) and (Soladin2Present == true) then
                    if ((Min % 5) == 0) and (Sec == 10) then 
                        -- Every 5 minutes send the mean values.  
                        if TriggerSendMeanData == true then
                            TriggerSendMeanData = false
                            DoSendMeanData = true
                        end    
                    else
                        TriggerSendMeanData = true
                        if (Sec == 8) and (DayHystoricalSend ~= Day) then 
                            DoSoladinHystorical() -- Check the hystorical data of the soladins
                        end            
                    end
                end
                    
                if Hour == 22 and Min == 47 then
                    if isset(DoSoladin, 4) and DoSaveTotal == true then
                        sendData(2, TotalWattCumulative / 12)
                        TotalWattCumulative = 0
                        DoSaveTotal = false
                    end    
                else
                    DoSaveTotal = true
                end         
            end
        end                                         
    end

    if ReceiveTimeOut > 0 then
        ReceiveTimeOut = ReceiveTimeOut - 1;
    end
    if (ReceiveData > 0) and (ReceiveTimeOut == 1) then -- only once
        if ReceiveData == 2 then
            uart.on("data") -- Uart for LUA again
        end
        HandleResponce(RS232_pointer)    
        ReceiveData = 0
        gpio.write(LED_PIN,0)
    end

   if     LoggerState == 0 then 
            DoSoladinInit() -- READVERSION
            ReceiveTimeOut = 100    -- 1 sec delay
            LoggerState = 1            

   elseif LoggerState == 1 then 
            if ReceiveTimeOut == 0 then             
                if isset(DoSoladin, INIT) then 
                    Soladin1Present = false
                    Soladin600Commands(1, SOLADIN_INIT, 0)           -- Soladin 1
                    LoggerState = LoggerState + 1;
                elseif isset(DoSoladin, READVERSION) then
                    Soladin600Commands(1, SOLADIN_READ_VERSION, 0)   -- Soladin 1
                    LoggerState = LoggerState + 1;
                elseif isset(DoSoladin, READDATA) then
                    Soladin600Commands(1, SOLADIN_READ_DATA, 0)      -- Soladin 1
                    LoggerState = LoggerState + 1;
                elseif isset(DoSoladin, READHYSTORICAL) then
                    Soladin600Commands(1, SOLADIN_HYSTORICAL_DATA, HystoricalDay - 1);-- Soladin 1
                    Soladin1Present = false
                    LoggerState = LoggerState + 1;
                elseif DoSendData == true then
                    DoSendData = false

                    if Samples == 0 then
                        MeanPower[1] = GridPower[1]
                        MeanPower[2] = GridPower[2]
                    else
                        MeanPower[1] = MeanPower[1] + GridPower[1]
                        MeanPower[2] = MeanPower[2] + GridPower[2]        
                    end
                    Samples = Samples + 1

                    if (Soladin1Present == true) and (Soladin2Present == true) then
                        sendData(0,0)
                    end
                    if ( SendSoladinZeroVals > 0) and 
                       (Soladin1Present == false) and 
                       (Soladin2Present == false) then
                        -- Send only once the 0 values to thinkspeak
                        SendSoladinZeroVals = SendSoladinZeroVals - 1
                        sendData(0,0)
                    end
                    
                elseif DoSendMeanData == true then

                    DoSendMeanData = false  
                    
                    MeanPower[1]  = MeanPower[1] / Samples
                    MeanPower[2]  = MeanPower[2] / Samples
                    TotalWattCumulative = TotalWattCumulative + MeanPower[1] + MeanPower[2]
                           
                    Samples       = 0
                    DoSaveFile    = false
                    if isset(DoSoladin, 4) and (((MeanPower[1] + MeanPower[2]) > 0) or (SendZeroMean > 0)) then
                        sendData(1, MeanPower[1] + MeanPower[2])
                        if(MeanPower[1] + MeanPower[2] > 0) then
                            -- Eventueel hierna x keer de nulwaarde versturen
                            SendZeroMean = 3                         
                        else
                            if SendZeroMean > 0 then
                                SendZeroMean = SendZeroMean - 1
                            end    
                        end
                    end                
                end 
            end

   elseif LoggerState == 2 then 
            if ReceiveTimeOut == 0 then
                LoggerState = 1
                if isset(DoSoladin, INIT) then 
                    DoSoladin = clear(DoSoladin, INIT)
                    Soladin2Present = false
                    Soladin600Commands(2, SOLADIN_INIT, 0)           -- Soladin 2
                elseif isset(DoSoladin, READVERSION) then
                    DoSoladin = clear(DoSoladin, READVERSION)
                    Soladin600Commands(2, SOLADIN_READ_VERSION, 0)   -- Soladin 2
                elseif isset(DoSoladin, READDATA) then
                    DoSoladin = clear(DoSoladin, READDATA)
                    Soladin600Commands(2, SOLADIN_READ_DATA, 0)      -- Soladin 2
                elseif isset(DoSoladin, READHYSTORICAL) then
                    Soladin600Commands(2, SOLADIN_HYSTORICAL_DATA, HystoricalDay - 1);-- Soladin 2
                    Soladin2Present = false
                    LoggerState = 3
                end 
            end
             
   elseif LoggerState == 3 then 
            if ReceiveData == 0 then
                LoggerState = 1
                if isset(DoSoladin,READHYSTORICAL) then 
                    if HystoricalDay < 8 then -- 10 is max, For now 8 days
                        HystoricalDay = HystoricalDay + 1
                    else
                        DoSoladin = bit.clear(DoSoladin, READHYSTORICAL)
                        sendData(3, 0)
                        DayHystoricalSend = Day
                        SerialWrite(DEBUGPORT, string.format("Hystorical data sent on day %02d\n",DayHystoricalSend))
                    end
                end
            end
    end            
end

function StartCommunication()
    if bit.isclear(DoSoladin, 4) then
        tmr.alarm( 3 , 10 , 1 , Timer10ms ) 
        DoSoladin = bit.set(DoSoladin, 4)
    end
end        


--    if(
--    if bit.isclear(DoSoladin, 4) or ((Sec%15 > 1) and (Sec%15 < 14)) then
--        print(PrintString)
--        ReceiveTimeOut = 5
--    end

--
--DEBUGPORT = 1

--TX0_PIN = 10 --(GPIO 1)
--RX0_PIN =  9 --(GPIO 3)

--uart.setup(0,9600,8,0,1,0)
--uart.alt(1) -- Uart0 on pins D7,8 (Rx/Tx) (let op nu geen communicatie meer met de ESplorer)

--gpio.mode(RX0_PIN, gpio.INPUT)
--gpio.mode(TX0_PIN, gpio.INPUT)

--uart.setup(1, 115200, 8, uart.PARITY_NONE, uart.STOPBITS_1, 0) -- Debug port
-- uart.alt(1) ==>> Uart 0 is on the pins D7/D8 
-- TX1 connected to TX0 ==>> the debugdata is going to the Wemos USB to serial converter

--tmr.alarm( 3 , 10 , 1 , Timer10ms ) -- stand alone test

