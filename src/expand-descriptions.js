import { closeSync, openSync, readFileSync, writeSync } from 'fs';
import Papa from 'papaparse';
import sh from 'shelljs';

const INPUT_CSV = process.argv[2];
const OUTPUT_CSV = process.argv[3];
const MODEL = process.env['LLM_MODEL'];
const MODEL_OPTS = process.env['LLM_MODEL_OPTS'] ?? '';
const TEMPLATE = process.env['LLM_EXPAND_TEMPLATE'] ?? 'term-description';

const results = openSync(OUTPUT_CSV, 'w');
writeSync(results, 'id,content\n');

const data = Papa.parse(readFileSync(INPUT_CSV).toString(), { skipEmptyLines: true, header: true }).data;
for (const row of data) {
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
