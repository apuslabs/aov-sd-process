import * as dotenv from 'dotenv'
dotenv.config()

const PROCESS_ID = process.env.PROCESS_ID!

import { readFileSync, writeFileSync } from "fs";
import { join } from "path"
import * as aoconnect from "@permaweb/aoconnect";
import { randomUUID } from 'crypto';

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
    console.error(e)
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
    console.error(e);
    return {
      Output: null,
      Messages: null,
      Spawns: [],
      Error: e
    }
  }
}

async function main() {
  init()
  const result = await messageResult({ Action: "Get-AI-Task"}, { "taskID": "gMx9mj8C" })
  console.log(result)
}

main()