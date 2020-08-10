DEBUGPORT = 1

TX0_PIN = 10 --(GPIO 1)
RX0_PIN =  9 --(GPIO 3)

dofile("SoladinCommunication.lc")
--dofile("SaveLog.lc")
dofile("ExtractTime.lc")

-- Constants
SSID    = ""
APPWD   = ""

-- Some control variables
wifiTrys    = 0      -- Counter of trys to connect to wifi
NUMWIFITRYS = 50    -- Maximum number of WIFI Testings while waiting for connection

NUMSENDRETRIES = 1

NumberOfFails = 0
SendRetry     = NUMSENDRETRIES

DataTypeMem = 0
ValueMem    = 0

-- testdisconnect = 0

cfg =
{
  ip="192.168.178.15",  --"192.168.2.99",
  netmask="255.255.255.0",
--  gateway="192.168.0.1"
}

function GetGoogleTime()
    local SerialWrite = uart.write
    connection=net.createConnection(net.TCP, 0)
    tmr.alarm( 0 , 2000 , 0 , FailSend)
    NumberOfFails = 10
    connection:connect(80,'google.nl')
    connection:on("connection",function(conn, payload)  -- Event handler
            SerialWrite(DEBUGPORT, "Get time\n")
            connection:send("HEAD / HTTP/1.1\r\nHost: google.com\r\n\r\n")
            end)
            
    connection:on("receive", function(conn, payload) -- Event handler
--    SerialWrite(DEBUGPORT, payload)
--    print('Time '..string.sub(payload,string.find(payload,"Date: ")
--           +6,string.find(payload,"Date: ")+35))
    Year,Month,MonthDay,Hour,Min,Sec = ExtractTimeData(payload)
    SerialWrite(DEBUGPORT, string.format("%02d-%s-%04d %02d:%02d:%02d\n",Day,Month,Year,Hour,Min,Sec))
    connection:close()

    tmr.stop(0)
    tmr.stop(1)
    StartCommunication() -- Time is known, now startup the Soladin communication
    end) 
end

function FailSend()
    local SerialWrite = uart.write
    SerialWrite(DEBUGPORT, "FailSend(): " .. NumberOfFails .. ", Retry = " .. SendRetry .. "\n")
    NumberOfFails = NumberOfFails + 1
    if NumberOfFails > 10 then
        tmr.alarm( 0 , 200 , 0 , DoRestart)
    else
        if SendRetry > 0 then
            SerialWrite(DEBUGPORT, "sendData retry!!!\n")
            SendRetry = SendRetry - 1
            sendData(DataTypeMem, ValueMem) -- Resend
        else
            SendRetry = NUMSENDRETRIES
        end     
    end
--    node.dsleep(SLEEPSHORT_TIME)
end

function DoRestart()
    tmr.stop(0)
    tmr.stop(1)
    tmr.stop(3)
    node.restart()
end

function sendData(DataType, Value)
    local SerialWrite = uart.write
    
    DataTypeMem = DataType
    ValueMem    = Value
    
    DoClose = false
    DataSendCorrectly = false

    OnlyTrace = false
    SerialWrite(DEBUGPORT, "sendData(" .. DataType .. "," .. Value .. ")\n")
    SerialWrite(DEBUGPORT, "PVVoltage[1]: " .. PVVoltage[1] .. ",PVVoltage[2]: " .. PVVoltage[2] .. "\n")
    SerialWrite(DEBUGPORT, "TotalPower[1]: " .. TotalPower[1] / 100 .. ",TotalPower[2]: " .. TotalPower[2] / 100 .. "\n")

    if OnlyTrace == true then
        return
    end
    
    ipAddr = wifi.sta.getip()
    if ( ( ipAddr == nil ) or ( ipAddr == "0.0.0.0" ) ) then
        SerialWrite(DEBUGPORT, "No ipnumber restart!\n")
        tmr.alarm( 0 , 200 , 0 , DoRestart)
        return
    end    

--testdisconnect = testdisconnect + 1
--print("testdisconnect = " .. testdisconnect)
--if testdisconnect == 5 then
--    print("disconnect the WiFi for test")
--    wifi.sta.disconnect(function() print("WiFi disconnected...") end)
--end
         
    conn=net.createConnection(net.TCP, 0)   
    tmr.alarm( 0 , 3000 , 0 , FailSend)
    StartTimer = tmr.now()         

    if DataType == 2 then
        -- Total Day logging
        NumberOfFails = 10
        conn:connect(80,'trudolphi.nl')
        conn:on("connection",function(conn, payload) -- Event handler
            SerialWrite(DEBUGPORT, "Connected\n")
            conn:send("POST ?????.php?value="..Value.."&mode=1 HTTP/1.1\r\nHost: www.trudolphi.nl\r\n\r\n")
            end)
            
        conn:on("sent", function(conn) 
                SerialWrite(DEBUGPORT, "Values send to trudolphi.nl\n")
                NumberOfFails = 0 
                DataSendCorrectly = true 
            end)  
                         
        conn:on("receive", function(conn, payload) -- Event handler
--          SerialWrite(DEBUGPORT,payload)
            if ( string.find(payload,"200 OK") ~= nil ) then
                SerialWrite(DEBUGPORT, "Rec: Good response(1)\n") 
                SendRetry = NUMSENDRETRIES
                tmr.stop(0)     
            else
                SerialWrite(DEBUGPORT, "Rec: Bad response(1)\n")  -- data will be resend once
            end
            SerialWrite(DEBUGPORT, "Close(1)\n")
            conn:close()
            end) 

        conn:on("reconnection", function(conn) SerialWrite(DEBUGPORT, "reconnection") end)
        conn:on("disconnection", function(conn) 
            tmr.stop(0)
            if DataSendCorrectly == false then
                SerialWrite(DEBUGPORT, "!!No Done received!!\n")
            else
                SerialWrite(DEBUGPORT, "Disconnected\n")
            end
        end)    
    else 
        conn:connect(80,'184.106.153.149') -- api.thingspeak.com 184.106.153.149
        
        conn:on("connection", function(conn)
            -- Connection made, now send the data 
            SerialWrite(DEBUGPORT, "Connected\n")
           
            if DataType == 0 then 
                -- 20 seconds logging
                conn:send("GET /update?key=????????????????&field1="..PVVoltage[1] ..
                                                          "&field2="..PVVoltage[2] ..  
                                                          "&field3="..string.format("%01d.%02d",PVCurrent[1]/1000,(PVCurrent[1]%1000)/10) ..
                                                          "&field4="..string.format("%01d.%02d",PVCurrent[2]/1000,(PVCurrent[2]%1000)/10) ..
                                                          "&field5="..GridPower[1] ..
                                                          "&field6="..GridPower[2] ..
                                                          "&field7="..GridPower[1] + GridPower[2] ..
                                                          "&field8="..0 ..                                    
                                                          " HTTP/1.1\r\nHost: api.thingspeak.com\r\n\r\n")             
            elseif DataType == 1 then
                -- 5 minutes logging
                heap_memory = node.heap()
                conn:send("GET /update?key=????????????????&field1="..Value ..  -- Mean power over 5 minutes
                                                          "&field2="..TotalWattCumulative / 12 ..  
                                                          "&field3="..TotalPower[1] / 100 .. -- kWh
                                                          "&field4="..TotalPower[2] / 100 ..
                                                          "&field5="..MainsVoltage ..                                 
                                                          "&field6="..heap_memory ..                                 
                                                          "&field7="..Temperature[1] ..
                                                          "&field8="..Temperature[2] ..    
                                                          " HTTP/1.1\r\nHost: api.thingspeak.com\r\n\r\n")             
            elseif DataType == 3 then
                -- Soladin internal hystory
                conn:send("GET /update?key=????????????????&field1="..HystoricalPower[1]*10 ..
                                                          "&field2="..HystoricalPower[2]*10 ..  
                                                          "&field3="..HystoricalPower[3]*10 ..
                                                          "&field4="..HystoricalPower[4]*10 ..
                                                          "&field5="..HystoricalPower[5]*10 ..                                 
                                                          "&field6="..HystoricalPower[6]*10 ..                                 
                                                          "&field7="..HystoricalPower[7]*10 ..                                 
                                                          "&field8="..HystoricalPower[8]*10 ..                                 
                                                          " HTTP/1.1\r\nHost: api.thingspeak.com\r\n\r\n")             
            elseif DataType == 2 then -- not used
                -- Total Day logging
                conn:send("GET /update?key=????????????????&field1="..Value.." HTTP/1.1\r\nHost: api.thingspeak.com\r\n\r\n")
            else
                SerialWrite(DEBUGPORT, "wrong DataType\n")            
            end
        end)
    
        conn:on("sent", function(conn)
                    SerialWrite(DEBUGPORT, "Values send to Thingspeak.\n") 
                    NumberOfFails = 0 
                    DataSendCorrectly = true 
                    if DoClose == true then
                        conn:close()
                        SerialWrite(DEBUGPORT, "Close(2)\n")
                    else
                        DoClose = true
                    end
                end)

        conn:on("receive", function(conn, payload) -- Event handler
--    SerialWrite(DEBUGPORT, payload)
--    print('Time '..string.sub(payload,string.find(payload,"Date: ")
--           +6,string.find(payload,"Date: ")+35))
            Year,Month,MonthDay,Hour,Min,Sec = ExtractTimeData(payload)
            SerialWrite(DEBUGPORT, string.format("%02d-%s-%04d %02d:%02d:%02d\n",Day,Month,Year,Hour,Min,Sec)) 
            if ( string.find(payload,"200 OK") ~= nil ) then
                SerialWrite(DEBUGPORT, "Rec: Good response\n")      
                if ( string.find(payload,"\r\n\r\n") ~= nil ) then
                    startpos = string.find(payload,"\r\n\r\n") + 4
                    ResponseNumber = tonumber(string.sub(payload, startpos, startpos+20))
                    SerialWrite(DEBUGPORT, "Response: " .. ResponseNumber .. "\n")
                end
                SendRetry = NUMSENDRETRIES
                tmr.stop(0)
            else
                SerialWrite(DEBUGPORT, "Rec: Bad response:\n") -- data will be resend once
                --SerialWrite(DEBUGPORT, payload)
                --SerialWrite(DEBUGPORT, "  >> End of payload <<\n")
            end
            SerialWrite(DEBUGPORT, "Time to send = " .. (tmr.now() - StartTimer)/1000 .. " ms\n")
            DataSendCorrectly = true
            if DoClose == true then
                conn:close()
                SerialWrite(DEBUGPORT, "Close(3)\n")
            else
                DoClose = true
            end
          end) 

        conn:on("reconnection", function(conn) SerialWrite(DEBUGPORT, "reconnection\n") end)
        conn:on("disconnection", function(conn) 
            tmr.stop(0)
            if DataSendCorrectly == false then
                SerialWrite(DEBUGPORT, "!!No Done received!!\n")
            else
                SerialWrite(DEBUGPORT, "Disconnected\n")
            end
        end)

        
    end    
end

function checkWIFI()
  local SerialWrite = uart.write 
  if ( wifiTrys > NUMWIFITRYS ) then
    SerialWrite(DEBUGPORT, "Sorry. Not able to connect, restart after 1 minute to try again\n")
    tmr.alarm( 0 , 60000 , 0 , DoRestart) -- Wait 1 minute to do a restart 
  else
    ipAddr = wifi.sta.getip()
    if ( ( ipAddr ~= nil ) and ( ipAddr ~= "0.0.0.0" ) )then
      SerialWrite(DEBUGPORT, "WIFI IP Address: " .. wifi.sta.getip() .. "\n")
      gpio.write(LED_PIN,0)
      GetGoogleTime()
    else
      tmr.alarm( 0 , 500 , 0 , checkWIFI)
      SerialWrite(DEBUGPORT, "Checking WIFI..." .. wifiTrys .. "\n")
      wifiTrys = wifiTrys + 1
      gpio.write(LED_PIN,(wifiTrys) % 2) 
    end 
  end 
end


uart.setup(0,9600,8,0,1,0)
uart.alt(1) -- Uart0 on pins D7,8 (Rx/Tx) (let op nu geen communicatie meer met de ESplorer)

gpio.mode(RX0_PIN, gpio.INPUT)
gpio.mode(TX0_PIN, gpio.INPUT)

uart.setup(1, 115200, 8, uart.PARITY_NONE, uart.STOPBITS_1, 0) -- Debug port
-- uart.alt(1) ==>> Uart 0 is on the pins D7/D8 
-- TX1 connected to TX0 ==>> the debugdata is going to the Wemos USB to serial converter

local SerialWrite = uart.write

--node.restore() -- When WiFi is unable to connect
--node.restart() -- ensure the restored settings take effect

ipAddr = wifi.sta.getip()

if ( ( ipAddr == nil ) or ( ipAddr == "0.0.0.0" ) ) then
    -- We aren't connected, so let's connect
    SerialWrite(DEBUGPORT, "Configuring WIFI...." .. "\n")
    --wifi.sta.setip(cfg)
    SerialWrite(DEBUGPORT, "wifi.getmode(): " .. wifi.getmode() .. "\n")  

    if ( wifi.getmode() ~= wifi.STATION ) then
        SerialWrite(DEBUGPORT, "wifi.setmode( wifi.STATION )")
        wifi.setmode( wifi.STATION )
        --connect to Access Point (DO save config to flash)
        station_cfg={}
        station_cfg.ssid=SSID
        station_cfg.pwd=APPWD
        station_cfg.save=true
        wifi.sta.config(station_cfg)
    end
    --  wifi.sta.eventMonReg(wifi.STA_CONNECTING, function() print("STATION_CONNECTING") end)
    --  wifi.sta.eventMonReg(wifi.STA_GOTIP, 
    --  function() 
    --    print("STATION_GOT_IP") 
        --ipAddr = wifi.sta.getip()
        --if ( ( ipAddr ~= nil ) and  ( ipAddr ~= "0.0.0.0" ) )then
        --  print("IP:" .. ipAddr)
        --  tmr.alarm( 0 , 5 , 0 , DoTemp )
        --end  
    --  end)
    --  wifi.sta.eventMonStart()
end

SerialWrite(DEBUGPORT, "Waiting for connection....\n")
checkWIFI()

