import { closeSync, openSync, writeSync } from 'fs';
import Papa from 'papaparse';
import { readCsv } from './utils.js';

const INPUT_CSV = process.argv[2];
const OUTPUT_CSV = process.argv[3];

const results = openSync(OUTPUT_CSV, 'w');
writeSync(results, 'id,content\n');

for await (const row of readCsv(INPUT_CSV)) {
  const expanded = `${row.name}${row.aka ? ` also known as ${row.aka}` : ''} ${row.description}`
    .replace(/\s+/g, ' ')
    .trim();
  writeSync(results, Papa.unparse([[row.id, expanded]]) + '\n');
}
closeSync(results);
