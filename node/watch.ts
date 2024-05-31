import * as dotenv from 'dotenv'
dotenv.config()

const PROCESS_ID = process.env.PROCESS_ID!

import { readFileSync, writeFileSync } from "fs";
import { join } from "path"
import axios from 'axios'
import {
  result,
  results,
  message,
  spawn,
  monitor,
  unmonitor,
  dryrun,
  createDataItemSigner,
} from "@permaweb/aoconnect";
import { randomUUID } from 'crypto';
import { text } from 'stream/consumers';

let wallet: string;
let id: string;

function init() {
  wallet = JSON.parse(
    readFileSync(join(__dirname, "../config/wallet.json")).toString(),
  );
  
  try {
    id = readFileSync(join(__dirname, "../config/id")).toString();
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
    const messageId = await message({
      process: PROCESS_ID,
      tags: Object.entries(tags).map(([name, value]) => ({ name, value })),
      signer: createDataItemSigner(wallet),
      data: JSON.stringify(data),
    });
  
    const messageReturn = await result({
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
    console.error(e);
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
    const dryrunResult =  await dryrun({
      process: PROCESS_ID,
      signer: createDataItemSigner(wallet),
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
    console.error(e);
    return {
      Output: null,
      Messages: null,
      Spawns: [],
      Error: e
    }
  }
}

async function fetchTasks(id: string) {
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
  }>('http://localhost:3001/sdapi/v1/txt2img', task)
}

async function receiveTask(task: any, code: number, res: any) {
  console.log("Receive Task", task.id, code, res)
  const { Messages, Output, Error } = await messageResult({ Action: "Receive-Response" }, {
    taskID: task.id,
    code,
    data: res,
  })
  console.log(Messages, Output, Error)
}

async function processTask() {
  const taskList: Record<string, any> = await fetchTasks(id)
  const tasks = Object.entries(taskList).map(([key, value]) => Object.assign(value, {id: key}))
  if (tasks.length) {
    await acceptTask(tasks[0])
    try {
      const text2imgResponse = await text2img(tasks[0])
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
  processTask().then((result) => {
    if (result != null) {
      console.log(`Task ${result[0].id} processed with status ${result[1]}`)
    }
  }).catch((e) => {
    console.error(e)
  }).finally(() => {
    setTimeout(intervalProcessTask, 2000)
  })
}

async function main() {
  init()
  intervalProcessTask()
}

main()