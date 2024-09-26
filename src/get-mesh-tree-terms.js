import { readFileSync, writeFileSync } from 'fs';
import Papa from 'papaparse';
import { select } from './sparql.js';

const KEY_TERMS = process.argv[2];
const OUTPUT = process.argv[3];
const SPARQL_ENDPOINT = 'https://id.nlm.nih.gov/mesh/sparql';
const baseQuery = readFileSync('queries/select-mesh-concepts.rq').toString();

const terms = Papa.parse(readFileSync(KEY_TERMS).toString(), { skipEmptyLines: true, header: true }).data;
const termList = terms.map((s) => `(<${s.iri}>)`).join(' ');
const query = baseQuery.replace('(example:)', termList);

const results = await select(query, SPARQL_ENDPOINT);
writeFileSync(OUTPUT, Papa.unparse(results, { header: true }));
