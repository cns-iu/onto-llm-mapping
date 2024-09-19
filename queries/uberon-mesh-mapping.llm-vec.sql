COPY (

SELECT
  UBERON.iri as subject_id, UBERON.name as subject_label,
  'skos:exactMatch' as predicate_id,
  MESH.iri as object_id, MESH.name as object_label,
  SCORES.score as similarity_score,
  '' as comment,
  'semapv:SemanticSimilarityThresholdMatching' as mapping_justification,

FROM
  read_csv('data/uberon-terms.csv') AS UBERON,
  read_csv('data/mesh-terms.csv') AS MESH,
  read_csv('data/uberon-terms.mesh-scores.csv') as SCORES
WHERE SCORES.source = UBERON.id AND SCORES.target = MESH.id

ORDER BY subject_id, similarity_score DESC

) TO 'mappings/uberon-mesh-mapping.llm-vec.sssom.csv' (HEADER, DELIMITER ',')
