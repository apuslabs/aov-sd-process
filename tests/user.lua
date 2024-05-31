local json = require("json")

_Apus_Process_ID = "1x2lsMZVr67txPJVZ0OQT7qOGYVP-w9EWqcfF57d0Dc"

Handlers.add("Text-To-Image", Handlers.utils.hasMatchingTag("Action", "Text-To-Image"), function(msg)
    local requestData = {}
    requestData.aiModelID = "096875a5-ed88-47ae-b420-895da26b4c53"
    requestData.params = {
      prompt = "hello world",
      negative_prompt = "",
      sampler_name = "DPM++ 2M Karras",
      batch_size = 1,
      n_iter = 1,
      steps = 50,
      cfg_scale = 7,
      width = 512,
      height = 512
    }
    ao.send({
        Target = _Apus_Process_ID,
        Tags = { Action = "Text-To-Image" },
        Data = json.encode(requestData)
    })
  end
)

Handlers.add("MarketBalances", Handlers.utils.hasMatchingTag("Action", "MarketBalances"), function(msg)
    ao.send({
        Target = _Apus_Process_ID,
        Tags = { Action = "MarketBalances" },
    })
end)

Handlers.add("Text-To-Image-Response", Handlers.utils.hasMatchingTag("Action", "Text-To-Image-Response"), function (msg)
  local data = json.decode(msg.Data)
  print(data)
end)