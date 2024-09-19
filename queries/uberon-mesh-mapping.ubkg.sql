COPY (

SELECT
  UBERON.iri as subject_id, UBERON.name as subject_label,
  'skos:exactMatch' as predicate_id,
  MESH.descriptor as object_id, MESH.name as object_label,
  '' as comment,
  'semapv:LogicalReasoning' as mapping_justification,

FROM
  read_csv('data/uberon-terms.csv') AS UBERON,
  read_csv('data/mesh-descriptors.csv') AS MESH,
  read_csv('data/uberon-mesh-mapping.UBKG.csv') as SCORES
WHERE SCORES.uberon_id = UBERON.id AND SCORES.mesh_id = MESH.descriptor_id

) TO 'mappings/uberon-mesh-mapping.ubkg.sssom.csv' (HEADER, DELIMITER ',')
