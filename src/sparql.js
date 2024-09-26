import Papa from 'papaparse';

export function fetchSparql(query, endpoint, mimetype) {
  const body = new URLSearchParams({ query });
  return fetch(endpoint, {
    method: 'POST',
    headers: {
      Accept: mimetype,
      'Content-Type': 'application/x-www-form-urlencoded',
      'Content-Length': body.toString().length.toString(),
    },
    body,
  });
}

export async function select(query, endpoint) {
  const resp = await fetchSparql(query, endpoint, 'text/csv');
  const text = await resp.text();
  const { data } = Papa.parse(text, { header: true, skipEmptyLines: true, dynamicTyping: true });
  return data || [];
}
