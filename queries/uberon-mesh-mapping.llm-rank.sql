COPY (

SELECT
  UBERON.iri as subject_id, UBERON.name as subject_label,
  'skos:relatedMatch' as predicate_id,
  MESH.iri as object_id, MESH.name as object_label,
  SCORES.rank::integer as score,
  '' as comment,
  'semapv:SemanticSimilarityThresholdMatching' as mapping_justification,

FROM
  read_csv('data/uberon-terms.csv') AS UBERON,
  read_csv('data/mesh-terms.csv') AS MESH,
  read_csv('data/uberon-terms.mesh-ranked-scores.csv', ignore_errors=true) as SCORES
WHERE SCORES.source = UBERON.id AND SCORES.target = MESH.id

ORDER BY subject_id, score

) TO 'mappings/uberon-mesh-mapping.llm-rank.sssom.csv' (HEADER, DELIMITER ',')
