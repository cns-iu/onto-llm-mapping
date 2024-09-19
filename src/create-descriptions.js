import { closeSync, openSync, readFileSync, writeSync } from 'fs';
import Papa from 'papaparse';

const INPUT_CSV = process.argv[2];
const OUTPUT_CSV = process.argv[3];

const results = openSync(OUTPUT_CSV, 'w');
writeSync(results, 'id,content\n');

const data = Papa.parse(readFileSync(INPUT_CSV).toString(), { skipEmptyLines: true, header: true }).data;
for (const row of data) {
  const expanded = `${row.name}${row.aka ? `also known as ${row.aka}` : ''} ${row.description}`
    .replace(/\s+/g, ' ')
    .trim();
  writeSync(results, Papa.unparse([[row.id, expanded]]) + '\n');
}
closeSync(results);
