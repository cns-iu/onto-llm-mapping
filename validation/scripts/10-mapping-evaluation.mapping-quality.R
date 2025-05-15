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
path_results_data  <- paste0(path_prep_data,"/results")
if(dir.exists(path_results_data)==FALSE){
  dir.create(path_results_data) 
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

# Load prepared in LLM mappings 
# currently selects for vector results.
llm_mapping_paths <- 
  list.files(path=path_prep_data,
             pattern="prepared.csv", full.names = TRUE)

# Load Ground Truth mapping Data
evaluative_mappings <- 
  read.csv(file=paste0(path_eval_data,"/mesh-uberon-human-mapping.validation-lookup-table.csv"),
           header = T, encoding = "UFT-8")

# Identify mapped concepts from initial set of subject concepts
mappable_concepts <- 
  evaluative_mappings[evaluative_mappings$map_state=="Mapped",]$subject_id %>%
  unique()

#### Create evaluation result mapping data frame ####
evaluation_results <- 
  data.frame(model = character(),
             mapping_results = numeric(),
             mappable_concepts = numeric(),
             mapped_concepts = numeric(),
             skipped_concepts = numeric(),
             mapped_concepts_percent = numeric(),
             hit = numeric(),
             hit_as = numeric(),
             hit_ct = numeric(),
             miss = numeric(),
             miss_as = numeric(),
             miss_ct = numeric(),
             hit_percent = numeric(),
             hit_as_percent = numeric(), 
             hit_ct_percent = numeric(),
             miss_percent = numeric(),
             miss_as_percent = numeric(),
             miss_ct_percent = numeric(),
             mean_k = numeric(),
             mean_precision = numeric(),
             mean_recall = numeric(),
             f_score = numeric(),
             beta = numeric(),
             mean_reciprocal_rank = numeric(),
             mean_reciprocal_rank_sd = numeric()
             )

# Identify SSSOM mapping project
project <- paste((str_split(llm_mapping_paths[1],"/")[[1]][3]))

#### Characterize MeSH Subject Concepts and Mappings ####
# MeSH Subject Concept Counts - Overall and by Concept Grouping
subject_concepts <- data.frame("group"=c("Overall"),
                               "subject_concepts"=nrow(source_concept))
subject_concepts_as <- data.frame("group"=c("Anatomical structure"),
                                  "subject_concepts"=
                                    length(unique(evaluative_mappings[evaluative_mappings$mesh_concept_group=="Anatomical structure",]$subject_label)))
subject_concepts_ct <- data.frame("group"=c("Cell type"),
                                  "subject_concepts"=
                                    length(unique(evaluative_mappings[evaluative_mappings$mesh_concept_group=="Cell type",]$subject_label)))
subject_concepts <- rbind(subject_concepts_as, subject_concepts_ct, subject_concepts)
# subject_concepts_as_ct <- subject_concepts_as + subject_concepts_ct
# subject_concepts_other <- subject_concepts - subject_concepts_as_ct

##### Characterizing unmapped MeSH Concepts ####
# by concept groups
mesh_unmapped_concepts <- 
  evaluative_mappings %>%
  filter(map_state=="Unmapped") %>% 
  ddply(.(mesh_concept_group), summarise,
        unmapped_subject_concepts = length(subject_id)) %>%
  arrange(mesh_concept_group, desc(unmapped_subject_concepts)) %>%
  mutate(percent_subject_concept = round(unmapped_subject_concepts/
                                         nrow(subject_concepts),2)) %>%
  rename(c("group"="mesh_concept_group"))

mesh_unmapped_concepts <-
  rbind(mesh_unmapped_concepts, 
        data.frame(group=c("Overall"),
                   unmapped_subject_concepts=
                     sum(mesh_unmapped_concepts$unmapped_subject_concepts),
                   percent_subject_concept=round(sum(mesh_unmapped_concepts$unmapped_subject_concepts)/
                                                 nrow(subject_concepts),2)))
# Unmapped Subject Concepts Broken out by exclusion reason
mesh_unmapped_concepts_rational <- 
  evaluative_mappings %>%
  filter(map_state=="Unmapped") %>% 
  ddply(.(mesh_concept_group, exclusion_reason), summarise,
        subject_concepts = length(subject_id)) %>%
  rename(c("group"="mesh_concept_group"))

# Combine both calculation data frames.
mesh_unmapped_concepts_rational <- 
  join(mesh_unmapped_concepts_rational, 
       mesh_unmapped_concepts[,1:2], by="group") %>%
  mutate(percent_group_unmapped_subject_concept = 
           round(subject_concepts/
                 unmapped_subject_concepts*100,2)) %>%
  select(-unmapped_subject_concepts) %>%
  arrange(group, desc(subject_concepts))

# Save results and clean up environment
write.csv(mesh_unmapped_concepts,
          file=paste0(path_results_data,"/",project,".unmapped_subject_concepts.desc_statistics.csv"),
          row.names = FALSE, fileEncoding = "UTF8")

write.csv(mesh_unmapped_concepts_rational,
          file=paste0(path_results_data,"/",project,".unmapped_subject_concepts.exclusions_breakout.csv"),
          row.names = FALSE, fileEncoding = "UTF8")

rm(mesh_unmapped_concepts_rational, mesh_unmapped_concepts)

# Mapped Subject Concept Counts and Percentages - Overall and by Concept Grouping
mapped_concepts <-
  evaluative_mappings %>%
  filter(map_state=="Mapped") %>%
  select(subject_id, subject_label, mesh_concept_group, mapping_count) %>%
  distinct() %>%
  group_by("group"=mesh_concept_group) %>%
  count() %>%
  ungroup() %>% 
  rename(c("mapped_subject_concepts"="n")) %>%
  rbind(data.frame(group=c("Overall"),
                   mapped_subject_concepts=length(mappable_concepts))) %>%
  mutate(percentage_mapped_concepts =
           round(mapped_subject_concepts/length(mappable_concepts)*100,2))

mapped_concepts <-
  left_join(subject_concepts, mapped_concepts, by="group") %>%
  mutate(percent_subject_concepts_mapped =
           round(mapped_subject_concepts/subject_concepts*100,2)) %>%
  select(group, subject_concepts, mapped_subject_concepts, 
         percent_subject_concepts_mapped, percentage_mapped_concepts)

# Subject Concept Recalls (Mappings) - Overall and by Concept Grouping
mapping_recalls <- data.frame(group=c("Overall"),
                              mapping_recalls=
                                nrow(evaluative_mappings[evaluative_mappings$map_state=="Mapped",]))
mapping_recalls <-
  evaluative_mappings %>%
  filter(map_state=="Mapped") %>%
  ddply(.(mesh_concept_group), summarise, 
        mapping_recalls = length(subject_id)) %>%
  rename(c("group"="mesh_concept_group")) %>%
  rbind(mapping_recalls)

# Combine mapped concepts and recall count and percentage statistics.
mapped_concepts_desc <- 
  join(mapped_concepts, mapping_recalls, by="group") %>%
  mutate(avg_mapped_concept_recalls = 
           round(mapping_recalls/mapped_subject_concepts, 2))

# Save results and clean up environment
write.csv(mapped_concepts_desc,
          file=paste0(path_results_data,"/",project,".mapped_subject_concepts.desc_statistics.csv"),
          row.names = FALSE, fileEncoding = "UTF8")

rm(mapped_concepts_desc, mapping_recalls, mapped_concepts, 
   subject_concepts, subject_concepts_as, subject_concepts_ct)

# UBERON and CL Concept Counts
target_concepts <- nrow(target_concept)
target_concepts_as <- nrow(target_concept[grepl("http://purl.obolibrary.org/obo/UBERON_",
                                                target_concept$iri)==T,])
target_concepts_ct <- nrow(target_concept[grepl("http://purl.obolibrary.org/obo/CL_",
                                                target_concept$iri)==T,])











#### Evaluate LLM Mapping Results ####
# Set F-score beta
beta = 2

# Evaluates concept mapping sets generated by LLM using metrics:
# hit-miss stats, precision, recall, f-score, & MRR.
# Loop through each data file to calculate top line stats, hit-miss rates,
# f-scores, mrr and mac scores for each set of prepared model results.
for(i in 1:length(llm_mapping_paths)){
  # Load data
  data <- read.csv(file=llm_mapping_paths[i],
                   header = T, encoding = "UFT-8")
  
  # Identify project model
  model <- unique(data$model)
  
  # Top line evaluation - subject concepts with and without mapping results (skipped).
  results_subject_concepts_mapped <- 
    data %>% 
    filter(model_analyzed==TRUE) %>% 
    select(model,subject_id) %>% 
    distinct() %>%
    ddply(.(model), summarise,
          mapping_results = nrow(data),
          mappable_concepts = mappable_concepts,
          mapped_concepts = length(subject_id),
          skipped_concepts = mappable_concepts - length(subject_id),
          mapped_concepts_percent = round(length(subject_id)/mappable_concepts, 3))

  # Calculate hit and miss statistics for model results
  results_hit_miss <-
    data %>%
    select(model, subject_id, hit_miss_concept) %>%
    distinct() %>%
    mutate(value=1) %>% 
    pivot_wider(id_cols = model, 
                names_from = hit_miss_concept,
                values_from = value,
                values_fn = length) %>%
    mutate(hit_percent = round(Hit/mappable_concepts,2),
           miss_percent = round(Miss/mappable_concepts,2)) %>%
    select(model,Hit,Miss,hit_percent, miss_percent)
  names(results_hit_miss)[2:3] <- c("hit","miss")
  
  # Calculate hit and miss statistics for model results - Group level
  results_hit_miss_groups <-
    data %>%
      select(model, subject_id, mesh_concept_group, hit_miss_concept) %>%
      distinct() %>%
      mutate(Value=1) %>%
      pivot_wider(id_cols = model, 
                  names_from = c(hit_miss_concept, mesh_concept_group), 
                  values_from = Value,
                  values_fn = length) %>%
    select(model,'Hit_Anatomical structure','Miss_Anatomical structure',
           'Hit_Cell type', 'Miss_Cell type',)
  names(results_hit_miss_groups)[2:5] <- c("hit_as","miss_as","hit_ct","miss_ct")
  results_hit_miss_groups <-
    results_hit_miss_groups %>%
    mutate(hit_as_percent= round(hit_as/mappable_concepts_as,2), 
           miss_as_percent= round(miss_as/mappable_concepts_as,2),
           hit_ct_percent= round(hit_ct/mappable_concepts_ct,2),
           miss_ct_percent= round(miss_ct/mappable_concepts_ct,2)) 

  # Precision at L
  precision <- 
    data %>%
    select(model, subject_id, accuracy, concept_pair_rank) %>%
    ddply(.(model, subject_id), summarise,
          score_at_k = max(accuracy),
          precision_k = max(concept_pair_rank),
          precision = max(accuracy)/max(concept_pair_rank))
  
  # Clean up precision for concepts llm skipped.
  if(nrow(precision[is.na(precision$precision_k),])>0){ 
    precision[is.na(precision$precision_k),]$precision_k <- 0
    precision[is.na(precision$precision),]$precision <- 0
  }
  
  # Recall at L
  recall <- 
    data %>%
    select(model, subject_id, accuracy, mapping_count) %>%
    ddply(.(model, subject_id), summarise,
          score_at_k = sum(accuracy),
          recall_k = max(mapping_count),
          recall = sum(accuracy)/max(mapping_count))
  
  # Save model precision and recall calculations
  mapping_scores_tmp <- 
    join(precision, recall, by=c("model", "subject_id"))
  mapping_scores_tmp <- mapping_scores_tmp[,c(1:5,7:8)]
  write.csv(mapping_scores_tmp, 
            file=paste0(path_results_data,"/precision_recall/",model,
                        "-precision-recall-calculations.csv"),
            row.names = FALSE)
  
  # Mean Precision and Recall, calculate F-score at K
  results_fscore <- 
    mapping_scores_tmp %>%
    ddply(.(model), summarise,
          mean_k = mean(precision_k, na.rm=T),
          mean_precision = mean(precision, na.rm = T),
          mean_recall = mean(recall, na.rm = T)) %>%
    mutate(f_score=((1+beta^2)*mean_precision*mean_recall)/((beta^2*mean_precision)+mean_recall),
           beta = beta)
  
  # Clean up
  rm(precision, recall, mapping_scores_tmp)
  
  # Calculate Concept Level - Mean Reciprocal Rank (MRR)
  # 1. Calculate reciprocal rank values for mapping records.
  tmp0 <- 
    data %>%
    mutate(reciprocal_rank = mapping_result_number/concept_pair_rank)
  
  # 2. Calculate reciprocal rank for accurately mapped concepts.
  tmp1 <-
    tmp0 %>%
    filter(mapping_result_number==1) %>%
    select(model, subject_id, reciprocal_rank)
  
  # 3. Calculate reciprocal rank for missed concepts.
  tmp2 <- 
    tmp0 %>%
    filter(hit_miss_concept=="Miss", 
           is.na(reciprocal_rank) == FALSE) %>% 
    ddply(.(model, subject_id), summarise,
          reciprocal_rank = mean(reciprocal_rank, na.rm=TRUE))
  
  # 4. Combine reciprocal rank calculations for each subject concept.
  results_rr <- 
    union(tmp1,tmp2)
  write.csv(results_rr, 
            file=paste0(path_results_data,"/reciprocal_rank/",model,
                        "-concept-reciprocal-rank-calculations.csv"),
            row.names = FALSE)
  rm(tmp0, tmp1, tmp2)
  
  # 5. Calculate mean reciprocal rank for the model
  results_mrr <-
    results_rr %>%
    ddply(.(model), summarise,
          mean_reciprocal_rank = mean(reciprocal_rank, na.rm=TRUE),
          mean_reciprocal_rank_sd = sd(reciprocal_rank, na.rm=TRUE))
  
  # Combine model evaluation statistics and organize variables.
  evaluation_results_tmp <- 
    left_join(results_subject_concepts_mapped, results_hit_miss,
              by="model") %>%
    left_join(., results_hit_miss_groups, by="model") %>%
    left_join(., results_fscore, by="model") %>%
    left_join(., results_mrr, by="model") %>%
    select(model,  mapping_results, mappable_concepts,
           mapped_concepts, skipped_concepts, mapped_concepts_percent,
           hit, hit_as, hit_ct, miss, miss_as, miss_ct, 
           hit_percent, hit_as_percent, hit_ct_percent, 
           miss_percent, miss_as_percent, miss_ct_percent, 
           mean_k, mean_precision, mean_recall, f_score, beta,
           mean_reciprocal_rank, mean_reciprocal_rank_sd)
  
   # Add model level statistics to data frame
   evaluation_results <- rbind(evaluation_results, evaluation_results_tmp)
}

# save model evaluation results
write.csv(evaluation_results, 
          file=paste0(path_results_data,"/",project,
                      "-model-evaluation-results.csv"),
          row.names = FALSE)
