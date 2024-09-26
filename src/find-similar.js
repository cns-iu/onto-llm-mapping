import { closeSync, openSync, readFileSync, writeSync } from 'fs';
import Papa from 'papaparse';
import sh from 'shelljs';

const SOURCE_CSV = process.argv[2];
const TARGET_CSV = process.argv[3];
const OUTPUT_CSV = process.argv[4];
const EMBED_MODEL = process.env['EMBED_MODEL'];
const MINIMUM_SCORE = 0.5;
const DB = `${OUTPUT_CSV}.db`;

sh.rm('-f', DB);
sh.exec(`llm embed-multi default -m ${EMBED_MODEL} -d ${DB} --format csv ${TARGET_CSV}`);

const results = openSync(OUTPUT_CSV, 'w');
writeSync(results, 'source,target,score\n');
const data = Papa.parse(readFileSync(SOURCE_CSV).toString(), { skipEmptyLines: true, header: true }).data;
for (const row of data) {
  console.log('source id', row.id);
  const simStr = sh.exec(`echo "${row.content}" | llm similar default -d ${DB} -i -`).stdout.toString().trim();
  const sims = simStr
    .split('\n')
    .filter((s) => !s.startsWith('Error'))
    .map((line) => {
      try {
        const result = JSON.parse(line);
        return {
          source: row.id,
          target: result.id,
          score: result.score,
        };
      } catch (err) {
        console.log('Bad JSON:', line);
        return { score: 0 };
      }
    })
    .filter((s) => s.score > MINIMUM_SCORE);

  if (sims.length > 0) {
    writeSync(results, Papa.unparse(sims, { header: false, columns: ['source', 'target', 'score'] }) + '\n');
  }
}
closeSync(results);
