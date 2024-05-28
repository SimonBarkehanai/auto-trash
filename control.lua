local function create_requests(player)
    if not player.character then
        return
    end
    local reqs = {
        ["blueprint"] = true,
        ["deconstruction-planner"] = true,
        ["upgrade-planner"] = true,
        ["blueprint-book"] = true,
    }
    for i = 1, 1000 do
        local req = player.get_personal_logistic_slot(i)
        if req.name ~= nil then
            reqs[req.name] = i
        end
    end
    global.reqs[player.index] = reqs
end

script.on_event(defines.events.on_player_joined_game,
    function(event)
        local idx = event.player_index
        if not global.reqs[idx] then
            create_requests(game.get_player(idx))
        end
    end)

script.on_event(defines.events.on_player_removed, function(event)
    global.reqs[event.player_index] = nil
end)

local function get_requests()
    global.reqs = {}
    for _, p in pairs(game.players) do
        create_requests(p)
    end
end

script.on_init(get_requests)
script.on_configuration_changed(get_requests)

local function clean_inventory(i)
    local player = game.get_player(i)
    if not player then
        return
    end
    local reqs = global.reqs[i]
    if not player.character or not player.character_personal_logistic_requests_enabled or not reqs then
        return
    end

    local main = player.get_inventory(defines.inventory.character_main)
    local trash = player.get_inventory(defines.inventory.character_trash)
    if not trash or not main then
        return
    end
    trash.sort_and_merge()
    for idx = 1, #main do
        local stack = main[idx]
        if stack.count > 0 and stack.name ~= nil and not reqs[stack.name] then
            trash.sort_and_merge()
            stack.count = stack.count - trash.insert(stack)
        end
    end
end

script.on_event(defines.events.on_player_main_inventory_changed,
    function(event)
        clean_inventory(event.player_index)
    end)

---@param event EventData.on_entity_logistic_slot_changed
local function update_requests(event)
    local player = event.entity.is_player() and event.entity.player or nil
    if not player then
        return
    end

    local reqs = global.reqs[player.index]
    if not reqs then
        return
    end

    local index = event.slot_index

    for name, slot in pairs(reqs) do
        if slot == index then
            reqs[name] = nil
            break
        end
    end

    local new = player.get_personal_logistic_slot(index)
    if new.name then
        reqs[new.name] = index
    end

    clean_inventory(player.index)
end

script.on_event(defines.events.on_entity_logistic_slot_changed, update_requests)

commands.add_command("my-requests", nil, function(d)
    game.players[d.player_index].print(serpent.block(global.reqs[d.player_index]))
end)

commands.add_command("fix-my-requests", nil, function(d)
    global.reqs[d.player_index] = nil
    create_requests(game.players[d.player_index])
end)
