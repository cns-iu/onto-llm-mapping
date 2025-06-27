#### Set up environment ####
library(magrittr)
library(tidyr)
library(plyr)
library(dplyr)
library(stringr)

#### Set Paths ####
# Paths
path_input_data <- paste0("./input-data/mesh-uberon-human/v0.0.1")
path_eval_data <- paste0("./validation/evaluation_mappings")
path_prep_data <- paste0("./validation/mesh-uberon-human/v0.0.1")

# Create results directory and path 
path_results_data  <- paste0(path_prep_data,"/results/")
if(dir.exists(path_results_data)==FALSE){
  dir.create(path_results_data) 
}
if(dir.exists(paste0(path_results_data,"/descriptive_statistics/"))==FALSE){
  dir.create(paste0(path_results_data,"/descriptive_statistics/")) 
}

#### Load data ####
# Load MeSH concepts used in LLM mapping analysis
source_concept <-
  read.csv(file=paste0(path_input_data,"/mesh-terms.csv"),
           header = T, encoding = "UFT-8")
names(source_concept)[1] <- "subject_id"

# Load UBERON and CL concepts used in LLM mapping analysis
target_concept <-
  read.csv(file=paste0(path_input_data,"/uberon-terms.csv"),
           header = T, encoding = "UFT-8")

# Load Ground Truth mapping Data
evaluative_mappings <- 
  read.csv(file=paste0(path_eval_data,"/mesh-uberon-human-mapping.validation-tool.csv"),
           header = T, encoding = "UFT-8")

# Identify mapped and unmapped concepts from initial set of subject concepts
mappable_concepts <- 
  evaluative_mappings[evaluative_mappings$map_state=="Mapped",]$subject_id %>%
  unique()

unmapped_concepts <-
  evaluative_mappings[evaluative_mappings$map_state=="Unmapped",]$subject_id %>%
  unique()

# Identify SSSOM mapping project
project <- paste((str_split(path_input_data[1],"/")[[1]][3]))

#### Characterize MeSH Subject Concepts and Mappings ####
##### MeSH Subject Concept Counts - Overall and by Concept Grouping ####
subject_concepts <- data.frame("concept_group"=c("Total"),
                               "subject_concepts"=nrow(source_concept))
subject_concepts_as <- data.frame("concept_group"=c("Anatomical structure"),
                                  "subject_concepts"=
                                    length(unique(evaluative_mappings[evaluative_mappings$mesh_concept_group=="Anatomical structure",]$subject_label)))
subject_concepts_ct <- data.frame("concept_group"=c("Cell type"),
                                  "subject_concepts"=
                                    length(unique(evaluative_mappings[evaluative_mappings$mesh_concept_group=="Cell type",]$subject_label)))
subject_concepts <- rbind(subject_concepts_as, subject_concepts_ct, subject_concepts)
# subject_concepts_as_ct <- subject_concepts_as + subject_concepts_ct
# subject_concepts_other <- subject_concepts - subject_concepts_as_ct

##### Characterizing Unmapped MeSH Concepts ####
# by concept groups
mesh_unmapped_concepts <- 
  evaluative_mappings %>%
  filter(map_state=="Unmapped") %>% 
  ddply(.(mesh_concept_group), summarise,
        concepts = length(subject_id)) %>%
  arrange(mesh_concept_group, desc(concepts)) %>%
  mutate(percent_subject_concepts = round(concepts/
                                          nrow(source_concept)*100,2)) %>%
  rename(c("concept_group"="mesh_concept_group"))

# Add 
mesh_unmapped_concepts <-
  rbind(mesh_unmapped_concepts, 
        data.frame(concept_group = c("Total"),
                   concepts = sum(mesh_unmapped_concepts$concepts),
                   percent_subject_concepts = round(sum(mesh_unmapped_concepts$concepts)/
                                                    nrow(source_concept)*100,2)))

# Unmapped Subject Concepts Broken out by exclusion reason
mesh_unmapped_concepts_rational <- 
  evaluative_mappings %>%
  filter(map_state=="Unmapped") %>% 
  ddply(.(mesh_concept_group, exclusion_reason), summarise,
        subject_concepts = length(subject_id)) %>%
  rename(c("concept_group"="mesh_concept_group")) %>%
  arrange(concept_group, desc(subject_concepts))

# Save results and clean up environment
write.csv(mesh_unmapped_concepts,
          file=paste0(path_results_data,"/descriptive_statistics/",
                      project,".subject_concepts.unmapped.desc_statistics.csv"),
          row.names = FALSE, fileEncoding = "UTF8")
write.csv(mesh_unmapped_concepts_rational,
          file=paste0(path_results_data,"/descriptive_statistics/",
                      project,".subject_concepts.unmapped.exclusions_breakout.csv"),
          row.names = FALSE, fileEncoding = "UTF8")

##### Characterizing Mapped MeSH Concepts ####
# Mapped Subject Concept Counts and Percentages - Overall and by Concept Grouping
mapped_concepts <-
  evaluative_mappings %>%
  filter(map_state=="Mapped") %>%
  select(subject_id, subject_label, mesh_concept_group, mapping_count) %>%
  distinct() %>%
  group_by("concept_group"=mesh_concept_group) %>%
  count() %>%
  ungroup() %>% 
  rename(c("mapped_subject_concepts"="n")) %>%
  rbind(data.frame(concept_group=c("Total"),
                   mapped_subject_concepts=length(mappable_concepts))) %>%
  mutate(percentage_mapped_concepts =
           round(mapped_subject_concepts/length(mappable_concepts)*100,2))

mapped_concepts <-
  left_join(subject_concepts, mapped_concepts, by="concept_group") %>%
  mutate(percent_subject_concepts_mapped =
           round(mapped_subject_concepts/subject_concepts*100,2)) %>%
  select(concept_group, subject_concepts, mapped_subject_concepts, 
         percent_subject_concepts_mapped, percentage_mapped_concepts)

# Subject Concept Recalls (Mappings) - Overall and by Concept Grouping
mapping_recalls <- data.frame(concept_group=c("Total"),
                              mapping_recalls=
                                nrow(evaluative_mappings[evaluative_mappings$map_state=="Mapped",]))
mapping_recalls <-
  evaluative_mappings %>%
  filter(map_state=="Mapped") %>%
  ddply(.(mesh_concept_group), summarise, 
        mapping_recalls = length(subject_id)) %>%
  rename(c("concept_group"="mesh_concept_group")) %>%
  rbind(mapping_recalls)

# Combine mapped concepts and recall count and percentage statistics.
mapped_concepts_desc <- 
  join(mapped_concepts, mapping_recalls, by="concept_group") %>%
  mutate(avg_mapped_concept_recalls = 
           round(mapping_recalls/mapped_subject_concepts, 2))

# Save results and clean up environment
write.csv(mapped_concepts_desc,
          file=paste0(path_results_data,"/descriptive_statistics/",
                      project,".subject_concepts.mapped.desc_statistics.csv"),
          row.names = FALSE, fileEncoding = "UTF8")

rm(mapped_concepts_desc, mapping_recalls, mapped_concepts, 
   subject_concepts, subject_concepts_as, subject_concepts_ct)
rm(mesh_unmapped_concepts_rational, mesh_unmapped_concepts)

# UBERON and CL Concept Counts
target_concepts <- nrow(target_concept)
target_concepts_as <- nrow(target_concept[grepl("http://purl.obolibrary.org/obo/UBERON_",
                                                target_concept$iri)==T,])
target_concepts_ct <- nrow(target_concept[grepl("http://purl.obolibrary.org/obo/CL_",
                                                target_concept$iri)==T,])