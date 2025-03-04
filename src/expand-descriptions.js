import { closeSync, openSync, writeSync } from 'fs';
import Papa from 'papaparse';
import sh from 'shelljs';
import { readCsv } from './utils.js';

const INPUT_CSV = process.argv[2];
const OUTPUT_CSV = process.argv[3];
const MODEL = process.env['LLM_MODEL'];
const MODEL_OPTS = process.env['LLM_MODEL_OPTS'] ?? '';
const TEMPLATE = process.env['LLM_EXPAND_TEMPLATE'] ?? 'term-description';

const results = openSync(OUTPUT_CSV, 'w');
writeSync(results, 'id,content\n');

for await (const row of readCsv(INPUT_CSV)) {
  console.log(row);

  const expanded = sh
    .exec(
      `echo "${row.description}" | llm -m ${MODEL} ${MODEL_OPTS} -t ${TEMPLATE} -p name "${row.name}"` +
        (row.aka ? ` -p aka "${row.aka}"` : ''),
      { silent: false }
    )
    .stdout.toString()
    .replace(/\s+/g, ' ')
    .trim();
  writeSync(results, Papa.unparse([[row.id, expanded]]) + '\n');
}
closeSync(results);
