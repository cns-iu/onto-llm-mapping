#### Set up environment ####
library(magrittr)
library(tidyr)
library(stringr)
library(multcomp)
library(plyr)
library(dplyr)
library(ggplot2)
library(car)
library(AICcmodavg)

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

#### Descriptive Analysis of Concept Mapping Similarity Scores ####
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
  mutate(range = max-min,
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
  mutate(range = max-min,
         std_err = sd/sqrt(mappings)) %>%
  select(model, hit_miss_mapping, mappings_overall, mappings, percent_mappings,
         median, mean, sd, std_err, var, min, max, range)

# Save descriptive statistical analysis results
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

# Plot 1: Box Plot visualizing the distribution of similarity scores, by model and mapping accuracy.
plot1 <-
  data %>%
  filter(model_analyzed==TRUE) %>%
  select(model,hit_miss_mapping, similarity_score) %>%
  ggplot(aes(x=hit_miss_mapping)) + 
    geom_boxplot(aes(y=similarity_score)) +
    facet_wrap(facets=vars(model)) +
    labs(x="Mapping Accuracy", 
         y="Similarity Score (values range 0-1)") +
    theme(panel.grid.major.y = element_line(color="#e1e6eb"))

# Plot 2: Density visualizing the distributions and overlap of similarity scores for mapping accuracy, by model.
plot2 <-
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

# Plot 3: Histogram visualizing the distribution accurate mapping rank, by model.
plot3 <-
  data %>%
  filter(hit_miss_mapping=="Hit") %>%
  select(model,rank, hit_miss_mapping) %>%
  ggplot(aes(rank)) +
    geom_bar() +
    facet_wrap(facets=vars(model)) +
    labs(x="Mapping Rank", 
         y="Accurate Mapping (log)") +
    scale_x_binned(nice.breaks=T, breaks=seq(0,10,1)) +
    scale_y_log10() +
    theme(panel.grid.major.y = element_line(color="#e1e6eb"))

# Save plot results as TIFF and JPEG formatted files
# Plot 1
tiff(filename = paste0(path_results_data,"/figures/",mapping_project,
                       ".boxplot-model_similiarity_score-byAccuracy.tiff"),
     width=5.5, height=6.5, units="in", res=300, type="cairo", compression="lzw")
plot1
dev.off()
jpeg(filename = paste0(path_results_data,"/figures/",mapping_project,
                       ".boxplot-model_similiarity_score-byAccuracy.jpeg"),
     width=5.5, height=6.5, units="in", res=300, type="windows")
plot1
dev.off()
# Plot 2
tiff(filename = paste0(path_results_data,"/figures/",mapping_project,
                       ".density-model_similiarity_score-byAccuracy.tiff"),
     width=5.5, height=5, units="in", res=300, type="cairo", compression="lzw")
plot2
dev.off()
jpeg(filename = paste0(path_results_data,"/figures/",mapping_project,
                       ".density-model_similiarity_score-byAccuracy.jpeg"),
     width=5.5, height=5, units="in", res=300, type="windows")
plot2
dev.off()

# Plot 3
tiff(filename = paste0(path_results_data,"/figures/",mapping_project,
                       ".histogram-accurate_mapping_rank_by_model.tiff"),
     width=5.5, height=5, units="in", res=300, type="cairo", compression="lzw")
plot3
dev.off()

jpeg(filename = paste0(path_results_data,"/figures/",mapping_project,
                       ".histogram-accurate_mapping_rank_by_model.jpeg"),
     width=5.5, height=5, units="in", res=300, type="windows")
plot3
dev.off()

# Clean up environment
rm(plot1,plot2,plot3)

#### Prepare additional categorical factor variables for ANOVA Test####
# Definition Treatment Group
data$treatment_groups <- "RAG Definition (Treatment)"
data[data$model=="human descriptions",]$treatment_groups <- "Human Definitions (Control)"
data$treatment_groups <- factor(data$treatment_groups, 
                                levels=c("RAG Definition (Treatment)",
                                         "Human Definitions (Control)"))

# Mapping Accuracy
data$accurate_mapping <- 
  factor(data$accurate_mapping, 
         levels=c(1,0),
         labels=c("Accurate Mapping",
                  "Inaccurate Mapping"))

# Concept Group (Anatomical Structures & Cell Types)
data$mesh_concept_group <- 
  factor(data$mesh_concept_group,
         levels=c("Anatomical structure",
                  "Cell type"))

#### Analysis of Variance by Model and Mapping Accuracy ####
# Select data where concepts have vector similarity analysis results
data_anova <- data[data$model_analyzed==TRUE,]

# Normalize similarity scores
data_anova$similarity_score_norm <- 
  as.numeric(scale(data_anova$similarity_score, center=T, scale=T))

#### Evaluating ANOVA Test Assumptions ####
# Chi Squared test if Independence of Variables (three ways)
# model and accuracy
chisq.test(table(data_anova$model, data_anova$accurate_mapping), correct = FALSE)
summary(table(data_anova$model, data_anova$accurate_mapping))
# model and concept group
chisq.test(table(data_anova$model, data_anova$mesh_concept_group), correct = FALSE)
summary(table(data_anova$model, data_anova$mesh_concept_group))
# concept group and accuracy
chisq.test(table(data_anova$mesh_concept_group, data_anova$accurate_mapping), correct = FALSE)
summary(table(data_anova$mesh_concept_group, data_anova$accurate_mapping))


#### Compare ANOVA GLM models for Type I, II, & III ANOVA or MANOVA Analysis ####

# H2. Type I1 models
h1_anova_t1.1 <- 
  glm(similarity_score_norm ~ model,
      data=data_anova)
h1_anova_t1.2 <- 
  glm(similarity_score_norm ~ mesh_concept_group,
      data=data_anova)
h1_anova_t1.3 <- 
  glm(similarity_score_norm ~ accurate_mapping,
      data=data_anova)

# H2. Type II models
h2_anova_t2.1 <- 
  glm(similarity_score_norm ~ model * accurate_mapping,
      data=data_anova)
h2_anova_t2.2 <- 
  glm(similarity_score_norm ~ model * mesh_concept_group * accurate_mapping,
      data=data_anova)

# H2. Type III models
h3_anova_t3.1 <-
  glm(similarity_score_norm ~ model * accurate_mapping,
      data=data_anova,
      contrasts=list(model=contr.treatment,
                     # mesh_concept_group = contr.treatment,
                     accurate_mapping=contr.sum))
h3_anova_t3.2 <-
  glm(similarity_score_norm ~ model * mesh_concept_group * accurate_mapping,
      data=data_anova,
      contrasts=list(model=contr.treatment,
                     mesh_concept_group = contr.sum,
                     accurate_mapping=contr.sum))

# Compare model AIC
model.set <- list(h1_anova_t1.1, h1_anova_t1.2, h1_anova_t1.3, 
                  h2_anova_t2.1, h2_anova_t2.2, 
                  h3_anova_t3.1, h3_anova_t3.2)
model.names <- c("h1_anova_t1.1", "h1_anova_t1.2","h1_anova_t1.3",
                 "h2_anova_t2.1", "h2_anova_t2.2","h3_anova_t3.1","h3_anova_t3.2")
mod_aic <- aictab(model.set, modnames = model.names)
mod_aic
# Analysis interpretation: Concept Type Factors account for more variance. Use a MANOVA.
rm(h1_anova_t1.2, h1_anova_t1.3,h2_anova_t2.1, h3_anova_t3.1)

#### Run ANOVA Test
# Type I
# Set-up ANOVA Models, relaxed assumptions of HoV
# Testing Hypothesis 1 (H1) - Oneinstall.versions(-Way ANOVA
h1_1w_anova <- 
  aov(similarity_score ~ model, data=data_anova)

# Type II
h2_manova_t2 <-
  Anova(mod=h2_anova_t2.2, multivariate=T, type="II", test.statistic=c("F"))

# Type III
h2_manova_t3 <-
  Anova(mod=h3_anova_t3.2, type="III", test.statistic=c("F"))

summary(h1_1w_anova)
h2_manova_t2
h2_manova_t3

#### Post-hoc tests ####
#### Test for Independence of Factor Variables ####
durbinWatsonTest(h1_1w_anova)
durbinWatsonTest(h2_anova_t2.2)

#### Test for Normal Distribution ####
# H1
# Shapiro Wilks test (5000 sample)
shapiro.test(sample(h1_1w_anova$residuals, 5000, replace=T))

# Visual checks
par(mfrow = c(1, 2)) # combine plots
# histogram
hist(h1_1w_anova$residuals)
# QQ-plot
qqPlot(h1_1w_anova$residuals,
       id = FALSE)

# H2 & H3
# Shapiro Wilks test (5000 sample)
shapiro.test(sample(h2_anova_t2.2$residuals, 5000, replace=T))

# Visual checks
par(mfrow = c(1, 2)) # combine plots
# histogram
hist(h2_anova_t2.2$residuals)
# QQ-plot
qqPlot(h2_anova_t2.2$residuals,
       id = FALSE)

#### Test Homogeneity of Variance ####
# H1
leveneTest(similarity_score_norm ~ model, 
           data=data_anova, center=median)

# H2
leveneTest(similarity_score_norm ~ model * mesh_concept_group * accurate_mapping, 
           data=data_anova, center=median)

#### Failed all tests for ANOVA use. Move to non-parametric tests. ####

#### Tukey HSD Test - Unreliable conclusions ####
# H1
post_test_h1 <- 
  glht(h1_1w_anova,
      linfct = mcp(model = "Tukey"))

# H2 T2
post_test_h2_m <- 
  glht(h2_anova_t2.2,
       linfct = mcp(model = "Tukey"))
post_test_h2_am <- 
  glht(h2_anova_t2.2,
       linfct = mcp(accurate_mapping = "Tukey"))
post_test_h2_c <- 
  glht(h2_anova_t2.2,
       linfct = mcp(mesh_concept_group = "Tukey"))

# H2 T3
post_test_h3_m <- 
  glht(h3_anova_t3.2,
       linfct = mcp(model = "Tukey"))
post_test_h3_am <- 
  glht(h3_anova_t3.2,
       linfct = mcp(accurate_mapping = "Tukey"))
post_test_h3_c <- 
  glht(h3_anova_t3.2,
       linfct = mcp(mesh_concept_group = "Tukey"))

# Results of Tukey HSD
summary(post_test_h1)

summary(post_test_h2_m)
# summary(post_test_h2_am)
# summary(post_test_h2_c)

summary(post_test_h3_m)
# summary(post_test_h3_am)
# summary(post_test_h3_c)
par(mar = c(3, 15, 3, 3))
plot(post_test_h1)
plot(post_test_h3_m)
plot(post_test_h2_m)
dev.off()

