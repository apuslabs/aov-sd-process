local math = require("math")
local json = require("json")

-- URL编码一个字符串
local function urlencode(str)
  if str then
      str = string.gsub(str, "\n", "\r\n")
      str = string.gsub(str, "([^%w ])", function(c)
          return string.format("%%%02X", string.byte(c))
      end)
      str = string.gsub(str, " ", "+")
  end
  return str
end

-- 将表转换为URL查询字符串
function EncodeTable(t)
  local url_parts = {}
  for key, value in pairs(t) do
      table.insert(url_parts, urlencode(key) .. "=" .. urlencode(value))
  end
  return table.concat(url_parts, "&")
end

-- 初始化随机种子
math.randomseed(os.time())

-- 函数生成随机ID
function GenerateRandomID(length)
    local chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    local charsLen = #chars
    local randomID = {}

    for i = 1, length do
        local randIndex = math.random(charsLen)
        table.insert(randomID, string.sub(chars, randIndex, randIndex))
    end

    return table.concat(randomID)
end


-- Decode With Error Handler
function JSONDecode(val)
    local status, result = xpcall(
        json.decode,
        function(err)
            print("[400] error: " .. err)
        end,
        val
    )
    if status then
        return result
    else
        return {}
    end
end

-- Filter
function ArrayFilter(arr, filter)
    local result = {}
    for i, v in ipairs(arr) do
        if filter(v) then
            table.insert(result, v)
        end
    end
    return result
end
function ObjectFilter(obj, filter)
    local result = {}
    for k, v in pairs(obj) do
        if filter(k, v) then
            result[k] = v
        end
    end
    return result
end

-- Check is process owner
function IsProcessOwner(msg)
    if msg.From == ao.id then
        return true
    else
        Handlers.utils.reply("[Error] [401] " .. "You are not the owner of this process.")(msg)
        return false
    end
end

-- Check if the string is a valid UUIDv4
function IsUUIDv4(str)
    assert(type(str) == "string", "str must be a string")
    local pattern = "^[0-9a-fA-F]{8}%-[0-9a-fA-F]{4}%-4[0-9a-fA-F]{3}%-[89aAbB][0-9a-fA-F]{3}%-[0-9a-fA-F]{12}$"
    return str:match(pattern) ~= nil
end