COPY (

SELECT
  SOURCE.iri as subject_id, SOURCE.name as subject_label,
  'skos:relatedMatch' as predicate_id,
  TARGET.iri as object_id, TARGET.name as object_label,
  SCORES.rank::integer as score,
  '' as comment,
  'semapv:SemanticSimilarityThresholdMatching' as mapping_justification,

FROM
  read_csv(getenv('SOURCE')) AS SOURCE,
  read_csv(getenv('TARGET')) AS TARGET,
  read_csv(getenv('SCORES'), ignore_errors=true) as SCORES
WHERE SCORES.source = SOURCE.id AND SCORES.target = TARGET.id

ORDER BY subject_id, score

) TO '/dev/stdout' (HEADER, DELIMITER ',')
