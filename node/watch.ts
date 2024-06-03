import * as dotenv from 'dotenv'
dotenv.config()

const PROCESS_ID = process.env.PROCESS_ID!

import { readFileSync, writeFileSync } from "fs";
import { join } from "path"
import axios from 'axios'
import * as aoconnect from "@permaweb/aoconnect";
import { randomUUID } from 'crypto';

import { logger } from './logger'

let wallet: string;
let id: string;

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

async function text2img(task: any) {
  return axios.post<{
    images: string[]
  // }>('http://localhost:3001/sdapi/v1/txt2img', task)
  }>('https://af00460591bbc19d-3001-proxy.us-south-1.infrai.com/sdapi/v1/txt2img', task)
}

async function receiveTask(task: any, code: number, res: any) {
  const resultRet = await messageResult({ Action: "Receive-Response" }, {
    taskID: task.id,
    code,
    data: res,
  })
  logger.debug(resultRet)
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
      const text2imgResponse = await text2img(tasks[0].RequestParams)
      logger.info("Image Generated" + text2imgResponse.status)
      await receiveTask(tasks[0], text2imgResponse.status, text2imgResponse.data)
      return [
        tasks[0],
        text2imgResponse.status,
      ] as const
    } catch (e) {
      await receiveTask(tasks[0], 500, e)
    }
  }
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
}

main()