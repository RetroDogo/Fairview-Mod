-- functions

-- supply 2 tables and returns the difference.
function tableDiffValues(table1, table2)
    if type(table1) ~= "table" or type(table2) ~= "table" then
        return {}
    end
    local diff = {}

    local function valueExists(value, table)
        for _, v in ipairs(table) do
            if v == value then
                return true
            end
        end
        return false
    end

    for _, value in ipairs(table1) do
        if not valueExists(value, table2) then
            table.insert(diff, value)
        end
    end

    return diff
end

-- checks if a player exists and returns the player.
function checkPlayer(id)
    for _,player in pairs(sm.player.getAllPlayers()) do
        if player.id == id then
            return player
        end
    end
    return false
end

-- converts 2 vec3s into a distance between them.
function getDistance(vec1, vec2)
    local dx = vec1.x - vec2.x
    local dy = vec1.y - vec2.y
    local dz = vec1.z - vec2.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

-- converts number to formated string. (1000 -> 1,000)
function formatWithCommas(number)
    local formatted = tostring(number):reverse():gsub("(%d%d%d)", "%1,"):reverse()
    if formatted:sub(1, 1) == "," then
        formatted = formatted:sub(2)
    end
    return formatted
end

-- format numbers to always have a certan ammount of spaces 1 > 01 or 15 > 15 
function formatTwoDigits(num)
    return string.format("%02d", num)
end

-- converts millitary to ordinary am/pm time
function convertToAmPm(militaryHour)
    -- Ensure input is valid
    if militaryHour < 0 or militaryHour > 30 then
        return false
    end

    local isPM = militaryHour >= 15
    local amPmHour = militaryHour % 15
    if amPmHour == 0 then amPmHour = 15 end -- Handle midnight and noon edge cases

    local period = isPM and "PM" or "AM"
    return amPmHour, isPM
end

-- gives 2 tick differences to 0h0m0s
function ticksToTimeDifference(tick1, tick2)
    local tickDiff = math.abs(tick1 - tick2)
    local totalSeconds = tickDiff / 40  -- since 1 tick = 1/40 of a second

    -- Break down the total seconds into months, days, hours, minutes, seconds, and milliseconds
    local months = math.floor(totalSeconds / (30 * 24 * 60 * 60))  -- Approx 30 days in a month
    totalSeconds = totalSeconds % (30 * 24 * 60 * 60)

    local days = math.floor(totalSeconds / (24 * 60 * 60))
    totalSeconds = totalSeconds % (24 * 60 * 60)

    local hours = math.floor(totalSeconds / (60 * 60))
    totalSeconds = totalSeconds % (60 * 60)

    local minutes = math.floor(totalSeconds / 60)
    local seconds = math.floor(totalSeconds % 60)
    local milliseconds = math.floor((totalSeconds % 1) * 1000)

    -- Build the output string in a short format
    local timeString = ""
    if months > 0 then timeString = timeString .. months .. "m " end
    if days > 0 then timeString = timeString .. days .. "d " end
    if hours > 0 then timeString = timeString .. hours .. "h " end
    if minutes > 0 then timeString = timeString .. minutes .. "m " end
    if seconds > 0 then timeString = timeString .. seconds .. "s " end

    -- Clean up trailing space if any
    return timeString:match("^%s*(.-)%s*$")
end

-- checks if a given "#FFFFFF" string is a valid hex color
function isValidHexColor(str)
    -- Check if the string starts with "#" and has exactly 7 characters
    if str:sub(1, 1) == "#" and #str == 7 then
        for i = 2, 7 do
            local char = str:sub(i, i)
            if not ((char >= "0" and char <= "9") or (char >= "A" and char <= "F") or (char >= "a" and char <= "f")) then
                return false
            end
        end
        return true
    end

    return false
end

-- picks a random item from a table
function pickRandomItem(tbl)
    if #tbl == 0 then
        return nil -- Return nil if the table is empty
    end

    local randomIndex = math.random(1, #tbl) -- Get a random index
    return tbl[randomIndex] -- Return the item at the random index
end

-- removes a value from a table if it exists
function smartRemove(t, value, removeAll)
    local i = 1
    while i <= #t do
        if t[i] == value then
            table.remove(t, i)
            if not removeAll then
                return true
            end
        else
            i = i + 1
        end
    end
    return false
end

-- removes a value from a table if it exists
function smartRemoveFromIndex(t, index, removeAll)
    local i = 1
    for i,_ in pairs(t) do
        if i == index then
            table.remove(t, i)
            if not removeAll then
                return true
            end
        else
            i = i + 1
        end
    end
    return false
end

-- checks if the storage alreaty exists and saves to the data or saves new data
function saveToStorage(self,data,index)
    if self.storage:load() then
        local storage = self.storage:load()
        storage[index] = data
        self.storage:save(storage)
    else
        self.storage:save({[index] = data})
    end
end

-- weird math function idk
function sigmoid(x, a, b)
	return 1/(1 + math.exp(-2 * a * (x + b)))
end

-- converts color to hashtag
function colorToHashtag(color)
	col = sm.color.new(
    sigmoid(color.r, 5, -0.25),
    sigmoid(color.g, 5, -0.25),
    sigmoid(color.b, 5, -0.25))
	return "#"..string.sub(tostring(col), 0, 6)
end

-- Function to check if a string is a valid UUIDv4
function isValidUUIDv4(uuid)
    -- Check the total length of the UUID
    if #uuid ~= 36 then
        return false
    end

    -- Check for correct dash positions
    if uuid:sub(9, 9) ~= "-" or uuid:sub(14, 14) ~= "-" or uuid:sub(19, 19) ~= "-" or uuid:sub(24, 24) ~= "-" then
        return false
    end

    -- Ensure the 20th character is one of '8', '9', 'a', or 'b' (UUID variant)
    local variantChar = uuid:sub(20, 20):lower()
    if variantChar ~= "8" and variantChar ~= "9" and variantChar ~= "a" and variantChar ~= "b" then
        return false
    end

    -- Ensure all other characters are valid hex (0-9, a-f)
    local hexDigits = "0123456789abcdef"
    for i = 1, #uuid do
        local char = uuid:sub(i, i):lower()
        if char ~= "-" and not hexDigits:find(char, 1, true) then
            return false
        end
    end

    -- All checks passed, it's a valid UUIDv4
    return true
end

-- gets the lowest value in a table (must be number)
function getLowestTableValue(table)
    if type(table) ~= "table" then return false end
    lowestVal = nil
    lowestValIndex = 0
    for i,v in pairs(table) do
        if type(v) == "number" then
            if not lowestVal then lowestVal = v lowestValIndex = i end
            if v < lowestVal then
                lowestVal = v
                lowestValIndex = i
            end
        end
    end
    return {lowestVal = lowestVal,lowestValIndex = lowestValIndex}
end

-- gets the closest player to a position
function closestPlayerToPos(self,position)
    playersDistance = {}
    for _,player in pairs(sm.player.getAllPlayers()) do
        playersDistance[player] = getDistance(position,player.character.worldPosition)
    end
    return getLowestTableValue(playersDistance).lowestValIndex
end

-- finds any value in a table and returns index
function findValueInTable(tbl,v)
    if type(tbl) ~= "table" then return false end
    for i,tblV in pairs(tbl) do
        if tblV == v then
            return i
        end
    end
    return false
end

-- gets all vec3s in a table and averages them
function averageTableVec3s(tbl)

    -- checks if its a table
    if type(tbl) ~= "table" then return false end

    -- checks if only vec3s exist in the table
    for _,v in pairs(tbl) do
        if type(v) ~= "Vec3" then
            return false
        end
    end

    -- formats all vec3s into 3 XYZ tables
    local X = 0
    local Y = 0
    local Z = 0
    for _,v in pairs(tbl) do
        X = X + v.x
        Y = Y + v.y
        Z = Z + v.z
    end

    return sm.vec3.new( X,Y,Z )/#tbl

end

-- gets all numbers in a table and averages them
function averageTableNumbers(tbl)

    -- checks if its a table
    if type(tbl) ~= "table" then return false end

    -- checks if only numbers exist in the table
    for _,v in pairs(tbl) do
        if not tonumber(v) then
            return false
        end
    end

    -- averages vec3s
    local output = 0
    for _,v in pairs(tbl) do
        output = output + tonumber(v)
    end

    -- returns the output divided by the amount
    return output/#tbl
    
end

-- gets all numbers in a table and averages them
function clampVec3(vec3,min,max)
    return sm.vec3.new(
        sm.util.clamp(vec3.x,min,max),
        sm.util.clamp(vec3.y,min,max),
        sm.util.clamp(vec3.z,min,max)
    )
end

-- rounds any number for real
function round(number,roundto)
    if not type(number) == "number" then return number end
    local number = number/roundto
    local dec = math.fmod(number,roundto)
    if dec < 0 then dec = -dec end -- checks for negitive decimals
    return dec >= 0.5 and math.floor(number)*roundto or (math.floor(number)+1)*roundto
end

-- rounds any number for real
function floorTo(number,floorTo)
    if not type(number) == "number" then return number end
    local number = number/floorTo
    return math.floor(number)*floorTo
end

-- Function to extract the hundreds, thousands, and millions place
function extractPlaces(number)
    local hundreds = number % 1000
    local thousands = math.floor((number / 1000) % 1000)
    local millions = math.floor(number / 1000000)
    return hundreds, thousands, millions
end

function tickToTime(tick)
    local totalSeconds = tick / 40  -- since 1 tick = 1/40 of a second

    -- Break down the total seconds into months, days, hours, minutes, seconds, and milliseconds
    local months = math.floor(totalSeconds / (30 * 24 * 60 * 60))  -- Approx 30 days in a month
    totalSeconds = totalSeconds % (30 * 24 * 60 * 60)

    local days = math.floor(totalSeconds / (24 * 60 * 60))
    totalSeconds = totalSeconds % (24 * 60 * 60)

    local hours = math.floor(totalSeconds / (60 * 60))
    totalSeconds = totalSeconds % (60 * 60)

    local minutes = math.floor(totalSeconds / 60)
    local seconds = math.floor(totalSeconds % 60)
    local milliseconds = math.floor((totalSeconds % 1) * 1000)

    -- Build the output string in a short format
    local timeString = ""
    if months > 0 then timeString = timeString .. months .. "m " end
    if days > 0 then timeString = timeString .. days .. "d " end
    if hours > 0 then timeString = timeString .. hours .. "h " end
    if minutes > 0 then timeString = timeString .. minutes .. "m " end
    if seconds > 0 then timeString = timeString .. seconds .. "s " end
    return timeString
end

-- Function to compare two tables
function areTablesEqual(table1, table2)
    -- If either is not a table, return false
    if type(table1) ~= "table" or type(table2) ~= "table" then
        return false
    end

    -- Check if they have the same number of keys
    local table1Keys = 0
    local table2Keys = 0
    for key in pairs(table1) do
        table1Keys = table1Keys + 1
        if table2[key] == nil then
            return false -- Key exists in table1 but not in table2
        end
    end
    for _ in pairs(table2) do
        table2Keys = table2Keys + 1
    end
    if table1Keys ~= table2Keys then
        return false -- Different number of keys
    end

    -- Recursively compare all key-value pairs
    for key, value in pairs(table1) do
        if not areTablesEqual(value, table2[key]) then
            return false
        end
    end

    return true
end