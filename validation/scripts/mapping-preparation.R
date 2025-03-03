#### Set up environment ####
library(magrittr)
library(tidyr)
library(plyr)
library(dplyr)
library(stringr)

#### Load data ####
# Set Paths
# path_input_data <- paste0("./input-data/mesh-uberon-human/v0.0.1")
path_raw_data <- paste0("./raw-data/mesh-uberon-human/v0.0.1")
path_eval_data <- paste0("./validation/evaluation_mappings")
path_prep_data <- paste0("./validation/mesh-uberon-human/v0.0.1")

# #Load MeSH concepts used in LLM mapping analysis
# source_concepts <- 
#   read.csv(file=paste0(path_input_data,"/mesh-terms.csv"),
#            header = T, encoding = "UFT-8")
# #Load UBERON and CL concepts used in LLM mapping analysis
# target_concepts <- 
#   read.csv(file=paste0(path_input_data,"/uberon-terms.csv"),
#            header = T, encoding = "UFT-8")

#Load in LLM mappings 
# currently selects for vector results.
llm_mapping_paths <- 
  list.files(path=paste0(path_raw_data,"/mappings"),
             pattern="vec.sssom.csv", full.names = TRUE)

#Load Ground Truth mapping Data
evaluative_mappings <- 
  read.csv(file=paste0(path_eval_data,"/concept-mapping-evaluation-lookup-table-MGINDA.csv"),
           header = T, encoding = "UFT-8")

# identify mappable concepts from initial set of subject concepts)
mappable_concepts <- 
  evaluative_mappings[evaluative_mappings$mappability=="Mappable",]$subject_label %>%
  unique()

#### Pre-process the data ####

for(i in 1:length(llm_mapping_paths)){
  # Load LLM mapping results  
  data <- read.csv(file=llm_mapping_paths[i],
                   header = T, encoding = "UFT-8")

  # grab project and model for data.
  llm_result_file <- tail(unlist(str_split(llm_mapping_paths[i], pattern="\\/")),1)
  llm_result_file <- str_split(llm_result_file, pattern="-vec")[[1]][1]
  
  # extracting mapping tool info?
  #mapping_tool	
  #mapping_tool_version
  
  # Creates model and project label for data set.
  data$model <- llm_result_file
  
  # Creates concept pair id with concept labels.
  data$pair_id <- 
    paste0(data$subject_label,"|",data$object_label)
  
  # Re-order columns
  data <- data[,c(9,8,1,3,4,10,2,5,6,7)]
  
  # Subset to keep only results for mappable concepts
  data <- data[data$subject_label %in% mappable_concepts,]
  
  # Join mapping results with accurate mapping evaluation.
  data <- join(data, evaluative_mappings[,c(2,11)], by="pair_id")
  
  # Set accuracy score for missing values, all to 0.
  data[is.na(data$accurate_mapping),]$accurate_mapping <- 0
  
  # Add rank number to mapping results per source concept.
  data <-
   data %>% 
    group_by(subject_id) %>% 
    mutate(concept_pair_rank = row_number()) %>%
    ungroup()
  
  # Identify any missing concepts, and return concept level labels and mapping stats
  tmp <-  
    data[,c(1,3,7,11)] %>%
    ddply(.(model, subject_id, subject_label),
          summarise, 
          accurate_mapping=max(accurate_mapping, na.rm = TRUE)) %>%
    mutate(model_analyzed = TRUE)
  
  tmp <-
    right_join(tmp, 
               unique(evaluative_mappings[
                      evaluative_mappings$mappability=="Mappable", c(3,4,8,12)]),
                      by=c("subject_id","subject_label")) %>%
    fill(model, .direction="down")
  
  # Clean up missing values
  tmp[is.na(tmp$accurate_mapping),]$accurate_mapping <- 0
  tmp[is.na(tmp$model_analyzed),]$model_analyzed <- FALSE
  # Add hit miss column for concept.
  tmp$hit_miss <- "Miss"
  tmp[tmp$accurate_mapping==1,]$hit_miss <- "Hit"
  
  tmp <- tmp[,c(1,2,3,5,8,6,4,7)]
  
  # Combine missing subject concepts back into results.
  data <- left_join(tmp,data, by=c("model","subject_id","subject_label"))
  data <- data[,c(1,9,2,10:12,3,13,6,14,16,17,8,5,4)]
  
  # update hit_miss to hit_miss_concept and hit_miss_mapping
  data$hit_miss_mapping <- data$hit_miss
  data[data$accurate_mapping==0 | is.na(data$accurate_mapping)==T ,]$hit_miss_mapping <- "Miss"
  names(data)[14] <- "hit_miss_concept"
  
  # Update mapping values for un-mapped concepts.
  names(data)[11] <- "accurate_mapping"
  data[is.na(data$accurate_mapping),]$accurate_mapping <- 0
  
  # Reorder columns
  data <- data[,c(1:14,16,15)]
  
  # Export prepared results.
  write.csv(data,file=paste0(path_prep_data,"/",llm_result_file,"-prepared.csv"), row.names =F )
  
  # Clean up loop
  rm(tmp, llm_result_file)
}
