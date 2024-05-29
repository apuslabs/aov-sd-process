#!/usr/bin/env node
import fs from "fs";
import axios from "axios";
import { TurboFactory, ArweaveSigner } from '@ardrive/turbo-sdk';

// Helper function to download a file chunk
async function downloadChunk(turbo, chunkId) {
    try {
        const { data } = await turbo.downloadFile(chunkId);
        return data;
    } catch (error) {
        console.error(`Failed to download chunk (ID: ${chunkId}):`, error);
        process.exit(-1);
    }
}

// Helper function to get chunk metadata
async function getChunkMetadata(turbo, chunkId) {
    try {
        const { tags } = await turbo.getMetadata(chunkId);
        const nextTag = tags.find(tag => tag.name === 'Next');
        return nextTag ? nextTag.value : null;
    } catch (error) {
        console.error(`Failed to get metadata for chunk (ID: ${chunkId}):`, error);
        process.exit(-1);
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
Usage: download-model [options]
Options:
  -i [id]         ID of the first chunk of the model
  -o [path]       Output path for the model binary file (default: ./downloaded_model.bin)
  -b [url]        Base URL for the bundler (default: https://turbo.ardrive.io)
  -h, --help      Display this help message and exit
Example:
  download-model -i chunkId -o path/to/output.bin -b https://example.com
  `);
}

async function main() {
    const defaults = {
        '-o': './downloaded_model.bin', // Default output file path
        '-b': 'https://turbo.ardrive.io' // Default base URL for the Turbo node
    };
    const args = parseArgs(defaults);
    const firstChunkId = args['-i'];
    const outputPath = args['-o'];
    const baseUrl = args['-b'];

    if (!firstChunkId) {
        console.error("Error: First chunk ID (-i) is required.");
        process.exit(-1);
    }

    const turbo = TurboFactory.create({ baseUrl });

    let currentChunkId = firstChunkId;
    const chunks = [];

    while (currentChunkId) {
        const chunkData = await downloadChunk(turbo, currentChunkId);
        chunks.push(chunkData);
        currentChunkId = await getChunkMetadata(turbo, currentChunkId);
    }

    fs.writeFileSync(outputPath, Buffer.concat(chunks));
    console.log(`Download complete. Model saved to: ${outputPath}`);
}

main().catch(console.error);