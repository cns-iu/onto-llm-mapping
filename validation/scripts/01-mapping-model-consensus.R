#### Set up environment ####
library(curl)
library(magrittr)
library(tidyr)
library(plyr)
library(dplyr)
library(stringr)

#### Load data ####
# Set Paths
path_raw_data <- paste0("./raw-data/mesh-uberon-human/v0.0.1")
path_eval_data <- paste0("./validation/evaluation_mappings")
path_prep_data <- paste0("./validation/mesh-uberon-human/v0.0.1")

#Load in LLM mappings 
# currently selects for vector results.
llm_mapping_paths <- 
  list.files(path=paste0(path_raw_data,"/mappings"),
             pattern="sssom.csv", full.names = TRUE)

# Identify mapping project from file path
mapping_project <- unlist(str_split(llm_mapping_paths[1], pattern="\\/"))[[3]]

#### Load Data ####
# CNS Naive SSSOM Mappings
evaluative_mappings <- 
  read.csv(file=paste0(path_eval_data,"/mesh-uberon-human-mapping.validation-lookup-table.csv"),
           header = T, encoding = "UFT-8")

# Mapped concepts
mappable_concepts <- 
  evaluative_mappings[evaluative_mappings$map_state=="Mapped",]$subject_label %>%
  unique()

#### Model consensus concept mapping ####
# Loop through data and select set of mappings
for(i in 1:length(llm_mapping_paths)){
  # Load data
  data <- read.csv(file=llm_mapping_paths[i],
                   header = T, encoding = "UFT-8")
  
  # Create temp data and extract project name
  if(i==1){
    tmp <- data[-c(1:nrow(data)),]
    }

  model <- tail(unlist(str_split(llm_mapping_paths[i], pattern="\\/")),1) %>% 
    str_remove(paste0(mapping_project,"-mapping.")) %>%
    str_remove(".sssom.csv") %>%
    str_remove("-vec")
  
  # Create concept_pair_rank values for subject concept mapping results, select results.
  data <-
    data %>% 
    group_by(subject_id) %>% 
    mutate(rank = row_number()) %>%
    ungroup() %>%
    filter(rank==1)
  
  # Add model identifier
  data$model <- model
  data$vote <- 1
  
  # Combine selected concept mappings to tmp data frame
  tmp <- rbind(tmp,data)
  rm(data)
}

# Update desc model name to human descriptions.
tmp[tmp$model=="desc",]$model <- "human descriptions"

##### Model vote tabulation ####
mapping_consensus <- 
  tmp %>%
  ddply(.(subject_id, object_id, subject_label, object_label, predicate_id), summarise,
        mean_similarity = mean(similarity_score),
        votes = sum(vote)) %>%
  arrange(subject_id,desc(votes))

##### Mapping model vote participation ####
mapping_participants <- 
  tmp %>%
  select(subject_id, model) %>%
  distinct() %>%
  ddply(.(subject_id), summarise,
        participants = length(model))
mapping_consensus <- 
  left_join(mapping_consensus, mapping_participants, by="subject_id")

##### Mapping options ####
mapping_options <- 
  mapping_consensus %>%
  ddply(.(subject_id), nrow)
names(mapping_options)[2] <- "opts"

# Combine mapping_options data to mapping_consensus
mapping_consensus <- left_join(mapping_consensus, mapping_options, by="subject_id")

# Vote Share
mapping_consensus$share <- mapping_consensus$votes/mapping_consensus$participants

# Create subset of mappings votes based on similarity of human generated description 
human_desc <- tmp[tmp$model=="human descriptions",c(1,4,11)]
names(human_desc)[3] <- "human_desc_vec_sim"

# Pull out human definition vector similarity vote and update NAs to 0
mapping_consensus <- left_join(mapping_consensus, human_desc, by=c("subject_id","object_id"))
mapping_consensus[is.na(mapping_consensus$human_desc_vec_sim),]$human_desc_vec_sim <- 0

##### Identify tied mappings (vote tallies) #####
ties <- 
  mapping_consensus %>%
  select(subject_id, participants, votes) %>%
  ddply(.(subject_id), summarise,
        max_votes = max(votes),
        participants = max(participants),
        opts = length(votes)) %>%
  mutate(ties=0, note="Not a tie.")
names(ties)[2] <- "votes"

# Pattern review - no consensus between models.
ties[ties$participants==ties$opts, ]$ties <- 1 

# Patter review - consensus ties, between 4 and 5 models
ties[ties$participants==5 & ties$opts==3 & ties$votes==2, ]$ties <- 1
ties[ties$participants==4 & ties$opts==2 & ties$votes==2, ]$ties <- 1

ties <- 
  ties %>% 
  select(participants, opts, votes, ties) %>%
  distinct()

# Identify ties in mapping set and remove NAs
mapping_consensus <- 
  left_join(mapping_consensus, ties, 
            by=c("votes", "participants", "opts"))
mapping_consensus[is.na(mapping_consensus$ties),]$ties <- 0

#### Evaluate votes based on current ground truth ####
# Create mapping pair identifier
mapping_consensus$pair_id <- 
  paste0(mapping_consensus$subject_id,"|",mapping_consensus$object_id)

# Evaluate vote based model using ground truth data
# selects pair_id, map_state, and accuracy 
tmp2 <- 
  evaluative_mappings %>% 
  select(pair_id, map_state, accuracy) %>%
  filter(map_state == "Mapped")
mapping_consensus <-
  join(mapping_consensus, tmp2,
       by="pair_id")
rm(tmp2)

# Identify unmapped MeSH concepts
unmapped <- 
  evaluative_mappings %>%
  filter(map_state == "Unmapped") %>%
  select(subject_id)

# Update concept map_state variable
mapping_consensus[mapping_consensus$subject_id %in% unmapped$subject_id,]$map_state <- "Unmapped"
mapping_consensus[mapping_consensus$map_state != "Unmapped" |
                  is.na(mapping_consensus$map_state) ,]$map_state <- "Mapped"

rm(mapping_options,mapping_participants, ties)

# Update accuracy score for records with NA values.
mapping_consensus[mapping_consensus$map_state == "Unmapped",]$accuracy <- 0
mapping_consensus[mapping_consensus$map_state == "Mapped" &
                  is.na(mapping_consensus$accuracy),]$accuracy <- 0

##### Identify the number of mapping records that earned votes ####
# 1. order by vote count and mean similarity score for mapping result candidate
# 2. create ranking order variable
mapping_consensus <-
  mapping_consensus %>%
  arrange(map_state, subject_id, desc(votes),
          desc(mean_similarity)) %>%
  group_by(subject_id) %>%
  mutate(concept_pair_rank = row_number()) %>%
  ungroup()

##### Copy over subject concept: mesh_concept_group & mapping count
tmp3 <- 
  evaluative_mappings %>%
  select(subject_id, mesh_concept_group, mapping_count)
mapping_consensus <- 
  join(mapping_consensus, tmp3, by="subject_id")
rm(tmp3)

# Mapping level variables: mapping_result_number & mapping_justification, model, model_analysis
# mapping_result_number
tmp4 <- 
  mapping_consensus %>%
  filter(accuracy==1) %>%
  group_by(subject_id) %>%
  mutate(mapping_result_number=row_number()) %>%
  ungroup() %>%
  select(pair_id, mapping_result_number)
mapping_consensus <- join(mapping_consensus, tmp4, by="pair_id")
mapping_consensus[is.na(mapping_consensus$mapping_result_number),]$mapping_result_number <- 0
rm(tmp4)

# mapping_justification
mapping_consensus$mapping_justification <- "semapv:SemanticSimilarity"

# Mapping result model name
mapping_consensus$model <- model <- paste0("pooled-K1-vec-vote")

# model_analyzed
tmp5 <- 
  evaluative_mappings %>%
  select(subject_id) %>%
  distinct() %>%
  mutate(model_analyzed=TRUE)
mapping_consensus <- join(mapping_consensus, tmp5, by="subject_id")
if(nrow(mapping_consensus[is.na(mapping_consensus$model_analyzed),])>0) {
  mapping_consensus[is.na(mapping_consensus$model_analyzed),]$model_analyzed <- FALSE
}
rm(tmp5)

# Top mapping vote earner is accuracy 
mapping_consensus$top_vote_correct <- NA
mapping_consensus[mapping_consensus$accuracy==1 &
                  mapping_consensus$concept_pair_rank==1 & 
                  mapping_consensus$ties==0,]$top_vote_correct <- 1

# Hit Miss
# Creates hit_miss_mapping variable.
mapping_consensus$hit_miss_mapping <- "Miss"

# Update hit_miss_mapping variable.
mapping_consensus[mapping_consensus$accuracy==1,]$hit_miss_mapping <- "Hit"

# Create hit_miss_concept
tmp6 <-
  mapping_consensus %>%
  filter(hit_miss_mapping=="Hit") %>%
  select(subject_id) %>%
  distinct() %>%
  mutate(hit_miss_concept="Hit")
mapping_consensus <- join(mapping_consensus, tmp6, by="subject_id")
if(nrow(mapping_consensus[is.na(mapping_consensus$hit_miss_concept),])>0) {
    mapping_consensus[is.na(mapping_consensus$hit_miss_concept),]$hit_miss_concept <- "Miss"
  }
rm(tmp6)

# Save data as mapping results evaluation look up table - working - all variables
# Arrange variables for saving results
names(mapping_consensus)[6] <- c("similarity_score")

mapping_consensus_eval <-
  mapping_consensus %>%
  select(subject_id, predicate_id, object_id,
         pair_id, subject_label, object_label, map_state, mesh_concept_group, 
         similarity_score, participants, opts, votes, share, human_desc_vec_sim,
         ties, accuracy, model, model_analyzed, mapping_justification) %>%
  mutate(reviewer_id="",confidence="")

# Save data
write.csv(mapping_consensus_eval,
          file=paste0(path_eval_data,"/",mapping_project,"-mapping.",model,".lookup-table.csv"),
          row.names = F, fileEncoding = "UTF8")

# Save data as mapping results for result evaluation - select variables
# Filter out Un-Mapped terms
mapping_consensus_filtered <-
  mapping_consensus %>%
  filter(map_state=="Mapped") %>%
  select(model, mapping_justification, subject_id,	predicate_id,	object_id,
         pair_id, subject_label, object_label, mesh_concept_group, 
         similarity_score, accuracy, concept_pair_rank, mapping_count, 
         mapping_result_number, hit_miss_concept, hit_miss_mapping, 
         model_analyzed)

# Save data
write.csv(mapping_consensus_filtered,
          file=paste0(path_prep_data,"/",mapping_project,"-mapping.",model,".prepared.csv"),
          row.names = F, fileEncoding = "UTF8")

# Clean up environment
rm(i, llm_mapping_paths, mapping_project, model,
   path_eval_data, path_prep_data, path_raw_data,
   evaluative_mappings, human_desc, ties, tmp,
   unmapped, mapping_consensus, mappable_concepts)
