local json = require("json")
local utils = require(".utils")
local bint = require('.bint')(256)

_TOKEN_ADDRESS = "jZrx_R1zuvUq7TVLd8fyUHgYu_N4ZtXw5KsP743ZHtY"

GPUModelList = GPUModelList or {}

Handlers.add(
    "Register-GPU-Model",
    Handlers.utils.hasMatchingTag("Action", "Register-GPU-Model"),
    function(msg)
        local gpuModel = msg.Data
        -- check gpu model id dulplicate
        for _, model in ipairs(GPUModelList) do
            if model == gpuModel then
                Handlers.utils.reply("[Error] [400] " .. "Register GPU Model " .. gpuModel .. "Model ID Duplicate")(msg)
                return
            end
        end
        table.insert(GPUModelList, gpuModel)
        Handlers.utils.reply("Register GPU Model Successfully " .. gpuModel)(msg)
    end
)

GPUList = GPUList or {}

Handlers.add(
    "Register-GPU",
    Handlers.utils.hasMatchingTag("Action", "Register-GPU"),
    function(msg)
        local gpu = json.decode(msg.Data)
        -- check gpu data item nil
        if not gpu.id or not gpu.gpumodel or not gpu.price then
            Handlers.utils.reply("[Error] [400] " .. "Register GPU " .. gpu.id .. "Data Item Nil")(msg)
            return
        end
        -- todo: check gpu data item type
        -- check gpu id dulplicate
        for _, g in ipairs(GPUList) do
            if g.id == gpu.id then
                Handlers.utils.reply("[Error] [400] " .. "Register GPU " .. gpu.id .. "ID Duplicate")(msg)
                return
            end
        end
        -- check gpu model
        local modelExist = utils.find(function(model) return model == gpu.gpumodel end, GPUModelList)
        if not modelExist then
            Handlers.utils.reply("[Error] [400] " .. "Register GPU " .. gpu.id .. "Model Not Exist")(msg)
            return
        end
        -- add busy flag and owner
        gpu.busy = false
        gpu.owner = msg.Owner
        table.insert(GPUList, gpu)
        Handlers.utils.reply("Register GPU Server Successfully " .. gpu.id)
    end
)

AIModelList = AIModelList or {}

Handlers.add(
    "Register-AI-Model",
    Handlers.utils.hasMatchingTag("Action", "Register-AI-Model"),
    function(msg)
        local aiModel = json.decode(msg.Data)
        -- check model data item nil
        if not aiModel.id or not aiModel.name or not aiModel.storageUrl or not aiModel.supportedGPUModel then
            Handlers.utils.reply("[Error] [400] " .. "Register AI Model " .. aiModel.id .. "Data Item Nil")(msg)
            return
        end
        -- check model data item type
        if type(aiModel.supportedGPUModel) ~= "table" then
            Handlers.utils.reply("[Error] [400] " ..
            "Register AI Model " .. aiModel.id .. "Supported GPU Model Type Error")(msg)
            return
        end
        -- check model id dulplicate
        local modelExist = utils.find(function(model) return model.id == aiModel.id end, AIModelList)
        if modelExist then
            Handlers.utils.reply("[Error] [400] " .. "Register AI Model " .. aiModel.id .. "ID Duplicate")(msg)
            return
        end
        -- check supported model exist
        for _, supportedModel in ipairs(aiModel.supportedGPUModel) do
            -- check supportedModel type
            if type(supportedModel) ~= "string" then
                Handlers.utils.reply("[Error] [400] " ..
                "Register AI Model " .. aiModel.id .. "Supported Model Type Error")(msg)
                return
            end
            local modelExist = utils.find(function(model) return model == supportedModel end, GPUModelList)
            if not modelExist then
                Handlers.utils.reply("[Error] [400] " ..
                "Register AI Model " .. aiModel.id .. "Supported Model Not Exist")(msg)
                return
            end
        end
        table.insert(AIModelList, aiModel)
        Handlers.utils.reply("Register Model Successfully " .. aiModel.id)(msg)
    end
)

AITask = AITask or {}

MarketBalances = MarketBalances or {}

local bintutils = {
    add = function (a,b) 
      return tostring(bint(a) + bint(b))
    end,
    subtract = function (a,b)
      return tostring(bint(a) - bint(b))
    end,
    toBalanceValue = function (a)
      return tostring(bint(a))
    end,
    toNumber = function (a)
      return tonumber(a)
    end
  }

local function SendFreeCredits(user)
    if MarketBalances[user] == nil then MarketBalances[user] = "200" end
end


-- Text-To-Image
-- Request Data: {"aiModelID":"xxx","params": {}}
Handlers.add(
    "Text-To-Image",
    Handlers.utils.hasMatchingTag("Action", "Text-To-Image"),
    function(msg)
        local requestData = json.decode(msg.Data)
        -- check request data item nil
        if not requestData.aiModelID or not requestData.params then
            Handlers.utils.reply("[Error] [400] " .. "Text-To-Image " .. requestData.aiModelID .. "Data Item Nil")(msg)
            return
        end
        -- check request data item type
        -- remark: let real ai server do the data struct check
        if type(requestData.params) ~= "table" then
            Handlers.utils.reply("[Error] [400] " .. "Text-To-Image " .. requestData.aiModelID .. "Params Type Error")(msg)
            return
        end
        -- check ai model exist
        local aiModel = utils.find(function(model) return model.id == requestData.aiModelID end, AIModelList)
        if not aiModel then
            Handlers.utils.reply("[Error] [400] " .. "Text-To-Image " .. requestData.aiModelID .. "Model Not Exist")(msg)
            return
        end
        -- find supported and unbusy gpu
        local gpu = utils.find(
            function(gpu)
                local modelSupport = utils.find(
                    function(model) return model == gpu.gpumodel end, aiModel.supportedGPUModel
                )
                return not gpu.busy and modelSupport ~= nil
            end, GPUList
        )
        if not gpu then
            Handlers.utils.reply("[Error] [403] " .. "Text-To-Image " .. requestData.aiModelID .. "No Available GPU")(msg)
            return
        end
        -- TODO: sort by gpu price
        -- check token balance, if has no balance, send 200 free credits
        SendFreeCredits(msg.From)
        if bint(MarketBalances[msg.From]) < bint(gpu.price) then
            Handlers.utils.reply("[Error] [403] " .. "Text-To-Image " .. requestData.aiModelID .. "Insufficient Balance")
            return
        else
            MarketBalances[msg.From] = bintutils.subtract(MarketBalances[msg.From], gpu.price)
        end
        
        -- Send request to 0rbit
        local requestID = GenerateRandomID(8)
        -- set request record
        AITask[requestID] = {
            From = msg.From,
            AIModelID = requestData.aiModelID,
            GPUID = gpu.id,
            Recipient = gpu.owner,
            Price = gpu.price,
            Status = "pending",
            RequestParams = requestData.params
        }
        Handlers.utils.reply("Text-To-Image " .. requestData.aiModelID .. "GPU " .. gpu.id)(msg)
        ao.send({
            Target = gpu.owner,
            Action = "Text-To-Image",
            Data = json.encode({
                taskID = requestID
            })
        })
    end
)

-- Accept-Task
-- TODO cron task to clean pending & processing task
Handlers.add(
  "Accept-Task",
  Handlers.utils.hasMatchingTag("Action", "Accept-Task"),
  function(msg)
      local data = json.decode(msg.Data)
      local record = AITask[data.taskID]
      -- check request record exist
      if not record then
          Handlers.utils.reply("[Error] [404] " .. "Accept-Task " .. data.taskID .. " Record Not Exist")(msg)
          return
      end
      -- check request record status
      if record.Status ~= "pending" then
          Handlers.utils.reply("[Error] [403] " .. "Accept-Task " .. data.taskID .. " Status Not Pending")(msg)
          return
      end
      -- check gpu owner match
    --   if record.Recipient ~= msg.Owner then
    --       Handlers.utils.reply("[Error] [403] " .. "Accept-Task " .. data.taskID .. " Owner Not Match " .. record.Recipient .. " " .. msg.Owner)(msg)
    --       return
    --   end
      -- check gpu busy: TODO: single thread -> multi thread
        local gpu = utils.find(function(gpu) return gpu.id == record.GPUID end, GPUList)
        if not gpu then
            Handlers.utils.reply("[Error] [404] " .. "Accept-Task " .. data.taskID .. " GPU Not Exist")(msg)
            return
        end
        if gpu.busy then
            Handlers.utils.reply("[Error] [403] " .. "Accept-Task " .. data.taskID .. " GPU Busy")(msg)
            return
        end

      -- set status
      record.Status = "processing"
      gpu.busy = true
      Handlers.utils.reply("Accept-Task " .. data.taskID)(msg)
  end
)

local function resetRequestRecord(taskID)
    -- set gpu unbusy
    local gpu = utils.find(function(gpu) return gpu.id == AITask[taskID].GPUID end, GPUList)
    if gpu then
        gpu.busy = false
    end
end

-- Receive-Response
Handlers.add(
    "Receive-Response",
    Handlers.utils.hasMatchingTag("Action", "Receive-Response"),
    function(msg)
        local data = json.decode(msg.Data)
        local record = AITask[data.taskID]
        -- check record exist
        if not record then
            Handlers.utils.reply("[Error] [404] " .. "Receive-Response " .. data.taskID .. "Record Not Exist")(msg)
            return
        end
        -- check owner match
        -- if record.Recipient ~= msg.Owner then
        --     Handlers.utils.reply("[Error] [403] " .. "Receive-Response " .. data.taskID .. "Owner Not Match")(msg)
        --     return
        -- end
        -- check status
        if record.Status ~= "processing" then
            Handlers.utils.reply("[Error] [403] " .. "Receive-Response " .. data.taskID .. "Status Not Processing")(msg)
            return
        end
        -- check response error
        if data.code ~= 200 then
            record.ResponseError = data.error
            -- check token balance
            MarketBalances[record.From] = bintutils.subtract(MarketBalances[record.From], record.price)
            -- return money to user
            MarketBalances[record.Recipient] = bintutils.add(MarketBalances[record.Recipient], record.Price)
            resetRequestRecord(data.taskID)
            Handlers.utils.reply("[Error] [500] " .. "Receive-Response " .. data.error)(msg)
            return
        else
            -- pay to gpu owner
            ao.send({ Target = _TOKEN_ADDRESS, Action = "Transfer", Recipient = record.Recipient, Quantity = tostring(record.Price) })
        end
        record.Status = "completed"
        record.ResponseData = data.data
        resetRequestRecord(data.taskID)
        Send({ Target = record.From, Action = "Text-To-Image-Response", Data = json.encode({
            taskID = data.taskID,
            data = data.data
        })})
    end
)

Handlers.add("Get-GPU-List", Handlers.utils.hasMatchingTag("Action", "Get-GPU-List"), function(msg)
  local UserGPUList = {}
    for _, gpu in pairs(GPUList) do
        if gpu.owner == msg.From then
            table.insert(UserGPUList, gpu)
        end
    end
    Handlers.utils.reply(json.encode(GPUList))(msg)
end)

Handlers.add("Get-GPU-Model-List", Handlers.utils.hasMatchingTag("Action", "Get-GPU-Model-List"), function(msg)
    Handlers.utils.reply(json.encode(GPUModelList))(msg)
end)

Handlers.add("Get-AI-Model-List", Handlers.utils.hasMatchingTag("Action", "Get-AI-Model-List"), function(msg)
    Handlers.utils.reply(json.encode(AIModelList))(msg)
end)

Handlers.add("Get-AI-Task-List", Handlers.utils.hasMatchingTag("Action", "Get-AI-Task-List"), function(msg)
    local req = JSONDecode(msg.Data)
    local UserTaskList = AITask
    if (type(req) ~= "table") then
        Handlers.utils.reply(json.encode(UserTaskList))(msg)
        return
    end
    if req.From then
        UserTaskList = ObjectFilter(UserTaskList, function(_, task) return task.From == req.From end)
    end
    if req.Status then
        UserTaskList = ObjectFilter(UserTaskList, function(_, task) return task.Status == req.Status end)
    end
    if req.GPUID then
        UserTaskList = ObjectFilter(UserTaskList, function(_, task) return task.GPUID == req.GPUID end)
    end
    Handlers.utils.reply(json.encode(UserTaskList))(msg)
end)
  

Handlers.add("Charge", Handlers.utils.hasMatchingTag("Action", "Credit-Notice"),function (msg)
    assert(type(msg.Quantity) == 'string', 'Quantity is required!')
    assert(type(msg.Sender) == 'string', 'Sender is required!')
    assert(msg.From == _TOKEN_ADDRESS, 'Only Accept Apus Token')
    SendFreeCredits(msg.Sender)
    MarketBalances[msg.Sender] = bintutils.add(MarketBalances[msg.Sender], msg.Quantity)
    ao.send({
        Target = msg.Sender,
        Action = "Deposit-Receiption",
        Quantity = msg.Quantity
    })
end)

Handlers.add("MarketBalances", Handlers.utils.hasMatchingTag("Action", "MarketBalances"), function(msg)
    SendFreeCredits(msg.From)
    Handlers.utils.reply(MarketBalances[msg.From])(msg)
end)