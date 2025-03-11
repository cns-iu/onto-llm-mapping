import { dot, norm } from 'mathjs';

/**
 * A function to return a cosine sim for two vectors
 *
 * @param {number[]} a
 * @param {number[]} b
 * @returns cosine similarity between a and b
 */
export function cosineSim(a, b) {
  return dot(a, b) / (norm(a) * norm(b));
}
