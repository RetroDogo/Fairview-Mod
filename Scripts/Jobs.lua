dofile("$CONTENT_DATA/Scripts/Utils.lua")
dofile("$CONTENT_DATA/Scripts/QueueMessages.lua")

-- local jobs = sm.json.open("$CONTENT_DATA/Json/Jobs.json")

-- job stuff

function JOB_onFixedUpdate(self)

    -- gives money per minute
    local timeHour = math.floor(sm.game.getTimeOfDay()*30)
    if timeHour ~= self.sv.timeHour then
        self.sv.timeHour = timeHour
        local jobs = sm.json.open("$CONTENT_DATA/Json/Jobs.json")
        local Currency = sm.json.open("$CONTENT_DATA/Json/Currency.json")
        for jobName,job in pairs(jobs) do
            for _,worker in pairs(job.workers) do
                if Currency[tostring(worker)] and checkPlayer(tonumber(worker)) and findValueInTable(job.clocked,tostring(worker)) then
                    Currency[tostring(worker)][1] = Currency[tostring(worker)][1] + job.pay
                end
            end
        end
        sm.json.save(Currency,"$CONTENT_DATA/Json/Currency.json")
    end

    if sm.game.getCurrentTick()%40 == 0 then
        
    end

end


function JOB_onJobCreate(self,player,createdJobName,pay)

    local jobs = sm.json.open("$CONTENT_DATA/Json/Jobs.json")

    -- checks if the team name already exists
    for jobName,_ in pairs(jobs) do
        if jobName == createdJobName then
            self.network:sendToClient(player, "cl_sendTextMessage","#FF0000Job already exists!")
            return
        end
    end

    -- makes the team and saves it
    jobs[createdJobName] = {pay = pay,workers = {"100"},clocked = {"100"}}
    sm.json.save(jobs,"$CONTENT_DATA/Json/Jobs.json")

end

function JOB_onJoAdd(self,addedJobName,addedPlayerId)

    local jobs = sm.json.open("$CONTENT_DATA/Json/Jobs.json")
    local addedPlayer = checkPlayer(addedPlayerId)

    -- checks if the player exists
    if not addedPlayer then
        self.network:sendToClient(player, "cl_sendTextMessage","#FF0000Player Invalid!")
        return
    end

    -- checks if the team exists
    local found = false
    for jobName,_ in pairs(jobs) do
        if jobName == addedJobName then
            found = true
        end
    end
    if not found then
        self.network:sendToClient(player, "cl_sendTextMessage","#FF0000Job doesnt exist!")
        return
    end

    -- checks if the player doesnt work at another job
    local found = false
    for _,job in pairs(jobs) do
        for _,worker in pairs(job.workers) do
            if tonumber(worker) == tonumber(addedPlayerId) then
                found = true
            end
        end
    end
    if found then
        self.network:sendToClient(player, "cl_sendTextMessage","#FF0000Player works at another job!")
        return
    end

    -- makes the team and saves it
    table.insert(jobs[addedJobName].workers,tostring(addedPlayerId))
    sm.json.save(jobs,"$CONTENT_DATA/Json/Jobs.json")
    
end

function JOB_onJobDelete(self)

end

function JOB_onJobLeave(self,player)
    
end

function JOB_onJobFire(self,player)

end