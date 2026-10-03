local StateSchema = {}

function StateSchema.new()
    return {
        Currency = 120,
        Soldiers = {[1] = 0, [2] = 0, [3] = 0},
        Conquered = {},
    }
end

function StateSchema.sanitize(raw)
    local state = StateSchema.new()
    if type(raw) ~= "table" then return state end
    state.Currency = math.max(0, math.floor(tonumber(raw.Currency) or state.Currency))
    if type(raw.Soldiers) == "table" then
        for level = 1, 3 do state.Soldiers[level] = math.max(0, math.floor(tonumber(raw.Soldiers[level]) or 0)) end
    end
    if type(raw.Conquered) == "table" then
        for id, conquered in pairs(raw.Conquered) do if conquered == true then state.Conquered[tostring(id)] = true end end
    end
    return state
end

return StateSchema
