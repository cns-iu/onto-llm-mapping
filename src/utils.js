import { createReadStream } from 'fs';
import Papa from 'papaparse';

export async function* readCsv(input, options = { skipEmptyLines: true, header: true }) {
  if (options.header) {
    let header;
    const newOpts = { ...options, header: false };
    const reader = createReadStream(input).pipe(Papa.parse(Papa.NODE_STREAM_INPUT, newOpts));
    for await (const row of reader) {
      if (!header) {
        header = row;
      } else {
        const result = header.reduce((acc, field, index) => {
          acc[field] = row[index];
          return acc;
        }, {});
        yield result;
      }
    }
  } else {
    return createReadStream(input).pipe(Papa.parse(Papa.NODE_STREAM_INPUT, options));
  }
}
