# Mapping ontologies using LLMs and RAG

:warning: RESEARCH IN PROGRESS

## TODO

* Write validation code to evaluate each mapping generated (againsta a gold standard?)
* Create scripts for setting up and running the workflow from start to finish
* Tweak models used and prompts to improve results
* Write code to choose and finalize a mapping for publication (maybe is then finalized by hand via SME)
* Afte we are really satisfied with the results, generalize the code and workflow for mapping between any two sets of concepts

## Current results

There are 4 different SSSOM mappings to evaluate in [mappings](./mappings/) folder:

* [uberon-mesh-mapping.desc-vec.sssom.csv](./mappings/uberon-mesh-mapping.desc-vec.sssom.csv)
  * maps uberon to mesh using just the label, synonyms, and description loaded into a vector store and computing the semantic similarity using that. Could be used as a baseline to see how expanding the text via LLM improves the results.  
* [uberon-mesh-mapping.llm-vec.sssom.csv](./mappings/uberon-mesh-mapping.llm-vec.sssom.csv)
  * maps uberon to mesh by expanding the label, synonym, and description text (see the [term description](./templates/term-description.yaml) template), loading them into a vector store, and computing the semantic similarity using that.
* [uberon-mesh-mapping.llm-rank.sssom.csv](./mappings/uberon-mesh-mapping.llm-rank.sssom.csv)
  * maps uberon to mesh by expanding the text from above and asking the LLM to rank the top 3 (see the [rank similar](./templates/rank-similar.yaml) template). This should theoretically give the best results. This method should be extended to look at the whole set (usually more than 3) to rank, but needs more engineering.
* [uberon-mesh-mapping.ubkg.sssom.csv](./mappings/uberon-mesh-mapping.ubkg.sssom.csv)
  * uses UBKG's concept mapping approach that utilizes mappings in UMLS, Uberon, and a host of other ontologies to map terms from different ontologies to the same Concept. With this, if both MESH and Uberon have a term mapped to the same Concept, they are added to this mapping.

Note: The LLM expanded description is in the data folder: [uberon](./data/uberon-terms.content.csv) and [mesh](./data/mesh-terms.content.csv)

## Current method

1. For each uberon and mesh term that we care about, use an LLM to expand the name, synonyms, plus descriptions to a common length and quality to create an expanded description
2. Store the expanded descriptions in a vector database 
3. For each term in the uberon ontology, compare it's expanded description to the expanded descriptions in the mesh ontology's vector database and retrieve the top most similar terms based on the expanded description. 
4. Ask the LLM to then take that same term's expanded description and rank the retrieved similar terms from the mesh ontology. (currently ranks the top 3)
5. Output the results to a .csv file to evaluate the results with an SME (Ellen).
6. Generate SSSOM file

### Current configuration

- prompt model: llama3.1:8b
- vector embed model: sentence-transformers/all-mpnet-base-v2

### Commands (to be scripted)

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
duckdb :memory: -no-stdin -init queries/uberon-mesh-mapping.desc-vec.sql
duckdb :memory: -no-stdin -init queries/uberon-mesh-mapping.llm-rank.sql
duckdb :memory: -no-stdin -init queries/uberon-mesh-mapping.llm-vec.sql
duckdb :memory: -no-stdin -init queries/uberon-mesh-mapping.ubkg.sql

### Validate SSOM csvs
sssom validate mappings/uberon-mesh-mapping.desc-vec.sssom.csv
sssom validate mappings/uberon-mesh-mapping.llm-rank.sssom.csv
sssom validate mappings/uberon-mesh-mapping.llm-vec.sssom.csv
sssom validate mappings/uberon-mesh-mapping.ubkg.sssom.csv

```
