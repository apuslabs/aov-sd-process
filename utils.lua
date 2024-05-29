local math = require("math")

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