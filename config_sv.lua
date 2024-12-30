ConfigSV = {
    logTypes = {
        ["placeHit"] = {
            label = "Hit Placed", 
            url = "DISCORD_WEBHOOK_HERE", 
            -- No touching below this line. Unless you are big brain.
            fields = function(data)
                return {
                    { name = "Issuer", value = ConfigSV.playerFunction(data.issuer) or "Unknown Issuer" },
                    { name = "Target", value = ConfigSV.playerFunction(data.target) or "Unknown Target" },
                    { name = "Reward", value = NumberWithCommas(data.reward) },
                    { name = "Time", value = os.date("%c") }
                }
            end 
        },
        ["acceptHit"] = { 
            label = "Hit Accepted", 
            url = "DISCORD_WEBHOOK_HERE", 
            -- No touching below this line. Unless you are big brain.
            fields = function(data)
                return {
                    { name = "Hitman", value = ConfigSV.playerFunction(data.hitman) or "Unknown Hitman" },
                    { name = "Target", value = ConfigSV.playerFunction(data.target) or "Unknown Target" },
                    { name = "Reward", value = NumberWithCommas(data.reward) },
                    { name = "Time", value = os.date("%c") }
                }
            end 
        },
        ["removeHit"] = { 
            label = "Hit Removed",
            url = "DISCORD_WEBHOOK_HERE", 
            -- No touching below this line. Unless you are big brain.
            fields = function(data)
                return {
                    { name = "Remover", value = ConfigSV.playerFunction(data.remover) or "Unknown Issuer" },
                    { name = "Target", value = ConfigSV.playerFunction(data.target) or "Unknown Target" },
                    { name = "Reward", value = NumberWithCommas(data.reward) },
                    { name = "Time", value = os.date("%c") }
                }
            end 
        },
        ["hitKilled"] = { 
            label = "Hit Killed",
            url = "DISCORD_WEBHOOK_HERE", 
            -- No touching below this line. Unless you are big brain.
            fields = function(data)
                return {
                    { name = "Target", value = ConfigSV.playerFunction(data.target) or "Unknown Target" },
                    { name = "Time", value = os.date("%c") }
                }
            end 
        },
        ["hitComplete"] = { 
            label = "Hit Complete",
            url = "DISCORD_WEBHOOK_HERE", 
            -- No touching below this line. Unless you are big brain.
            fields = function(data)
                return {
                    { name = "Hitman", value = ConfigSV.playerFunction(data.hitman) or "Unknown Hitman" },
                    { name = "Target", value = ConfigSV.playerFunction(data.target) or "Unknown Target" },
                    { name = "Reward", value = NumberWithCommas(data.reward) },
                    { name = "Time", value = os.date("%c") }
                }
            end 
        },
    },
    playerFunction = function(data)
        local str = data.identifier
        if data.source then
            str = str .. " (ID: " .. data.source .. ")"
        end
        return str
    end,
    logFunction = function(logType, data)
        local logTypeData = ConfigSV.logTypes[logType]
        if not logTypeData or logTypeData.url == "DISCORD_WEBHOOK_HERE" then print("ERROR: COULDN'T SEND LOG.", json.encode(logTypeData), json.encode(data)) return end
        PerformHttpRequest(logTypeData.url, function(err, text, headers) end, 'POST', json.encode({
            username = "Hitman Logs",
            embeds = {
                {
                    title = logTypeData.label,
                    fields = logTypeData.fields(data) or {},
                    color = 16711680 -- Red color
                }
            }
        }), { ['Content-Type'] = 'application/json' })
    end
}