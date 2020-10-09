---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by seancheey.
--- DateTime: 10/6/20 1:13 AM
---

local assertNotNull = require("__MiscLib__/assert_not_null")
--- @type Vector2D
local Vector2D = require("__MiscLib__/vector2d")
--- @type TransportLineType
local TransportLineType = require("transport_line_type")
--- @type ArrayList
local ArrayList = require("__MiscLib__/array_list")

--- @class LuaEntitySpec
--- @field name string
--- @field position Vector2D
--- @field direction defines.direction
--- @field type '"input"'|'"output"'|nil only used for underground belt entity, otherwise nil

--- Represent a minimum segment of a path, can be either:
--- single belt/single input underground belt/single output underground belt/pair of underground belts etc...
--- @class PathUnit
--- @field name string Prototype name for the path unit
--- @field direction defines.direction
--- @field position Vector2D Starting point position for the path unit
--- @field distance number Distance of the path unit, minimum 1
--- @field type '"input"'|'"output"'|nil only used for unpaired underground belt entity, otherwise nil
--- @type PathUnit
local PathUnit = {}

--- @return defines.direction
local function reverseDirection(direction)
    return (direction + 4) % 8
end

--- @return defines.direction[]
local function frontLeftRightOf(direction)
    return { direction, (direction + 2) % 8, (direction + 6) % 8 }
end

--- @param entity LuaEntity
--- @param halfUndergroundPipeAsInput boolean since we cannot decide if a single underground pipe is input or output, by default we consider it as output
--- @return PathUnit
function PathUnit:fromLuaEntity(entity, halfUndergroundPipeAsInput)
    local newUnit = PathUnit:new {
        name = entity.name,
        position = Vector2D.fromPosition(entity.position),
        direction = entity.direction or defines.direction.north,
        distance = 1
    }
    if halfUndergroundPipeAsInput and TransportLineType.getType(entity.name).lineType == TransportLineType.fluidLine and TransportLineType.getType(entity.name).groundType == TransportLineType.underGround then
        newUnit.direction = reverseDirection(newUnit.direction)
    end
    return newUnit
end

--- @param o PathUnit
--- @return PathUnit
function PathUnit:new(o)
    assertNotNull(o.name, o.position, o.direction, o.distance)
    assert(type(o.direction) == "number")
    setmetatable(o, self)
    self.__index = self
    return o
end

--- @return LuaEntitySpec[]
function PathUnit:toEntitySpecs()
    local type = TransportLineType.getType(self.name)
    if type.groundType == TransportLineType.onGround then
        if self.distance == 1 then
            return {
                { name = self.name, direction = self.direction, position = self.position }
            }
        else
            -- although we basically don't include multiple onGround segments into one PathUnit, but I'll provide algorithm here
            local out = {}
            for dist = 0, self.distance - 1, 1 do
                out[#out + 1] = { name = self.name, direction = self.direction, position = self.position + Vector2D.fromDirection(self.direction):scale(dist) }
            end
            return out
        end
    else
        if type.lineType == TransportLineType.fluidLine then
            local out = {}
            out[1] = { name = self.name, direction = Vector2D.fromDirection(self.direction):reverse():toDirection(), position = self.position }
            if self.distance > 1 then
                out[2] = { name = self.name, direction = self.direction, position = self.position + Vector2D.fromDirection(self.direction):scale(self.distance - 1) }
            end
            return out
        else
            if self.distance == 1 then
                return {
                    { name = self.name, direction = self.distance, position = self.position, type = self.type }
                }
            else
                return {
                    { name = self.name, direction = self.direction, position = self.position, type = "input" },
                    { name = self.name, direction = self.direction, position = self.position + Vector2D.fromDirection(self.direction):scale(self.distance - 1), type = "output" }
                }
            end
        end
    end
end

--- @param allowUnderground boolean default false
--- @return PathUnit[]
function PathUnit:possibleNextPathUnits(allowUnderground)
    local attribute = TransportLineType.getType(self.name)
    local undergroundPrototype = TransportLineType.undergroundVersionOf(self.name)
    local onGroundPrototype = TransportLineType.onGroundVersionOf(self.name)
    local directionVector = Vector2D.fromDirection(self.direction)
    local endingPosition = (self.distance == 1) and self.position or (self.position + directionVector:scale(self.distance - 1))
    --- @type PathUnit[]|ArrayList
    local candidates = ArrayList.new()
    local posDiffDirections
    if attribute.lineType == TransportLineType.fluidLine and attribute.groundType == TransportLineType.onGround then
        -- on ground pipe allow 4-way direction
        posDiffDirections = { defines.direction.north, defines.direction.east, defines.direction.south, defines.direction.west }
    else
        -- all other only allow 1 direction
        posDiffDirections = { self.direction }
    end

    for _, posDiffDirection in ipairs(posDiffDirections) do
        local posDiffVector = Vector2D.fromDirection(posDiffDirection)
        local newPosition = endingPosition + posDiffVector
        if allowUnderground then
            -- adds underground candidates
            for underground_distance = 3, undergroundPrototype.max_underground_distance + 1 do
                candidates:add(PathUnit:new {
                    name = undergroundPrototype.name,
                    direction = posDiffDirection,
                    position = newPosition,
                    distance = underground_distance
                })
            end
        end
        -- adds on ground candidate
        candidates:add(PathUnit:new {
            name = onGroundPrototype.name,
            direction = posDiffDirection,
            position = newPosition,
            distance = 1
        })
    end
    return candidates
end

--- @param allowUnderground boolean
--- @return PathUnit[]
function PathUnit:possiblePrevPathUnits(allowUnderground)
    local undergroundPrototype = TransportLineType.undergroundVersionOf(self.name)
    local onGroundPrototype = TransportLineType.onGroundVersionOf(self.name)
    local attribute = TransportLineType.getType(self.name)
    --- @type PathUnit[]|ArrayList
    local candidates = ArrayList.new()
    --- @type defines.direction[]
    local posDiffDirections
    if attribute.lineType == TransportLineType.itemLine then
        if attribute.beltType == TransportLineType.undergroundBelt or attribute.beltType == TransportLineType.splitterBelt then
            -- underground belt/splitter's input only allows one direction
            posDiffDirections = { reverseDirection(self.direction) }
        else
            -- normal belt would allow 3 legal directions
            posDiffDirections = frontLeftRightOf(reverseDirection(self.direction))
        end
    else
        if attribute.groundType == TransportLineType.underGround then
            -- underground pipe's input only allows one direction
            posDiffDirections = { reverseDirection(self.direction) }
        else
            -- normal pipe would allow 4 legal directions
            posDiffDirections = { defines.direction.north, defines.direction.east, defines.direction.south, defines.direction.west }
        end
    end
    for _, posDiffDirection in ipairs(posDiffDirections) do
        local posDiffVector = Vector2D.fromDirection(posDiffDirection)
        if allowUnderground then
            -- adds underground candidates
            for underground_distance = 3, undergroundPrototype.max_underground_distance + 1 do
                candidates:add(PathUnit:new {
                    name = undergroundPrototype.name,
                    direction = reverseDirection(posDiffDirection),
                    position = self.position + posDiffVector:scale(underground_distance),
                    distance = underground_distance
                })
            end
        end
        -- adds on ground candidate
        candidates:add(PathUnit:new {
            name = onGroundPrototype.name,
            direction = reverseDirection(posDiffDirection),
            position = posDiffVector + Vector2D.fromPosition(self.position),
            distance = 1
        })
    end
    return candidates
end

function PathUnit:__eq(other)
    return self.name == other.name and self.direction == other.direction and self.position == other.position and self.distance == other.distance and self.type == other.type
end

--- only tests position and direction but doesn't care about if their TransportLineGroup are the same
--- @param other PathUnit
--- @return boolean
function PathUnit:canConnect(other)
    local attribute = TransportLineType.getType(self.name)
    for _, testUnit in ipairs(other:possiblePrevPathUnits()) do
        if self.position == testUnit.position then
            if attribute.lineType == TransportLineType.fluidLine and attribute.groundType == TransportLineType.onGround then
                -- pipe is not direction dependent, so we don't test for its direction
                return true
            else
                return self.direction == testUnit.direction
            end
        end
    end
    return false
end

return PathUnit