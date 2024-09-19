import { closeSync, openSync, readFileSync, writeSync } from 'fs';
import Papa from 'papaparse';
import sh from 'shelljs';
sh.config.silent = true;

const SOURCE_CSV = process.argv[2];
const TARGET_CSV = process.argv[3];
const SOURCE_CONTENT_CSV = process.argv[4];
const TARGET_CONTENT_CSV = process.argv[5];
const SIMILARITIES_CSV = process.argv[6];
const OUTPUT_CSV = process.argv[7];

function readCsv(input) {
  const csvString = readFileSync(input).toString();
  const result = Papa.parse(csvString, { header: true, skipEmptyLines: true, dynamicTyping: true });
  return result.data;
}

function getLookup(dataCsv, contentCsv) {
  const lookup = {};
  for (const row of readCsv(dataCsv)) {
    lookup[row.id] = row;
  }
  for (const row of readCsv(contentCsv)) {
    lookup[row.id].content = row.content;
  }
  return lookup;
}

const sources = getLookup(SOURCE_CSV, SOURCE_CONTENT_CSV);
const targets = getLookup(TARGET_CSV, TARGET_CONTENT_CSV);

for (const sim of readCsv(SIMILARITIES_CSV)) {
  sources[sim.source].similar = sources[sim.source].similar ?? [];
  sources[sim.source].similar.push([sim.target, sim.score]);
}

const results = openSync(OUTPUT_CSV, 'w');
writeSync(results, 'source,target,rank,score\n');

for (const source of Object.values(sources).filter((s) => s.similar?.length > 0)) {
  const similar = source.similar;
  if (similar.length === 1) {
    writeSync(results, [source.id, similar[0], 1, similar[1]].join(',') + '\n');
  } else if (similar.length > 1) {
    console.log('source id', source.id, source.name, similar.length);
    const content = similar
      .map(([targetId, _score]) => {
        const target = targets[targetId];
        return `[${targetId}] ${target.content}\n`;
      })
      .slice(0, 3)
      .join('\n');
    const options = ['name', 'aka', 'content'].map((n) => `-p ${n} "${source[n]}"`).join(' ');
    const simStr = sh.echo(content).exec(`llm -t rank-similar ${options}`).stdout.toString().trim();

    const sorted = similar
      .slice(0, 3)
      .sort((a, b) => {
        const scoreA = simStr.indexOf(a[0]) === -1 ? simStr.length : simStr.indexOf(a[0]);
        const scoreB = simStr.indexOf(b[0]) === -1 ? simStr.length : simStr.indexOf(b[0]);
        return scoreA - scoreB;
      })
      .map(([targetId, score], rank) => [source.id, targetId, rank + 1, score].join(','));

    writeSync(results, sorted.join('\n') + '\n');
  }
}
closeSync(results);
