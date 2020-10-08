---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by seancheey.
--- DateTime: 9/30/20 1:11 AM
---


--- @alias player_index number

--- @type ArrayList
local ArrayList = require("__MiscLib__/array_list")
--- @type Copier
local Copy = require("__MiscLib__/copy")
--- @type Logger
local logging = require("__MiscLib__/logging")
--- @type TransportLineConnector
local TransportLineConnector = require("transport_line_connector")
local releaseMode = require("release")
--- @type TransportLineType
local TransportLineType = require("transport_line_type")
--- @type Vector2D
local Vector2D = require("__MiscLib__/vector2d")
--- @type table<string, boolean>
local loggingCategories = {
    reward = false,
    placing = false,
    transportType = false
}
--- @type AsyncTaskManager
local AsyncTaskManager = require("__MiscLib__/async_task")

local taskManager = AsyncTaskManager:new()
taskManager:resolveTaskEveryNthTick(1)

for category, enable in pairs(loggingCategories) do
    logging.addCategory(category, releaseMode and false or enable)
end
if releaseMode then
    logging.disableCategory(logging.D)
    logging.disableCategory(logging.I)
    logging.disableCategory(logging.V)
end

--- @type table<player_index, ArrayList|LuaEntity[]>
local playerSelectedStartingPositions = {}

local function pushNewStartingPosition(player_index, entity)
    if playerSelectedStartingPositions[player_index] == nil then
        playerSelectedStartingPositions[player_index] = ArrayList.new()
    end
    playerSelectedStartingPositions[player_index]:add(entity)
end

local function popNewStartingPosition(player_index)
    if playerSelectedStartingPositions[player_index] then
        return playerSelectedStartingPositions[player_index]:popLeft()
    end
end

local function setStartingTransportLine(event)
    local player = game.players[event.player_index]
    local selectedEntity = player.selected
    if not selectedEntity then
        return
    end
    local transportLineType = TransportLineType.getType(selectedEntity.prototype.name)
    if transportLineType then
        if transportLineType.beltType == TransportLineType.splitterBelt then
            -- since splitter belt has 2-block width, we need to figure out which part is routable and smartly choose the routable belt
            local splitterPositions = ArrayList.new { Vector2D.new(0, 0), Vector2D.new(0, 0) }
            splitterPositions[1].x = selectedEntity.position.x % 1 == 0 and selectedEntity.position.x - 0.5 or selectedEntity.position.x
            splitterPositions[1].y = selectedEntity.position.y % 1 == 0 and selectedEntity.position.y - 0.5 or selectedEntity.position.y
            splitterPositions[2].x = selectedEntity.position.x % 1 == 0 and selectedEntity.position.x + 0.5 or selectedEntity.position.x
            splitterPositions[2].y = selectedEntity.position.y % 1 == 0 and selectedEntity.position.y + 0.5 or selectedEntity.position.y
            local routablePositions = splitterPositions:filter(function(pos)
                local targetPos = pos + Vector2D.fromDirection(selectedEntity.direction)
                return player.surface.find_entities({ { targetPos.x, targetPos.y }, { targetPos.x, targetPos.y } })[1] == nil
            end)
            local chosenPosition = #routablePositions > 0 and routablePositions[1] or splitterPositions[1]
            logging.log("splitter chosen position = " .. serpent.line(chosenPosition))
            selectedEntity = {
                name = selectedEntity.name,
                direction = selectedEntity.direction,
                position = chosenPosition,
                valid = true
            }
        end
        pushNewStartingPosition(event.player_index, selectedEntity)
        player.print("queued one " .. selectedEntity.name .. " into connection waiting list. There are " .. #playerSelectedStartingPositions[event.player_index] .. " belts in connection waiting list")
    end
end

local function setEndingTransportLine(event, config)
    local player = game.players[event.player_index]
    local selectedEntity = player.selected
    if not selectedEntity then
        return
    end
    if not TransportLineType.getType(selectedEntity.prototype.name) then
        return
    end
    local startingEntity = popNewStartingPosition(event.player_index)
    if not startingEntity then
        player.print("You haven't specified any starting belt yet. Place a belt as starting transport line, and then shift + right click on it to mark it as starting belt.")
        return
    end
    logging.log("build line with config: " .. serpent.line(config))
    local surface = player.surface
    local function canPlace(position)
        return surface.can_place_entity { name = "transport-belt", position = position, build_check_type = defines.build_check_type.ghost_place }
    end
    local num = 1
    local function place(entity)
        entity = Copy.deep_copy(entity)
        entity.force = player.force
        if entity.name ~= "entity-ghost" and entity.name ~= "speech-bubble" then
            entity.inner_name = entity.name
            entity.name = "entity-ghost"
        end
        entity.player = player
        if not releaseMode then
            player.create_local_flying_text { text = tostring(num), position = entity.position, time_to_live = 100000, speed = 0.000001 }
            num = num + 1
        end
        surface.create_entity(entity)
    end
    local function getEntity(position)
        for _, entity in pairs(surface.find_entities({ { position.x, position.y }, { position.x, position.y } })) do
            -- don't want player/other vehicles to be included
            if TransportLineType.getType(entity.name) then
                return entity
            end
        end
    end
    local transportLineConstructor = TransportLineConnector.new(canPlace, place, getEntity, taskManager)
    local errorMessage = transportLineConstructor:buildTransportLine(startingEntity, selectedEntity, taskManager, config, player)
    if errorMessage then
        player.print(errorMessage)
    end
end

local function buildTransportLineWithConfig(config)
    return function(event)
        setEndingTransportLine(event, config)
    end
end

script.on_event("select-line-starting-point", setStartingTransportLine)
script.on_event("build-transport-line", buildTransportLineWithConfig { allowUnderground = true })
script.on_event("build-transport-line-no-underground", buildTransportLineWithConfig { allowUnderground = false })
