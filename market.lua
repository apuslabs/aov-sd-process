local json = require("json")
local utils = require(".utils")
local bint = require('.bint')(256)

_TOKEN_ADDRESS = "jZrx_R1zuvUq7TVLd8fyUHgYu_N4ZtXw5KsP743ZHtY"

GPUModelList = GPUModelList or {}

Handlers.add(
    "Register-GPU-Model",
    Handlers.utils.hasMatchingTag("Action", "Register-GPU-Model"),
    function(msg)
        if not IsProcessOwner(msg) then
            return
        end
        local gpuModel = msg.Data
        assert(type(msg.Data) == "string", "GPU Model Must be string")
        -- check gpu model id dulplicate
        local modelExist = utils.find(function (model) return model == gpuModel end, GPUModelList)
        assert(not modelExist, "Model Duplicate")
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
        -- check gpu data item type
        assert(type(gpu.id) == "string", "GPU ID Type Error")
        if not IsUUIDv4(gpu.id) then
            return
        end
        assert(type(gpu.gpumodel) == "string", "GPU Model Type Error")
        assert(type(gpu.price) == "string", "GPU Price Type Error") -- bigint
        -- check gpu model valid
        local modelExist = utils.find(function(model) return model == gpu.gpumodel end, GPUModelList)
        assert(modelExist, "GPU Model Not Exist")
        -- check gpu id dulplicate
        local idExist = utils.find(function(gpu) return gpu.id == gpu.id end, GPUList)
        if idExist then
            -- Update GPU
            for k, v in pairs(gpu) do
                idExist[k] = v
            end
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
        if not IsProcessOwner(msg) then
            return
        end
        local aiModel = json.decode(msg.Data)
        -- check model data item type
        assert(type(aiModel.id) == "string", "AI Model ID Type Error")
        if not IsUUIDv4(aiModel.id) then
            return
        end
        assert(type(aiModel.name) == "string", "AI Model Name Type Error")
        -- assert(type(aiModel.storageUrl) == "string", "AI Model Storage URL Type Error")
        assert(type(aiModel.supportedGPUModel) == "table", "AI Model Supported GPU Model Type Error")
        assert(type(aiModel.hash) == "string", "AI Model Hash Type Error")
        -- check supported model exist
        for _, supportedModel in ipairs(aiModel.supportedGPUModel) do
            -- check supportedModel type
            assert(type(supportedModel) == "string", "AI Model Supported Model Type Error")
            local modelExist = utils.find(function(model) return model == supportedModel end, GPUModelList)
            assert(modelExist, "Supported Model Not Exist")
        end
        -- check model id dulplicate
        local modelExist = utils.find(function(model) return model.id == aiModel.id end, AIModelList)
        if modelExist then
            -- Update Model
            for k, v in pairs(aiModel) do
                modelExist[k] = v
            end
            return
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
        assert(requestData.aiModelID and requestData.params, "Data Item Nil")
        -- check request data item type
        -- remark: let real ai server do the data struct check
        assert(type(requestData.params) == "table", "Params Type Error")
        -- check ai model exist
        local aiModel = utils.find(function(model) return model.id == requestData.aiModelID end, AIModelList)
        assert(aiModel, "Model Not Exist")
        -- find supported and unbusy gpu
        local gpu = utils.find(
            function(gpu)
                local modelSupport = utils.find(
                    function(model) return model == gpu.gpumodel end, aiModel.supportedGPUModel
                )
                return not gpu.busy and modelSupport ~= nil
            end, GPUList
        )
        assert(gpu, "No Available GPU")
        -- TODO: sort by gpu price
        -- check token balance, if has no balance, send 200 free credits
        SendFreeCredits(msg.From)
        assert(bint(MarketBalances[msg.From]) >= bint(gpu.price), "Insufficient Balance")
        MarketBalances[msg.From] = bintutils.subtract(MarketBalances[msg.From], gpu.price)
        
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
            RequestParams = requestData.params,
            Metadata = {}
        }
        -- find all X-[] fields in requestData and pass into AITask.Metadata
        for key, value in pairs(requestData) do
            if key:match("^X%-.+") then
                AITask.Metadata[key] = value
            end
        end
        Handlers.utils.reply("Text-To-Image Successfully: " .. requestData.aiModelID .. " GPU " .. gpu.id)(msg)
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
      assert(record, "Record Not Exist")
      -- check request record status
      assert(record.Status == "pending", "Record Status Not Pending")
      -- check gpu owner match
      assert(record.Recipient == msg.Owner, "Owner Not Match")
      -- check gpu busy: TODO: single thread -> multi thread
        local gpu = utils.find(function(gpu) return gpu.id == record.GPUID end, GPUList)
        assert(gpu, "GPU Not Exist")
        assert(not gpu.busy, "GPU Busy")

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
        assert(record, "Record Not Exist")
        -- check owner match
        assert(record.Recipient == msg.Owner, "Owner Not Match")
        -- check status
        assert(record.Status == "processing", "Record Status Not Processing")
        -- check response error
        if data.code ~= 200 then
            record.ResponseError = data.error
            -- check token balance
            MarketBalances[record.From] = bintutils.subtract(MarketBalances[record.From], record.Price)
            -- return money to user
            MarketBalances[record.Recipient] = bintutils.add(MarketBalances[record.Recipient], record.Price)
            resetRequestRecord(data.taskID)
            record.Status = "failed"
            Handlers.utils.reply("Response Error" .. data.taskID)(msg)
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
            data = data.data,
            metadata = record.Metadata
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

Handlers.add("Get-AI-Task", Handlers.utils.hasMatchingTag("Action", "Get-AI-Task"), function(msg)
    local req = JSONDecode(msg.Data)
    assert(type(req.taskID) == "string", "Task ID is required!")
    local task = AITask[req.taskID]
    assert(task, "Task Not Exist")
    Handlers.utils.reply(json.encode(task))(msg)
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