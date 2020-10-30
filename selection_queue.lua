---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by seancheey.
--- DateTime: 10/13/20 9:04 PM
---

--- @type ArrayList
local ArrayList = require("__MiscLib__/array_list")
--- @type Logger
local logging = require("__MiscLib__/logging")

--- @class EntitySelectionInfo
--- @field entity LuaEntity
--- @field rectangleId number
--- @field textId number

--- @class SelectionQueue
--- @field queue ArrayList|EntitySelectionInfo[] I use arraylist here since player won't select too much belts at the same time and linked list has extra memory cost
--- @field playerIndex player_index
--- @type SelectionQueue
local SelectionQueue = {}
SelectionQueue.__index = SelectionQueue

local renderedBoxLiveTime = 60 * 60 * 5 -- 5 min

--- @return SelectionQueue
function SelectionQueue:new(playerIndex)
    --- @type SelectionQueue
    local o = {}
    setmetatable(o, self)
    o.playerIndex = playerIndex
    o.queue = ArrayList.new()
    return o
end

--- @param entity LuaEntity
function SelectionQueue:push(entity)
    local rectId = rendering.draw_rectangle {
        surface = game.players[self.playerIndex].surface,
        players = { game.players[self.playerIndex] },
        color = { 0.1, 1, 0.1, 0.5 },
        width = 2.5,
        filled = false,
        left_top = entity.selection_box.left_top,
        right_bottom = entity.selection_box.right_bottom,
        time_to_live = renderedBoxLiveTime -- 60tick/sec * 60sec/min = 1 min live time
    }

    local textId = rendering.draw_text {
        surface = game.players[self.playerIndex].surface,
        players = { game.players[self.playerIndex] },
        text = #self + 1,
        color = { 1, 1, 1, 0.9 },
        target = entity,
        time_to_live = renderedBoxLiveTime
    }
    self.queue:add { entity = entity, rectangleId = rectId, textId = textId }
end

--- @return LuaEntity
function SelectionQueue:pop()
    if #self.queue > 0 then
        --- @type EntitySelectionInfo
        local selection = self.queue:popLeft()
        rendering.destroy(selection.rectangleId)
        rendering.destroy(selection.textId)
        self:__updateLabelNumbers()
        return selection.entity
    end
end

--- @param index number
--- @return LuaEntity|nil
function SelectionQueue:removeIndex(index)
    --- @type EntitySelectionInfo
    local removedSelection = self.queue:pop(index)
    if removedSelection then
        rendering.destroy(removedSelection.rectangleId)
        rendering.destroy(removedSelection.textId)
        self:__updateLabelNumbers()
        return removedSelection.entity
    end
end

--- @param entity LuaEntity
--- @return boolean true if success
function SelectionQueue:tryRemoveDuplicate(entity)
    local i = 1
    while i <= #self.queue do
        local selection = self.queue[i]
        if selection.entity.valid then
            if entity.position.x == selection.entity.position.x and entity.position.y == selection.entity.position.y then
                self:removeIndex(i)
                return true
            end
            i = i + 1
        else
            logging.log("removed one invalid selection")
            self:removeIndex(i)
        end
    end
    return false
end

function SelectionQueue:__updateLabelNumbers()
    for i, otherSelection in ipairs(self.queue) do
        if rendering.is_valid(otherSelection.textId) then
            rendering.set_text(otherSelection.textId, i)
        else
            rendering.draw_text {
                surface = game.players[self.playerIndex].surface,
                players = { game.players[self.playerIndex] },
                text = i,
                color = { 1, 1, 1, 0.9 },
                target = otherSelection.entity,
                time_to_live = renderedBoxLiveTime
            }
        end
    end
end

function SelectionQueue:__len()
    return #self.queue
end

return SelectionQueue