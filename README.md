# How to start

## Start Token Process

```shell
aos apus-gpu-devnet-token

.load-blueprint token
```

## Start Market Process

```shell
aos apus-gpu-devnet-market

.load helper.lua
.load market.lua
```

# How to use

## 🔑 Prerequisites

- Understanding of the [ao](https://docs.0rbit.co/concepts/what-is-ao) and [aos](https://docs.0rbit.co/concepts/what-is-aos).
- aos installed on your system.
- Any Code Editor (VSCode, Sublime Text, etc)

## 🛠️ Let's Start Building

### Initialize the Project

Create a new file named `Apus-SD-Request.lua` in your project directory.

`touch Apus-SD-Request.lua`

### Initialize the Variables

```lua
local json = require("json")
 
_APUS = "1x2lsMZVr67txPJVZ0OQT7qOGYVP-w9EWqcfF57d0Dc"
_APUS_TOKEN = "jZrx_R1zuvUq7TVLd8fyUHgYu_N4ZtXw5KsP743ZHtY"
 
local RequestParams = {
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
```

### Make the Request

The following code contains the Handler that will make the SD Inference request using example prompt

```lua
Handlers.add("Text-To-Image", Handlers.utils.hasMatchingTag("Action", "Text-To-Image"), function(msg)
    ao.send({
        Target = _APUS,
        Tags = { Action = "Text-To-Image" },
        Data = json.encode({
          aiModelID = "096875a5-ed88-47ae-b420-895da26b4c53",
          params = RequestParams,
          ["X-ID"] = "xxxxxxx01",
        })
    })
  end
)
```

Breakdown of the above code:

- `Handlers.add` is used to add a new handler to the ao process.

- **Text-To-Image** is the name of the handler.

- `Handlers.utils.hasMatchingTag` is a function that checks if the incoming message has the matching tag same as the Text-To-Image.

- `function(msg)` is the function executed when the handler is called.

- `ao.send` is the function that takes several tags as the arguments and creates a message on the ao:

| Tag | Description |
| --- | --- |
| Target | The processId of the recipient. In this case, it's the apus market processId. |
| Action | The tag that defines the handler to be called in the recipient process. In this case it's Text-To-Image |
| aiModelID | The model id to be used when generating images. |
| params | The params to be used when generating images. refer params Docs in the sd params part. |
| X- | The params which will be passed into the Response |

### Receive Data

The following code contains the Handler that will receive the data from the Apus market process and print it.

```lua
Handlers.add("Text-To-Image-Response", Handlers.utils.hasMatchingTag("Action", "Text-To-Image-Response"), function (msg)
  local data = json.decode(msg.Data)
  print(data)
end)
```

Breakdown of the above code:

- `Handlers.add` is used to add a new handler to the ao process.
- `Text-To-Image-Response` is the name of the handler.
- `Handlers.utils.hasMatchingTag` is a function that checks if the incoming message has the matching tag same as the Text-To-Image-Response.
- `function(msg)` is the function executed when the handler is called.
  - `json.decode` is used to decode the JSON data received.
  - `print` shows the table data in aos console.

## 🏃 Run the process

### Create a new process and load the script

```shell
aos apussdrequest --load Apus-SD-Request.lua
```

The above command will create a new process with the name 0rbitGetRequest and load `Apus-SD-Request.lua` into it.

### Call the Handler

Call the handler, who will create a request for the apus market process.

```lua
Send({ Target= ao.id, Action="Text-To-Image" })
```

### Check the Data

Upon the result is returned, console print the result.

## Stable Diffusion Params

### How to use another model

you can query all supported models by run

```lua
Send({ Target = _APUS, Action = "Get-AI-Model-List" })
```

then, check AI Model List in your Inbox `Inbox[#inbox].Data`, for example

```json
[{"name":"sd_xl_base_1.0.safetensors","storageUrl":"","supportedGPUModel":["RTX 4090"],"id":"096875a5-ed88-47ae-b420-895da26b4c53"}]
```

using this model by updating the `aiModelId` in the Request Data

```lua
-- ao.send({
--     Target = _APUS,
--     Tags = { Action = "Text-To-Image" },
--     Data = json.encode({
       aiModelID = "096875a5-ed88-47ae-b420-895da26b4c53",
--       params = RequestParams,
--       ["X-ID"] = "xxxxxxx01",
--     })
-- })
```

### What's the params?

You can refer [stable-diffusion-webui](https://github.com/AUTOMATIC1111/stable-diffusion-webui) for api detail.
or you can find help in discord.

```json
{
  "prompt": "",
  "negative_prompt": "",
  "styles": [
    "string"
  ],
  "seed": -1,
  "subseed": -1,
  "subseed_strength": 0,
  "seed_resize_from_h": -1,
  "seed_resize_from_w": -1,
  "sampler_name": "string",
  "batch_size": 1,
  "n_iter": 1,
  "steps": 50,
  "cfg_scale": 7,
  "width": 512,
  "height": 512,
  "restore_faces": true,
  "tiling": true,
  "do_not_save_samples": false,
  "do_not_save_grid": false,
  "eta": 0,
  "denoising_strength": 0,
  "s_min_uncond": 0,
  "s_churn": 0,
  "s_tmax": 0,
  "s_tmin": 0,
  "s_noise": 0,
  "override_settings": {},
  "override_settings_restore_afterwards": true,
  "refiner_checkpoint": "string",
  "refiner_switch_at": 0,
  "disable_extra_networks": false,
  "comments": {},
  "enable_hr": false,
  "firstphase_width": 0,
  "firstphase_height": 0,
  "hr_scale": 2,
  "hr_upscaler": "string",
  "hr_second_pass_steps": 0,
  "hr_resize_x": 0,
  "hr_resize_y": 0,
  "hr_checkpoint_name": "string",
  "hr_sampler_name": "string",
  "hr_prompt": "",
  "hr_negative_prompt": "",
  "sampler_index": "Euler",
  "script_name": "string",
  "script_args": [],
  "send_images": true,
  "save_images": false,
  "alwayson_scripts": {}
}
```

## 💰Apus Token

You will get **free 200 tokens** for test every account.

### Charge

```shell
Send({ Target = _APUS_TOKEN, Action = "Transfer", Recipient = _APUS, Quantity = "100" })
```

if success, you will receive Deposit-Receiption in your Inbox like
```

```

### Check Balance

```shell
Send({ Target = _APUS, Action = "MarketBalances" })
```