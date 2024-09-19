# Mapping ontologies using LLMs and RAG

:warning: RESEARCH IN PROGRESS

Let's try:

1. For each term, provide the LLM a name and short description (ideally all are about the same length) and ask it to expand the definition to 500 words
2. Use model embedding to store each as a vector
3. Use similarity search to find similar terms (-m sentence-transformers/all-MiniLM-L6-v2)
4. Ask llm to verify
5. Generate SSSOM file

1. For each uberon and mesh term that we care about, use an LLM to expand the name, synonyms, plus descriptions to a common length and quality to create an expanded description
2. Store the expanded descriptions in a vector database 
3. For each term in the uberon ontology, compare it's expanded description to the expanded descriptions in the mesh ontology's vector database and retrieve the top most similar terms based on the expanded description. 
4. Ask the LLM to then take that same term's expanded description and rank the retrieved similar terms from the mesh ontology. 
5. Output the results to a .csv file to evaluate the results with an SME (Ellen).
6. Generate SSSOM file

# prompt model: llama3.1:8b
# vector embed model: sentence-transformers/all-mpnet-base-v2

```bash
# Extract terms and descriptive metadata
sparql-select.sh http://localhost:8080/blazegraph/namespace/kb/sparql queries/mesh-terms.rq > data/mesh-terms.csv
sparql-select.sh http://localhost:8080/blazegraph/namespace/kb/sparql queries/uberon-terms.rq > data/uberon-terms.csv

# WITHOUT EXPANDED CONTENT

## Convert metadata to a content format for LLM vector database
node ./src/create-descriptions.js data/mesh-terms.csv data/mesh-terms.description.csv
node ./src/create-descriptions.js data/uberon-terms.csv data/uberon-terms.description.csv

## Find similar terms using vectorized versions of original content
node ./src/find-similar.js data/uberon-terms.description.csv data/mesh-terms.description.csv data/uberon-terms.description.mesh-scores.csv

## Use an LLM to rank the similar terms from expanded content comparison
node ./src/rank-similar.js data/uberon-terms.csv data/mesh-terms.csv data/uberon-terms.description.csv data/mesh-terms.description.csv data/uberon-terms.description.mesh-scores.csv data/uberon-terms.description.mesh-ranked-scores.csv


# WITH EXPANDED CONTENT

## Use an LLM to expand the description to a consistent length and format
node src/expand-descriptions.js data/mesh-terms.csv data/mesh-terms.content.csv
node src/expand-descriptions.js data/uberon-terms.csv data/uberon-terms.content.csv

## Find similar terms using vectorized versions of expanded content
node src/find-similar.js data/uberon-terms.content.csv data/mesh-terms.content.csv data/uberon-terms.mesh-scores.csv

## Use an LLM to rank the similar terms from expanded content comparison
node ./src/rank-similar.js data/uberon-terms.csv data/mesh-terms.csv data/uberon-terms.content.csv data/mesh-terms.content.csv data/uberon-terms.mesh-scores.csv data/uberon-terms.mesh-ranked-scores.csv

### Convert to SSSOM format
duckdb :memory: -no-stdin -init queries/uberon-mesh-mapping.llm-rank.sql
duckdb :memory: -no-stdin -init queries/uberon-mesh-mapping.llm-vec.sql
duckdb :memory: -no-stdin -init queries/uberon-mesh-mapping.ubkg.sql

### Validate SSOM csvs
sssom validate mappings/uberon-mesh-mapping.llm-rank.sssom.csv
sssom validate mappings/uberon-mesh-mapping.llm-vec.sssom.csv
sssom validate mappings/uberon-mesh-mapping.ubkg.sssom.csv

```
