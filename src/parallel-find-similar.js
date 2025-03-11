import { createWriteStream } from 'node:fs';
import { cpus } from 'node:os';
import { writeEmbeddingSimilarities } from './utils/embedding-similarities.js';
import { readEmbeddings } from './utils/embeddings.js';

const SOURCE_EMBEDDINGS = process.argv[2];
const TARGET_EMBEDDINGS = process.argv[3];
const OUTPUT_CSV = process.argv[4];
const TOP_RESULTS = 10;
const NUM_CORES = cpus().length;

await writeEmbeddingSimilarities(
  readEmbeddings(SOURCE_EMBEDDINGS),
  readEmbeddings(TARGET_EMBEDDINGS),
  createWriteStream(OUTPUT_CSV),
  TOP_RESULTS,
  NUM_CORES
);
