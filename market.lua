require("token")
local json = require("json")
local utils = require('utils')

GPUModelList = GPUModelList or {}

Handlers.add(
    "Register-GPU-Model",
    Handlers.utils.hasMatchingTag("Action", "Register-GPU-Model"),
    function(msg)
        local gpuModel = json.decode(msg.Data)
        -- check gpu model id dulplicate
        for _, gpuModel in ipairs(GPUModelList) do
            if gpuModel == gpuModel then
                Handlers.utils.reply("[Error] [400] " .. "Register GPU Model " .. gpuModel .. "Model ID Duplicate")
                return
            end
        end
        table.insert(GPUModelList, gpuModel)
        Handlers.utils.reply("Register GPU Model Successfully " .. gpuModel)
    end
)

GPUList = GPUList or {}

Handlers.add(
    "Register-GPU",
    Handlers.utils.hasMatchingTag("Action", "Register-GPU"),
    function(msg)
        local gpu = json.decode(msg.Data)
        -- check gpu data item nil
        if not gpu.id or not gpu.endpoint or not gpu.gpumodel or not gpu.price then
            Handlers.utils.reply("[Error] [400] " .. "Register GPU " .. gpu.id .. "Data Item Nil")
            return
        end
        -- todo: check gpu data item type
        -- check gpu id dulplicate
        for _, gpu in ipairs(GPUList) do
            if gpu.id == gpu.id then
                Handlers.utils.reply("[Error] [400] " .. "Register GPU " .. gpu.id .. "ID Duplicate")
                return
            end
        end
        -- check gpu model
        local modelExist = utils.find(function(model) return model == gpu.gpumodel end, GPUModelList)
        if not modelExist then
            Handlers.utils.reply("[Error] [400] " .. "Register GPU " .. gpu.id .. "Model Not Exist")
            return
        end
        -- add busy flag and owner
        gpu.busy = false
        gpu.owner = msg.From
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
            Handlers.utils.reply("[Error] [400] " .. "Register AI Model " .. aiModel.id .. "Data Item Nil")
            return
        end
        -- check model data item type
        if type(aiModel.supportedGPUModel) ~= "table" then
            Handlers.utils.reply("[Error] [400] " ..
            "Register AI Model " .. aiModel.id .. "Supported GPU Model Type Error")
            return
        end
        -- check model id dulplicate
        local modelExist = utils.find(function(model) return model.id == aiModel.id end, AIModelList)
        if modelExist then
            Handlers.utils.reply("[Error] [400] " .. "Register AI Model " .. aiModel.id .. "ID Duplicate")
            return
        end
        -- check supported model exist
        for _, supportedModel in ipairs(aiModel.supportedGPUModel) do
            -- check supportedModel type
            if type(supportedModel) ~= "string" then
                Handlers.utils.reply("[Error] [400] " ..
                "Register AI Model " .. aiModel.id .. "Supported Model Type Error")
                return
            end
            local modelExist = utils.find(function(model) return model == supportedModel end, GPUModelList)
            if not modelExist then
                Handlers.utils.reply("[Error] [400] " ..
                "Register AI Model " .. aiModel.id .. "Supported Model Not Exist")
                return
            end
        end
        table.insert(AIModelList, aiModel)
        Handlers.utils.reply("Register Model Successfully " .. aiModel.id)
    end
)

local AITask = AITask or {}

-- Text-To-Image
-- Request Data: {"aiModelID":"xxx","params": {}}
Handlers.add(
    "Text-To-Image",
    Handlers.utils.hasMatchingTag("Action", "Text-To-Image"),
    function(msg)
        local requestData = json.decode(msg.Data)
        -- check request data item nil
        if not requestData.aiModelID or not requestData.params then
            Handlers.utils.reply("[Error] [400] " .. "Text-To-Image " .. requestData.aiModelID .. "Data Item Nil")
            return
        end
        -- check request data item type
        -- remark: let real ai server do the data struct check
        if type(requestData.params) ~= "table" then
            Handlers.utils.reply("[Error] [400] " .. "Text-To-Image " .. requestData.aiModelID .. "Params Type Error")
            return
        end
        -- check ai model exist
        local aiModel = utils.find(function(model) return model.id == requestData.aiModelID end, AIModelList)
        if not aiModel then
            Handlers.utils.reply("[Error] [400] " .. "Text-To-Image " .. requestData.aiModelID .. "Model Not Exist")
            return
        end
        -- find supported and unbusy gpu
        local gpu = utils.find(
            function(gpu)
                return not gpu.busy and utils.find(function(model) return model == gpu.gpumodel end, aiModel.supportedGPUModel)
            end, GPUList
        )
        if not gpu then
            Handlers.utils.reply("[Error] [403] " .. "Text-To-Image " .. requestData.aiModelID .. "No Available GPU")
            return
        end
        -- todo: sort by gpu price
        -- check token balance
        -- local balance = Balances[msg.From] or 0
        -- if balance < gpu.price then
        --     Handlers.utils.reply("[Error] [403] " .. "Text-To-Image " .. requestData.aiModelID .. "Insufficient Balance")
        --     return
        -- end
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
        Handlers.utils.reply("Text-To-Image " .. requestData.aiModelID .. "GPU " .. gpu.id)
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
Handlers.add(
  "Accept-Task",
  Handlers.utils.hasMatchingTag("Action", "Accept-Task"),
  function(msg)
      local data = json.decode(msg.Data)
      local record = AITask[data.taskID]
      -- check request record exist
      if not record then
          Handlers.utils.reply("[Error] [404] " .. "Accept-Task " .. data.taskID .. "Record Not Exist")
          return
      end
      -- check request record status
      if record.Status ~= "pending" then
          Handlers.utils.reply("[Error] [403] " .. "Accept-Task " .. data.taskID .. "Status Not Pending")
          return
      end
      -- check gpu owner match
      if record.Recipient ~= msg.From then
          Handlers.utils.reply("[Error] [403] " .. "Accept-Task " .. data.taskID .. "Owner Not Match")
          return
      end
      -- set request record status
      record.Status = "processing"
      Handlers.utils.reply("Accept-Task " .. data.taskID)
  end
)

local function resetRequestRecord(taskID)
    -- set gpu unbusy
    local gpu = utils.find(function(gpu) return gpu.id == AITask[taskID].GPUID end, GPUList)
    gpu.busy = false
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
            Handlers.utils.reply("[Error] [404] " .. "Receive-Response " .. data.taskID .. "Record Not Exist")
            return
        end
        -- check owner match
        if record.Recipient ~= msg.From then
            Handlers.utils.reply("[Error] [403] " .. "Receive-Response " .. data.taskID .. "Owner Not Match")
            return
        end
        -- check response error
        if data.code ~= 200 then
            record.ResponseError = data.error
            resetRequestRecord(data.taskID)
            Handlers.utils.reply("[Error] [500] " .. "Receive-Response " .. data.error)
            return
        end
        -- transfer token
        -- Send({ Target = ao.id, Action = "Transfer", Recipient = record.Recipient, Quantity = record.Price, From = record.From})
        -- set base64 img data
        record.ResponseData = data.data
        resetRequestRecord(data.taskID)
        Send({ Target = record.From, Action = "Text-To-Image-Response", Data = json.encode({
            taskID = data.taskID,
            data = data.data
        })})
        print("Data: " .. json.encode(msg))
    end
)

Handlers.add("Get-GPU-List", Handlers.utils.hasMatchingTag("Action", "Get-GPU-List"), function(msg)
  local UserGPUList = {}
    for _, gpu in pairs(GPUList) do
        if gpu.owner == msg.From then
            table.insert(UserGPUList, gpu)
        end
    end
    Handlers.utils.reply(json.encode(GPUList))
end)

Handlers.add("Get-GPU-Model-List", Handlers.utils.hasMatchingTag("Action", "Get-GPU-Model-List"), function(msg)
    Handlers.utils.reply(json.encode(GPUModelList))
end)

Handlers.add("Get-AI-Model-List", Handlers.utils.hasMatchingTag("Action", "Get-AI-Model-List"), function(msg)
    Handlers.utils.reply(json.encode(AIModelList))
end)

Handlers.add("Get-AI-Task-List", Handlers.utils.hasMatchingTag("Action", "Get-AI-Task-List"), function(msg)
    local UserTaskList = {}
    for _, task in pairs(AITask) do
        if task.From == msg.From then
            table.insert(UserTaskList, task)
        end
    end
    Handlers.utils.reply(json.encode(AITask))
end)

Handlers.add("Get-AI-Pending-Task-List", Handlers.utils.hasMatchingTag("Action", "Get-User-Balance"), function(msg)
    local pendingTaskList = {}
    for _, task in pairs(AITask) do
        if task.Status == "pending" then
            table.insert(pendingTaskList, task)
        end
    end
    Handlers.utils.reply(json.encode(pendingTaskList))
end)

Handlers.add("Get-AI-Processing-Task-List", Handlers.utils.hasMatchingTag("Action", "Get-User-Balance"), function(msg)
    local processingTaskList = {}
    for _, task in pairs(AITask) do
        if task.Status == "processing" then
            table.insert(processingTaskList, task)
        end
    end
    Handlers.utils.reply(json.encode(processingTaskList))
end)