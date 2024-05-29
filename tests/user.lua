local json = require("json")

_Apus_Process_ID = "0"

Handlers.add("Text-To-Image", Handlers.utils.hasMatchingTag("Action", "Text-To-Image"), function(msg)
    local requestData = {}
    requestData.aiModelID = ""
    requestData.params = {}
    local reply = ao.send({
        Target = _Apus_Process_ID,
        Tags = { Action = "Text-To-Image" },
        Data = json.encode(requestData)
    })
  end
)

Handlers.add("Text-To-Image-Response", Handlers.utils.hasMatchingTag("Action", "Text-To-Image-Response"), function (msg)
  local data = json.decode(msg.Data)
  print(data)
end)