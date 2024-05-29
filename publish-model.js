#!/usr/bin/env node
import fs from "fs";
import { Readable } from 'stream';
import { TurboFactory, ArweaveSigner } from '@ardrive/turbo-sdk';

// Helper function to read file in chunks
function readFileInChunks(filePath, chunkSize) {
  const fileBuffer = fs.readFileSync(filePath);
  const chunks = [];
  for (let offset = 0; offset < fileBuffer.length; offset += chunkSize) {
      chunks.push(fileBuffer.slice(offset, Math.min(offset + chunkSize, fileBuffer.length)));
  }
  return chunks;
}

// Helper function to upload a file chunk
async function uploadChunk(turbo, chunkData, previousId,  extraTags = []) {
  let tags = [
      { name: 'Content-Type', value: 'application/octet-stream' },
      { name: 'Data-Protocol', value: 'Onchain-SD' },
      { name: 'Type', value: 'Model-Chunk' },
      { name: 'Next', value: previousId },
      ...extraTags
  ].filter(tag => tag.value != null);

  try {
      const { id } = await turbo.uploadFile({
          fileStreamFactory: () => Readable.from(chunkData),
          fileSizeFactory: () => chunkData.length,
          dataItemOpts: {
              tags: tags
          }
      });
      return id;
  } catch (error) {
      console.error(`Failed to upload chunk:`, error);
      exit(-1);
  }
}

// Parsing command-line arguments and displaying help
function parseArgs(defaults) {
    const args = {};
    let argFound = false;
    process.argv.slice(2).forEach((val, index, array) => {
        if (val.startsWith('-')) {
            args[val] = array[index + 1] || true;
            argFound = true;
        }
    });

    if (!argFound || args['-h'] || args['--help']) {
        displayHelp();
        process.exit(0);
    }

    return { ...defaults, ...args };
}

// Help message display function
function displayHelp() {
    console.log(`
Usage: publish-model [options]
Options:
  -w [path]       Path to the Arweave wallet JSON file (default from ARWEAVE_WALLET env)
  -m [path]       Path to the model binary file (default: ./model.bin)
  -s [size]       Chunk size in megabytes (default: 100)
  -b [url]        Base URL for the bundler (default: https://turbo.ardrive.io)
  -h, --help      Display this help message and exit
Example:
  publish-model -m path/to/model.bin -s 10 -w path/to/wallet.json -b https://example.com
  `);
}

async function main() {
    const defaults = {
        '-m': './model.bin',
        '-s': '100', // Default chunk size in MB
        '-w': process.env.ARWEAVE_WALLET || './wallet.json', // Default wallet path
        '-b': 'https://turbo.ardrive.io' // Default base URL for the Turbo node
    };
    const args = parseArgs(defaults);
    const modelPath = args['-m'];
    const chunkSize = parseInt(args['-s'], 10) * 1024 * 1024; // Convert MB to bytes
    const walletPath = args['-w'];
    const privateKey = JSON.parse(fs.readFileSync(walletPath, 'utf-8'));

    const signer = new ArweaveSigner(privateKey);
    const turbo = TurboFactory.authenticated({ signer });

    // check balance
    // get the cost of uploading the file
    const fileSize = fs.statSync(modelPath).size;
    const [{ winc: fileSizeCost }] = await turbo.getUploadCosts({
      bytes: [fileSize],
    });
    const { winc: balance } = await turbo.getBalance();
    if (balance < fileSizeCost) {
      const { url } = await turbo.createCheckoutSession({
        amount: fileSizeCost,
        owner: signer.publicKey.toString(),
      });
      open(url);
      return;
    }

    // Process the model file in chunks
    const modelChunks = readFileInChunks(modelPath, chunkSize);

    for (let i = modelChunks.length - 1; i >= 1; i--) {
        lastId = await uploadChunk(turbo, modelChunks[i], lastId);
        console.log(`Uploaded chunk #${i-1}...`);
    }

    lastId = await uploadChunk(turbo, modelChunks[0], lastId,
        [
            { name: 'Model-Size', value: String(modelChunks.reduce((acc, chunk) => acc + chunk.length, 0)) },
        ]);

    console.log(`Upload complete. Last Model Chunk ID: ${lastId}.`);
}

main().catch(console.error);
