
-- string = "dsf sdfsffsd Date: Fri, 24 Aug 2015 16:44:14 GMT"
Months = {"Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"}

function ExtractTimeData(payload)
    if ( string.find(payload,"Date") ~= nil ) then
        local i, j = string.find(payload,"Date")
        startpos = j + 8
        Day = tonumber(string.sub(payload, startpos, startpos+1))
        Month = string.sub(payload, startpos+3, startpos+5)
        for i=1, 12 do
            if Month == Months[i] then
                Month = i
            end    
        end
        Year = tonumber(string.sub(payload, startpos+7, startpos+10))
        Hour = tonumber(string.sub(payload, startpos+12, startpos+13)) + 2
        Hour = Hour % 24
        Min = tonumber(string.sub(payload, startpos+15, startpos+16))
        Sec = tonumber(string.sub(payload, startpos+18, startpos+19))
        i = nil
        j = nil
        
--        return string.format("%02d %02d %04d %02d:%02d:%02d",Day,Month,Year,Hour,Min,Sec)

        return Year,Month,Day,Hour,Min,Sec
    end

end    

--SerialWrite(DEBUGPORT, ExtractTimeData(string))

