import { readFileSync, writeFileSync } from 'fs';
import Papa from 'papaparse';
import { select } from './sparql.js';

const KEY_TERMS = process.argv[2];
const OUTPUT = process.argv[3];
const SPARQL_ENDPOINT = 'https://lod.humanatlas.io/sparql';
const baseQuery = readFileSync('queries/hra-uberon-part-of-terms.rq').toString();

const terms = Papa.parse(readFileSync(KEY_TERMS).toString(), { skipEmptyLines: true, header: true }).data;
const termList = terms.map((s) => `(<${s.iri}>)`).join(' ');
const query = baseQuery.replace('(body:)', termList);

const results = await select(query, SPARQL_ENDPOINT);
writeFileSync(OUTPUT, Papa.unparse(results, { header: true }));
