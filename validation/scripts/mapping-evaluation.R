#### Set up environment ####
library(magrittr)
library(tidyr)
library(plyr)
library(dplyr)

#### Set Paths ####
path_input_data <- paste0("./input-data/mesh-uberon-human/v0.0.1")
path_raw_data <- paste0("./raw-data/mesh-uberon-human/v0.0.1")
path_eval_data <- paste0("./validation/evaluation_mappings")
path_prep_data <- paste0("./validation/mesh-uberon-human/v0.0.1/")

#### Load data ####
#Load MeSH concepts used in LLM mapping analysis
source_concepts <-
  read.csv(file=paste0(path_input_data,"/mesh-terms.csv"),
           header = T, encoding = "UFT-8")
#Load UBERON and CL concepts used in LLM mapping analysis
target_concepts <-
  read.csv(file=paste0(path_input_data,"/uberon-terms.csv"),
           header = T, encoding = "UFT-8")

#Load prepared in LLM mappings 
# currently selects for vector results.
llm_mapping_paths <- 
  list.files(path=path_prep_data,
             pattern="llm-prepared.csv", full.names = TRUE)

#Load Ground Truth mapping Data
evaluative_mappings <- 
  read.csv(file=paste0(path_eval_data,"/concept-mapping-evaluation-lookup-table-MGINDA.csv"),
           header = T, encoding = "UFT-8")

# identify mappable concepts from initial set of subject concepts)
mappable_concepts <- 
  evaluative_mappings[evaluative_mappings$mappability=="Mappable",]$subject_label %>%
  unique()

