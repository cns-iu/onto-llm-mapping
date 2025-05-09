#### Set up environment ####
library(curl)
library(magrittr)
library(tidyr)
library(plyr)
library(dplyr)
library(stringr)

#### Set Paths ####
# Set Paths
path_eval_data <- paste0("./validation/evaluation_mappings")
path_obo_eval <- paste0("https://github.com/mapping-commons/mesh-mappings/raw/refs/heads/first/mappings/")
 
# # Identify mapping project from file path
# mapping_project <- unlist(str_split(llm_mapping_paths[1], pattern="\\/"))[[3]]

#### Load Data ####
##### SSSOM Mapping Evaluation Tools ####
# OBO SSSOM Mappings
if(file.exists(paste0(path_eval_data,"/obo_mesh.sssom.csv"))==F){
  obo_mappings <- 
    read.delim(paste0(path_obo_eval,"obo-mesh.sssom.tsv"), sep="\t", header = T)
  write.csv(obo_mappings, file=paste0(path_eval_data,"/obo_mesh.sssom.csv"),
            row.names = F, fileEncoding = "UTF8")
} else {
  obo_mappings <- read.csv(paste0(path_eval_data,"/obo_mesh.sssom.csv"), header=T)
}

##### CNS Naive SSSOM Mappings ####
evaluative_mappings <- 
  read.csv(file=paste0(path_eval_data,"/mesh-uberon-human-mapping.validation-lookup-table.MGINDA.csv"),
           header = T, encoding = "UFT-8")

# Compare OBO and CNS Naive Mappings
# Note: OBO is based on SME ground truth, and will correct errors found in CNS 
# Naive mapping results.

# Create id for joining evaluating mapping results
obo_mappings$object_id <- str_replace(obo_mappings$object_id,"\\:","\\_")
obo_mappings$subject_id <- str_replace(obo_mappings$subject_id,"\\:","\\_")
obo_mappings$subject_uri <- paste0("http://purl.obolibrary.org/obo/",
                                   obo_mappings$subject_id)
obo_mappings$pair_id <- paste0(obo_mappings$object_uri,"|",obo_mappings$subject_uri)
obo_mappings$weight <- 1

# Convert OBO object_id and subject_id to URI pattern in CNS mappings.
obo_mappings <- 
  obo_mappings %>%
  select(pair_id,object_uri,object_label,predicate_id,
         subject_uri,subject_label,confidence,mapping_date,
         author_id,weight)
names(obo_mappings)[c(2,3,5,6)] <- c("subject_id","subject_label",
                                     "object_id","object_label")

write.csv(obo_mappings, file=paste0(path_eval_data,"/obo_mesh.sssom.prepared.csv"),
          row.names = F, fileEncoding = "UTF8")

#### Create SSSOM mapping comparison set. ####
mapping_comparison <- full_join(evaluative_mappings,obo_mappings, by="pair_id")

# Clean up common fields 
mapping_comparison[is.na(mapping_comparison$rec_id),]$subject_id.x <-
  mapping_comparison[is.na(mapping_comparison$rec_id),]$subject_id.y
mapping_comparison[is.na(mapping_comparison$rec_id),]$subject_label.x <-
  mapping_comparison[is.na(mapping_comparison$rec_id),]$subject_label.y
mapping_comparison[is.na(mapping_comparison$rec_id),]$object_id.x <- 
  mapping_comparison[is.na(mapping_comparison$rec_id),]$object_id.y
mapping_comparison[is.na(mapping_comparison$rec_id),]$object_label.x <- 
  mapping_comparison[is.na(mapping_comparison$rec_id),]$object_label.y
mapping_comparison[is.na(mapping_comparison$rec_id),]$predicate_id.x <-
  mapping_comparison[is.na(mapping_comparison$rec_id),]$predicate_id.y

# Update NA values to 0 for confidence and accuracy ratings
mapping_comparison[is.na(mapping_comparison$confidence),]$confidence <- 0
mapping_comparison[is.na(mapping_comparison$weight),]$weight <- 0

# Re-order and re-name variables
mapping_comparison <-
  mapping_comparison %>%
  select(rec_id,pair_id,subject_id.x,subject_label.x,predicate_id.x,
         object_id.x,object_label.x,mesh_concept_group,mappability,
         exclusion_reason,mapping_count,accurate_mapping_r_1,weight,
         confidence_r_1, confidence,reviewer_1,author_id) %>%
  rename_with(~str_remove(., '.x')) %>%
  arrange(subject_id,object_id) %>%
  mutate(rec_id = seq_along(subject_id))

names(mapping_comparison)[c(13,15,16,17)] <- 
  c("accurate_mapping_r_2","confidence_r_2","author_id_1","author_id_2")

# Calculate difference in mapping scores
mapping_comparison <-
  mapping_comparison %>%
  mutate(mapping_diff = accurate_mapping_r_2-accurate_mapping_r_1)
mapping_comparison <- mapping_comparison[,c(1:13,18,14:17)]

mapping_comparison$use_rec <- 1

write.csv(mapping_comparison, file=paste0(path_eval_data,"/mesh-uberon-human-mapping.evaluate.csv"),
          row.names = F, fileEncoding = "UTF8")
