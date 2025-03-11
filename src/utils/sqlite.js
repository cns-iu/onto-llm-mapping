import sqlite3 from 'sqlite3';

export const Database = sqlite3.Database;

export async function* select(db, query) {
  const queue = [];
  let done = false;

  db.each(
    query,
    (err, row) => {
      if (err) {
        done = true;
        throw err;
      }
      queue.push(row);
    },
    () => (done = true)
  );

  try {
    while (!done || queue.length > 0) {
      if (queue.length > 0) {
        yield queue.shift();
      } else {
        await new Promise((resolve) => setTimeout(resolve, 10));
      }
    }
  } finally {
    db.close();
  }
}
