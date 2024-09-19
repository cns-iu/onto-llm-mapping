import { closeSync, openSync, readFileSync, writeSync } from 'fs';
import Papa from 'papaparse';
import sh from 'shelljs';

const INPUT_CSV = process.argv[2];
const OUTPUT_CSV = process.argv[3];

const results = openSync(OUTPUT_CSV, 'w');
writeSync(results, 'id,content\n');

const data = Papa.parse(readFileSync(INPUT_CSV).toString(), { skipEmptyLines: true, header: true }).data;
for (const row of data) {
  console.log(row);

  const expanded = sh
    .exec(
      // -o max_tokens 384
      `echo "${row.description}" | llm -t term-description -o num_predict 384 -p name "${row.name}"` +
        (row.aka ? ` -p aka "${row.aka}"` : ''),
      { silent: false }
    )
    .stdout.toString().replace(/\s+/g, ' ').trim();
    writeSync(results, Papa.unparse([[row.id, expanded]]) + '\n');
}
closeSync(results);
