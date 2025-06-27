import { existsSync, readFileSync } from 'node:fs';
import { Database, select } from './sqlite.js';

let SKIP = new Set();
if (existsSync('skip.txt')) {
  const ids = readFileSync('skip.txt', 'utf-8').split('\n');
  SKIP = new Set(ids);
}

function decode(binary) {
  const floatArray = [];
  for (let i = 0; i < binary.length; i += 4) {
    floatArray.push(binary.readFloatLE(i));
  }
  return floatArray;
}

export async function* readEmbeddings(filePath) {
  const db = new Database(filePath);
  const query = 'SELECT id, embedding FROM embeddings';

  for await (const { id, embedding } of select(db, query)) {
    if (!SKIP.has(id)) {
      yield { id: id, embedding: decode(embedding) };
    }
  }
}
