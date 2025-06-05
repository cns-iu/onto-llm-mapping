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
  read.csv(file=paste0(path_eval_data,"/mesh-uberon-human-mapping.validation-tool.csv"),
           header = T, encoding = "UFT-8")

# Identify mapped concepts from initial set of subject concepts)
mappable_concepts <- 
  evaluative_mappings[evaluative_mappings$map_state =="Mapped",]$subject_label %>%
  unique()

#i=2
#### Pre-process the data ####
for(i in 1:length(llm_mapping_paths)){
  ##### Load LLM mapping results and update data file #### 
  data <- read.csv(file=llm_mapping_paths[i],
                   header = T, encoding = "UFT-8")

  # grab project and model for data.
  llm_result_file <- tail(unlist(str_split(llm_mapping_paths[i], pattern="\\/")),1)
  llm_result_file <- str_split(llm_result_file, pattern="-vec")[[1]][1]
  
  # Creates model and project label for data set.
  data$model <- llm_result_file
  
  # Creates concept pair id with concept labels.
  data$pair_id <- 
    paste0(data$subject_id,"|",data$object_id)
  
  # Re-order columns
  data <- data[,c(9,8,1,3,4,10,2,5,6,7)]
  
  # Subset to keep only results for mapped concepts
  data <- data[data$subject_label %in% mappable_concepts,]
  
  ##### Join 1: Evaluate mapping results using mapping evaluation look-up table. ####
  tmp1 <- 
    evaluative_mappings %>%
    select(pair_id, accuracy) %>%
    distinct()
  data <- join(data, tmp1, by="pair_id")
  rm(tmp1)
  
  # Set accuracy score for missing values, all to 0.
  data[is.na(data$accuracy),]$accuracy <- 0
  
  ##### Create concept_pair_rank values for subject concept mapping results. ####
  data <-
   data %>% 
    group_by(subject_id) %>% 
    mutate(concept_pair_rank = row_number()) %>%
    ungroup()
  
  ##### Join 2: tmp2 concept level mapping results are joined to evaluation look up. ####
  # Set of concepts missed by model in mapping process
  tmp2 <-  
    data %>%
    select(model, subject_id, subject_label, accuracy) %>%
    ddply(.(model, subject_id, subject_label),
          summarise, 
          accurate_mapping=max(accuracy, na.rm = TRUE)) %>%
    mutate(model_analyzed = TRUE)
  
  # Unique set of mapped concepts 
  tmp3 <-  
    evaluative_mappings %>%
    select(subject_id, subject_label, map_state, mapping_count, 
           mesh_concept_group, accuracy) %>%
    filter(map_state=="Mapped") %>%
    distinct()
  
  # Join to indicate if model generated mappings
  tmp2 <-
    right_join(tmp2, tmp3,
               by=c("subject_id","subject_label")) %>%
    fill(model, .direction="down")
  
  # Updates missing values for absent subject concepts.
  if(nrow(tmp2[is.na(tmp2$model_analyzed),])>0){ 
    tmp2[is.na(tmp2$model_analyzed),]$model_analyzed <- FALSE
    }
  
  ##### Create hit_miss_concept variables. #####
  tmp2$hit_miss_concept <- "Miss"
  
  # Update hit_miss_concept variable.
  tmp2[tmp2$accurate_mapping==1 & !is.na(tmp2$accurate_mapping),]$hit_miss_concept <- "Hit"
  
  ##### Join 3: Combine missing subject concepts back into results. ####
  # Select and Reorder columns, unique concepts 
  tmp2 <-
    tmp2 %>%
    select(model, subject_id, subject_label, mesh_concept_group, mapping_count,
           model_analyzed, hit_miss_concept, accurate_mapping) %>%
    distinct()
  
  # Join selected data
  data <- left_join(data, tmp2, by=c("model","subject_id","subject_label"))
  
  # Reorder columns
  data <- 
    data %>% 
    select(model, mapping_justification, subject_id, predicate_id, object_id, 
           pair_id, subject_label, object_label, mesh_concept_group, 
           similarity_score, accurate_mapping, accuracy, concept_pair_rank, 
           mapping_count, hit_miss_concept,	model_analyzed)
  
  ##### Create hit_miss_mapping from hit_miss_concept ####
  data$hit_miss_mapping <- data$hit_miss_concept
  
  # Update values for hit_miss_mapping, where accuracy values euqals 0 or NA.
  data[data$accuracy==0 | is.na(data$accuracy)==T ,]$hit_miss_mapping <- "Miss"
  
  # Update mapping values for accurate_mapping for absent subject concepts variables.
  if(nrow(data[is.na(data$accurate_mapping),])>0){
     data[is.na(data$accurate_mapping),]$accurate_mapping <- 0
  }
  
  ##### Pivot 2: Calculate mapping result number (most subject concepts have 1 valid result). #####
  tmp4 <- 
    data[data$accuracy==1, 
         c("subject_id","pair_id")] %>%
    group_by(subject_id) %>%  
    mutate(mapping_result_number = row_number()) %>%
    ungroup() %>%
    select(pair_id,mapping_result_number)
  
  # Join 4
  data <- join(data, tmp4, by="pair_id")
  data[is.na(data$mapping_result_number)==T,]$mapping_result_number <- 0
  
  # Reorder columns
  data <- data[,c(1:10,12:14,18,15,17,16)]
  
  # Export prepared results.
  write.csv(data,file=paste0(path_prep_data,"/",llm_result_file,"-prepared.csv"), row.names =F )
  
  # Clean up loop
  rm(tmp2, tmp3, tmp4, llm_result_file)
}

rm(i, data, llm_mapping_paths, evaluative_mappings, mappable_concepts, 
   path_eval_data, path_prep_data, path_raw_data)
