import * as dotenv from 'dotenv'
dotenv.config()

const PROCESS_ID = process.env.PROCESS_ID!
// const BASE_URL = "https://fb47e7743187cc02-3001-proxy.us-south-1.infrai.com"
const BASE_URL = "http://localhost:3001"

import { readFileSync, writeFileSync } from "fs";
import { join } from "path"
import axios from 'axios'
import * as aoconnect from "@permaweb/aoconnect";
import { randomUUID } from 'crypto';

import { logger } from './logger'

let wallet: string;
let id: string;

const modelMap: Record<string, {
  name: string
  canrun: boolean
}> = {}

function init() {
  wallet = JSON.parse(
    readFileSync(join(__dirname, "../config/wallet.json")).toString().trim(),
  );
  
  try {
    id = readFileSync(join(__dirname, "../config/id")).toString().trim();
  } catch (e) {
    id = randomUUID();
    writeFileSync(join(__dirname, "../config/id"), id);
  }
  return {
    wallet,
    id,
  }
}

async function messageResult(tags: Record<string, string>, data: any) {
  try {
    const messageId = await aoconnect.message({
      process: PROCESS_ID,
      tags: Object.entries(tags).map(([name, value]) => ({ name, value })),
      signer: aoconnect.createDataItemSigner(wallet),
      data: JSON.stringify(data),
    });
  
    const messageReturn = await aoconnect.result({
      // the arweave TXID of the message
      message: messageId,
      // the arweave TXID of the process
      process: PROCESS_ID,
    });

    if (messageReturn.Messages != null) {
      if (messageReturn.Messages[0] && messageReturn.Messages[0]?.Data?.includes("[Error]")) {
        throw new Error(messageReturn.Messages[0].Data)
      } else {
        return messageReturn
      }
    }
    throw new Error(messageReturn.Error)
  } catch (e) {
    logger.error(e)
    return {
      Output: null,
      Messages: null,
      Spawns: [],
      Error: e
    }
  }
}

async function dryrunResult(tags: Record<string, string>, data: any) {
  try {
    const dryrunResult =  await aoconnect.dryrun({
      process: PROCESS_ID,
      signer: aoconnect.createDataItemSigner(wallet),
      tags: Object.entries(tags).map(([name, value]) => ({ name, value })),
      data: JSON.stringify(data)
    });
    if (dryrunResult.Messages != null) {
      if (dryrunResult.Messages[0] && dryrunResult.Messages[0].Data.includes("[Error]")) {
        throw new Error(dryrunResult.Messages[0].Data)
      } else {
        return dryrunResult
      }
    }
    throw new Error(dryrunResult.Error)
  } catch (e) {
    logger.error(e);
    return {
      Output: null,
      Messages: null,
      Spawns: [],
      Error: e
    }
  }
}

async function fetchTasks() {
  const { Messages } = await dryrunResult({
    Action: "Get-AI-Task-List"
  }, {
    GPUID: id,
    Status: "pending"
  })
  if (Messages != null) {
    const tasks = JSON.parse(Messages[0].Data)
    return tasks
  }
  return []
}

async function acceptTask(task: any) {
  await messageResult({ Action: "Accept-Task" }, {
    taskID: task.id,
  })
}

function text2img(task: any) {
  const canrun = modelMap?.[task.AIModelID]?.canrun
  if (!canrun) {
    throw new Error("Model not available")
  }
  return axios.post<{
    images: string[]
  }>(`${BASE_URL}/sdapi/v1/txt2img`, {
    ...task.RequestParams,
    // https://github.com/AUTOMATIC1111/stable-diffusion-webui/discussions/3734
    override_settings: {
      sd_model_checkpoint: modelMap[task.AIModelID]?.name
    }
  })
}

function refreshCheckpoints() {
  return axios.post(`${BASE_URL}/sdapi/v1/refresh-checkpoints`)
}

function getSDModels() {
  return axios.get(`${BASE_URL}/sdapi/v1/sd-models`).then(res => res.data)
}

async function getAOModels() {
  const { Messages, Error } = await dryrunResult({ Action: "Get-AI-Model-List" }, {})
  if (Error != null) {
    logger.error(Error)
  } else {
    return JSON.parse(Messages?.[0].Data ?? "[]")
  }
}

async function receiveTask(task: any, code: number, res: any) {
  const resultRet = await messageResult({ Action: "Receive-Response" }, {
    taskID: task.id,
    code,
    data: res,
  })
  logger.debug(JSON.stringify(resultRet))
}

async function processTask() {
  const taskList: Record<string, any> = await fetchTasks()
  const tasks = Object.entries(taskList).map(([key, value]) => Object.assign(value, {id: key}))
  logger.info("To Process Task " + tasks.length)
  if (tasks.length) {
    await acceptTask(tasks[0])
    logger.info("Accepted Task " + tasks[0]?.id)
    try {
      logger.debug("Processing Task " + JSON.stringify(tasks[0]))
      const text2imgResponse = await text2img(tasks[0])
      logger.info("Image Generated " + text2imgResponse.status)
      await receiveTask(tasks[0], text2imgResponse.status, text2imgResponse.data)
      return [
        tasks[0],
        text2imgResponse.status,
      ] as const
    } catch (e) {
      logger.error("Process Error: " + (e instanceof Error) ? (e as Error).message : JSON.stringify(e))
      await receiveTask(tasks[0], 500, e)
    }
  }
}

async function refreshModel() {
  try {
    await refreshCheckpoints()
    const sdModels: any[] = await getSDModels()
    const aoModels: any[] = await getAOModels()
    for (const model of aoModels) {
      modelMap[model.id] = {
        name: model.name,
        canrun: sdModels.findIndex((sdModel) => sdModel.title === model.name) !== -1
      }
    }
    logger.debug("ModelMap: " + JSON.stringify(modelMap))
  } catch(e) {
    logger.error(e)
  }
}

async function intervalRefreshModel() {
  logger.info("Start Refresh Model Every 1 hour")
  refreshModel()
  setInterval(() => {
    refreshModel().then(() => {
      logger.info("Model Refreshed")
    }).catch((e) => {
      logger.error(e)
    })
  }, 3600000)
}

function intervalProcessTask() {
  logger.info("Start Process Task Every 2s")
  processTask().then((result) => {
    if (result != null) {
      logger.info(`Task ${result[0].id} processed with status ${result[1]}`)
    }
  }).catch((e) => {
    logger.error(e)
  }).finally(() => {
    setTimeout(intervalProcessTask, 2000)
  })
}

async function main() {
  init()
  logger.info("GPU ID " + id)
  intervalProcessTask()
  intervalRefreshModel()
}

main()