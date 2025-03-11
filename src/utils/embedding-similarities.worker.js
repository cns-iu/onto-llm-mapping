import Papa from 'papaparse';
import { parentPort, workerData } from 'worker_threads';
import { cosineSim } from './cosine-similarity.js';

const { targets, topResults: TOP_RESULTS } = workerData;

parentPort.on('message', function (message) {
  if (message.terminate) {
    process.exit(0);
  } else {
    try {
      const { id, embedding } = message;

      let worstResult = 1;
      const topResults = [];
      for (const target of targets) {
        const score = cosineSim(embedding, target.embedding);
        if (topResults.length < TOP_RESULTS || !TOP_RESULTS) {
          worstResult = Math.min(worstResult, score);
        }
        if (score >= worstResult) {
          topResults.push([id, target.id, score]);
        }
      }

      const rows = topResults.sort((a, b) => b[2] - a[2]).slice(0, Math.min(topResults.length, TOP_RESULTS));
      const csvText = Papa.unparse(rows) + '\n';
      parentPort.postMessage(csvText);
    } catch (err) {
      parentPort.postMessage('');
      console.log('Unknown error processing embedding for', message);
      console.error(err);
    }
  }
});
