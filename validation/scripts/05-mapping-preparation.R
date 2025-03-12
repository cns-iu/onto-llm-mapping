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

#Load in LLM mappings 
# currently selects for vector results.
llm_mapping_paths <- 
  list.files(path=paste0(path_raw_data,"/mappings"),
             pattern="sssom.csv", full.names = TRUE)

# Load Ground Truth mapping Data
evaluative_mappings <- 
  read.csv(file=paste0(path_eval_data,"/mesh-uberon-human-mapping.evaluative-lookup-table-MGINDA.csv"),
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
    paste0(data$subject_id,"|",data$object_id)
  
  # Re-order columns
  data <- data[,c(9,8,1,3,4,10,2,5,6,7)]
  
  # Subset to keep only results for mappable concepts
  data <- data[data$subject_label %in% mappable_concepts,]
  
  # Join 1: Evaluate mapping results using mapping evaluation look-up table.
  data <- join(data, evaluative_mappings[,c(2,11)], by="pair_id")
  
  # Set accuracy score for missing values, all to 0.
  data[is.na(data$accurate_mapping),]$accurate_mapping <- 0
  
  # Create concept_pair_rank values for subject concept mapping results.
  data <-
   data %>% 
    group_by(subject_id) %>% 
    mutate(concept_pair_rank = row_number()) %>%
    ungroup()
  
  #Identify any missing concepts, and return concept level labels and mapping stats
  tmp <-  
    data[,c(1,3,7,11)] %>%
    ddply(.(model, subject_id, subject_label),
          summarise, 
          accurate_mapping=max(accurate_mapping, na.rm = TRUE)) %>%
    mutate(model_analyzed = TRUE)
  
  # Join 2: tmp concept level mapping results are joined to evaluation look up.
  tmp <-
    right_join(tmp, 
               unique(evaluative_mappings[
                      evaluative_mappings$mappability=="Mappable", c(3,4,8,12)]),
                      by=c("subject_id","subject_label")) %>%
    fill(model, .direction="down")
  
  # Updates missing values for absent subject concepts.
  if(nrow(tmp[is.na(tmp$model_analyzed),])>0){ 
    tmp[is.na(tmp$model_analyzed),]$model_analyzed <- FALSE
    }
  
  # Creates hit_miss_concept variable.
  tmp$hit_miss_concept <- "Miss"
  
  # Update hit_miss_concept variable.
  tmp[tmp$accurate_mapping==1 & !is.na(tmp$accurate_mapping),]$hit_miss_concept <- "Hit"
  
  # Reorder columns
  tmp <- tmp[,c(1,2,3,5,8,6,4,7)]
  
  # Join 3: Combine missing subject concepts back into results.
  data <- left_join(tmp, data, by=c("model","subject_id","subject_label"))
  
  # Reorder columns
  data <- data[,c(1,9,2,10:12,3,13,6,14,16,17,8,5,4)]
  
  # Update name of variable
  names(data)[11] <- "accurate_mapping"
  
  # Create hit_miss_mapping from hit_miss_concept
  data$hit_miss_mapping <- data$hit_miss_concept
  
  # Update values for hit_miss_mapping, where accurate mapping values are 0.
  data[data$accurate_mapping==0 | is.na(data$accurate_mapping)==T ,]$hit_miss_mapping <- "Miss"
  
  # Update mapping values for accurate_mapping for absent subject concepts variables.
  if(nrow(data[is.na(data$accurate_mapping),])>0){
     data[is.na(data$accurate_mapping),]$accurate_mapping <- 0
  }
  
  # Pivot 2: Calculate mapping result number (most subject concepts have 1 valid result).
  tmp2 <- 
    data[data$accurate_mapping==1,c("subject_id","pair_id","mapping_count")] %>%
    group_by(subject_id) %>%  
    mutate(mapping_result_number = row_number()) %>%
    ungroup() %>%
    select(pair_id,mapping_result_number)
  
  # Join 4
  data <- join(data, tmp2, by="pair_id")
  data[is.na(data$mapping_result_number)==T,]$mapping_result_number <- 0
  
  # Reorder columns
  data <- data[,c(1:13,17,14,16,15)]
  
  # Export prepared results.
  write.csv(data,file=paste0(path_prep_data,"/",llm_result_file,"-prepared.csv"), row.names =F )
  
  # Clean up loop
  rm(tmp, tmp2, llm_result_file)
}

rm(i, data, llm_mapping_paths, evaluative_mappings, mappable_concepts, 
   path_eval_data, path_prep_data, path_raw_data)