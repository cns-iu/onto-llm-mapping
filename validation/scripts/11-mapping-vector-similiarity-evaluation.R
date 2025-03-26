#### Set up environment ####
library(magrittr)
library(tidyr)
library(stringr)
library(plyr)
library(dplyr)
library(ggplot2)

#### Set Paths ####
# Paths
path_prep_data <- paste0("./validation/mesh-uberon-human/v0.0.1")
path_eval_data <- paste0("./validation/evaluation_mappings")

# Create results directory and path 
path_results_data  <- paste0(path_prep_data,"/results")
if(dir.exists(path_results_data)==FALSE){
  dir.create(path_results_data) 
}

#### Load data ####
# Load prepared in LLM mappings 
# currently selects for vector results.
llm_mapping_paths <- 
  list.files(path=path_prep_data,
             pattern="prepared.csv", full.names = TRUE) %>%
  as.data.frame()
names(llm_mapping_paths) <- "path"

# Identify mapping project from file path
mapping_project <- unlist(str_split(llm_mapping_paths[1], pattern="\\/"))[[3]]

# Select paths that are not pooled.
llm_mapping_paths <- 
    llm_mapping_paths[-grep("pooled", llm_mapping_paths$path),]

#### Combine prepared concept mapping sets ####
# Loop through data and select set of mappings
for(i in 1:length(llm_mapping_paths)){
  # Load data
  tmp <- read.csv(file=llm_mapping_paths[i],
                   header = T, encoding = "UFT-8")
  
  # Create temp data and extract project name
  if(i==1){
    data <- tmp[-c(1:nrow(tmp)),]
  }
  
  # Generate name of model
  model <- 
    tail(unlist(str_split(llm_mapping_paths[i], pattern="\\/")),1) %>% 
    str_remove(paste0(mapping_project,"-mapping.")) %>%
    str_remove(".sssom.csv") %>%
    str_remove("-vec") %>%
    str_remove("-prepared.csv")
  
  # Create concept_pair_rank values for subject concept mapping results, select results.
  tmp <-
    tmp %>% 
    group_by(subject_id) %>% 
    mutate(rank = row_number()) %>%
    ungroup()
  
  # Add model identifier
  tmp$model <- model

  # Combine selected concept mappings to tmp data frame
  data <- 
    rbind(data,tmp)
  rm(tmp)
}
rm(i,model)

# Update model name 
data[data$model=="desc",]$model <- "human descriptions"

# Create factor variable
data$model <- factor(data$model, levels=c("human descriptions","llama3.2-3b.llm","gpt4o.llm",
                                          "phi4-14b.llm","curategpt"))

# Update rank for rank when model did not evaluate mapping.
data[data$model_analyzed==FALSE,]$rank <- 0

#### Data Selection ####
data <- 
  data %>%
  #filter(model_analyzed=="TRUE") %>%
  select(model,pair_id, subject_id, object_id, subject_label, object_label, 
         mesh_concept_group, hit_miss_mapping, accurate_mapping, similarity_score, rank, model_analyzed)

#### Analysis of Concept Mapping Similarity Scores ####
# Calculating Concept Mapping Similarity Score Descriptive Statistics, by Model
model_mapping_counts <- 
  data %>% 
  filter(model_analyzed==TRUE) %>%
  ddply(.(model), nrow) %>%
  rename(mappings="V1")

descriptives_model <- 
  data %>% 
  filter(model_analyzed==TRUE) %>%
  ddply(.(model), summarise,
        median = median(similarity_score, na.rm = T),
        mean = mean(similarity_score, na.rm = T),
        sd = sd(similarity_score, na.rm = T),
        var = var(similarity_score, na.rm = T),
        min = min(similarity_score, na.rm = T),
        max = max(similarity_score, na.rm = T)) %>%
  left_join(model_mapping_counts, by="model") %>%
  mutate(
    range = min-max,
    std_err = sd/sqrt(mappings)) %>%
  select(model, mappings, median, mean, sd, std_err, var, min, max, range)

# Calculating Concept Mapping Similarity Score Descriptive Statistics, by Model & Accuracy #
model_hit_miss_counts <- 
  data %>% 
  filter(model_analyzed==TRUE) %>%
  mutate(hit_miss_mapping = tolower(hit_miss_mapping)) %>%
  ddply(.(model, hit_miss_mapping), nrow) %>% 
  rename(mappings="V1") %>% 
  right_join(model_mapping_counts, by="model") %>% 
  rename(mappings="mappings.x", mappings_overall="mappings.y") %>%
  mutate(percent_mappings=round(mappings/mappings_overall*100,2)) %>%
  select(model, hit_miss_mapping, mappings_overall, mappings, percent_mappings)

descriptives_model_accuracy <- 
  data %>% 
  filter(model_analyzed==TRUE) %>%
  mutate(hit_miss_mapping = tolower(hit_miss_mapping)) %>%
  ddply(.(model, hit_miss_mapping), summarise,
        median = median(similarity_score, na.rm = T),
        mean = mean(similarity_score, na.rm = T),
        sd = sd(similarity_score, na.rm = T),
        var = var(similarity_score, na.rm = T),
        min = min(similarity_score, na.rm = T),
        max = max(similarity_score, na.rm = T)) %>%
  left_join(model_hit_miss_counts, by=c("model","hit_miss_mapping")) %>%
  mutate(
    range = min-max,
    std_err = sd/sqrt(mappings)) %>%
  select(model, hit_miss_mapping, mappings_overall, mappings, percent_mappings,
         median, mean, sd, std_err, var, min, max, range)

# Save results
write.csv(descriptives_model, 
          file=paste0(path_results_data,"/descriptive_statistics/",mapping_project,
                      ".model_similiarity_score_descriptives.csv"),
          row.names = FALSE)
write.csv(descriptives_model_accuracy, 
          file=paste0(path_results_data,"/descriptive_statistics/",mapping_project,
                      ".model+accuracy_similiarity_score_descriptives.csv"),
          row.names = FALSE)

#### Visualization Distributions of model similarity scores and ranks ####
# Set up visualization themes
theme_set(theme_grey())
theme_update(
  plot.tag = element_text(color="#202f3d"),
  plot.title = element_text(color="#202f3d"),
  plot.title.position = "plot",
  plot.subtitle = element_text(color="#202f3d"),
  plot.background = element_rect(fill="White"),
  plot.caption = element_text(hjust = 0, 
                              color="#202f3d", 
                              face= "italic"),
  plot.caption.position = "plot",
  panel.grid.major.x = element_blank(),
  panel.grid.major.y = element_blank(),
  panel.grid.minor.x = element_blank(),
  panel.grid.minor.y = element_blank(),
  panel.background = element_rect(fill="White"),
  panel.border = element_rect(fill=NA, 
                              color="#92a0ae",
                              linetype="solid"),
  
  strip.background = element_rect(fill="#e1e6eb"),
  strip.placement = "outside",
  strip.text.x = element_text(vjust=0, 
                              color="#202f3d"),
  strip.text.y = element_text(vjust=0, 
                              color="#202f3d"),
  axis.title = element_text(color="#202f3d"),
  axis.text = element_text(color="#202f3d"),
  axis.ticks = element_line(color="#92a0ae"),
  legend.position = "none",
  legend.background = element_rect(fill="White"),
  legend.margin = margin(t=1,r=1,b=1,l=1, unit="pt"),
  legend.title = element_text(hjust=.1, 
                              color="#493828"),
  legend.text = element_text(hjust=.1, 
                             color="#493828"),
  legend.key = element_rect(fill="White"))

# Box Plot visualizing the distribution of similarity scores, by model and mapping accuracy.
tiff(filename = paste0(path_results_data,"/figures/",mapping_project,
                       ".boxplot-model_similiarity_score-byAccuracy.tiff"),
     width=5.5, height=6.5, units="in", res=300, type="cairo", compression="lzw")
jpeg(filename = paste0(path_results_data,"/figures/",mapping_project,
                       ".boxplot-model_similiarity_score-byAccuracy.jpeg"),
     width=5.5, height=6.5, units="in", res=300, type="windows")

data %>%
  filter(model_analyzed==TRUE) %>%
  select(model,hit_miss_mapping, similarity_score) %>%
  ggplot(aes(x=hit_miss_mapping)) + 
    geom_boxplot(aes(y=similarity_score)) +
    facet_wrap(facets=vars(model)) +
    labs(x="Mapping Accuracy", 
         y="Similarity Score (values range 0-1)") +
    theme(panel.grid.major.y = element_line(color="#e1e6eb"))
dev.off()

# Density visualizing the distributions and overlap of similarity scores for mapping accuracy, by model.
tiff(filename = paste0(path_results_data,"/figures/",mapping_project,
                       ".density-model_similiarity_score-byAccuracy.tiff"),
     width=5.5, height=5, units="in", res=300, type="cairo", compression="lzw")
jpeg(filename = paste0(path_results_data,"/figures/",mapping_project,
                       ".density-model_similiarity_score-byAccuracy.jpeg"),
     width=5.5, height=5, units="in", res=300, type="windows")
data %>%
  filter(model_analyzed==TRUE) %>%
  select(model,hit_miss_mapping, similarity_score) %>%
  ggplot(aes(similarity_score)) +
    geom_density(aes(color=hit_miss_mapping, 
                     fill=hit_miss_mapping),
                 alpha=.4) +
    facet_wrap(facets=vars(model)) +
    labs(x="Similarity Score (values range 0-1)", 
         y="Density") +
    theme(panel.grid.major.y = element_line(color="#e1e6eb"))
dev.off()

