// Get all UBERON mapped to MeSH terms via shared Concept
// perl -pe 's/\"\"\"/\"/g' uberon-mesh-mapping.UBKG.exported.csv | csvformat > uberon-mesh-mapping.UBKG.csv

MATCH (ul:Term)<-[]-(u: Code {SAB:'UBERON'})<-[:CODE]-(c:Concept)-[:CODE]->(m: Code {SAB:'MSH'})-[]->(ml:Term)
WITH u,m,ul,ml ORDER BY ul.name,ml.name
RETURN DISTINCT 
    replace(u.CodeID, ':', '_') as uberon_id,
    replace(m.CodeID, 'MSH:', '') as mesh_id,
    apoc.text.join(collect(DISTINCT toLower(ul.name)),'; ') as uberon_labels,
    apoc.text.join(collect(DISTINCT toLower(ml.name)),'; ') as mesh_labels
ORDER BY uberon_id,mesh_id
