import { createReadStream } from 'fs';
import Papa from 'papaparse';

export function readCsv(input, options = { skipEmptyLines: true, header: true }) {
  return createReadStream(input).pipe(Papa.parse(Papa.NODE_STREAM_INPUT, options));
}
