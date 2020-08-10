--uart.setup(0,9600,8,0,1,0)
LED_PIN = 3
gpio.mode(LED_PIN, gpio.OUTPUT)
toggle = 0
DelayCounter = 0

function GarbageDelay()
    tmr.alarm(0,1,0,startup)
end

function startup()
    gpio.write(LED_PIN, toggle)
    toggle = (toggle + 1) % 2
    DelayCounter = DelayCounter + 1
    if DelayCounter > 80 then
        print('Start......')
        dofile('SolarServer.lc')
    else
        tmr.alarm(0,100,0,startup)    
    end        
end

print('\n\nStartup delay (10 sec.)')
tmr.alarm(0,2000,0,GarbageDelay)
