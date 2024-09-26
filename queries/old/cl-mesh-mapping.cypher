// Get all CL mapped to MeSH terms via shared Concept
// perl -pe 's/\"\"\"/\"/g' cl-mesh-mapping.UBKG.exported.csv | csvformat > cl-mesh-mapping.UBKG.csv

MATCH (cll:Term)<-[]-(cl: Code {SAB:'CL'})<-[:CODE]-(c:Concept)-[:CODE]->(m: Code {SAB:'MSH'})-[]->(ml:Term)
WITH cl,m,cll,ml ORDER BY cll.name,ml.name
RETURN DISTINCT 
    replace(cl.CodeID, ':', '_') as cl_id,
    replace(m.CodeID, 'MSH:', '') as mesh_id,
    apoc.text.join(collect(DISTINCT toLower(cll.name)),'; ') as cl_labels,
    apoc.text.join(collect(DISTINCT toLower(ml.name)),'; ') as mesh_labels
ORDER BY cl_id,mesh_id
