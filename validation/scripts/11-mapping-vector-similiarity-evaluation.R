#### Set up environment ####
library(magrittr)
library(tidyr)
library(stringr)
library(multcomp)
library(dplyr)
library(plyr)
library(ggplot2)
library(car)
library(AICcmodavg)

##### Set Paths and Directories ####
# Paths
path_data <- paste0("./validation/mesh-uberon-human/v0.0.1")
path_eval_data <- paste0("./validation/evaluation_mappings")
path_results_data  <- paste0(path_data,"/results")

# Create directories for results
if(dir.exists(path_results_data)==FALSE){
  dir.create(path_results_data) 
}
# descriptive statistics
if(dir.exists(paste0(path_results_data,"/descriptive_statistics"))==FALSE){
  dir.create(paste0(path_results_data,"/descriptive_statistics")) 
}
# similarity score variance analysis
if(dir.exists(paste0(path_results_data,"/similarity_score_variance"))==FALSE){
  dir.create(paste0(path_results_data,"/similarity_score_variance")) 
}

#### Load data ####
# Load prepared in LLM mappings 
# currently selects for vector results.
llm_mapping_paths <- 
  list.files(path=path_data,
             pattern="prepared.csv", full.names = TRUE) %>%
  as.data.frame()
names(llm_mapping_paths) <- "path"

# Identify mapping project from file path
mapping_project <- unlist(str_split(llm_mapping_paths[1], pattern="\\/"))[[3]]

# Select paths that are not pooled.
llm_mapping_paths <- 
    llm_mapping_paths[-grep("pooled", llm_mapping_paths$path),]

##### Combine prepared mapping data sets ####
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
    dplyr::mutate(rank = row_number()) %>%
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

##### Data Selection #####
data <- 
  data %>%
  filter(model_analyzed=="TRUE") %>%
  dplyr::select(model,pair_id, subject_id, object_id, subject_label, object_label, 
                mesh_concept_group, hit_miss_mapping, accuracy, similarity_score, 
                rank, model_analyzed)

#### Descriptive Analysis of Concept Mapping Similarity Scores ####
# Calculating Concept Mapping Similarity Score Descriptive Statistics, by Model
model_mapping_counts <- 
  data %>% 
  filter(model_analyzed==TRUE) %>%
  ddply(.(model), nrow) %>%
  dplyr::rename(mappings="V1")

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
  dplyr::select(model, mappings, median, mean, sd, std_err, var, min, max, range)

# Calculating Concept Mapping Similarity Score Descriptive Statistics, by Model & Accuracy #
model_hit_miss_counts <- 
  data %>% 
  filter(model_analyzed==TRUE) %>%
  mutate(hit_miss_mapping = tolower(hit_miss_mapping)) %>%
  ddply(.(model, hit_miss_mapping), nrow) %>% 
  dplyr::rename(mappings="V1") %>% 
  right_join(model_mapping_counts, by="model") %>% 
  dplyr::rename(mappings="mappings.x", mappings_overall="mappings.y") %>%
  mutate(percent_mappings=round(mappings/mappings_overall*100,2)) %>%
  dplyr::select(model, hit_miss_mapping, mappings_overall, mappings, percent_mappings)

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
  dplyr::select(model, hit_miss_mapping, mappings_overall, mappings, 
                percent_mappings, median, mean, sd, std_err, var, min, max, 
                range)

# Save descriptive statistical analysis results
write.csv(descriptives_model, 
          file=paste0(path_data,"/results/descriptive_statistics/",mapping_project,
                      ".model-similiarity_score_descriptives.csv"),
          row.names = FALSE)
write.csv(descriptives_model_accuracy, 
          file=paste0(path_data,"/results/descriptive_statistics/",mapping_project,
                      ".model+hit_miss-similiarity_score_descriptives.csv"),
          row.names = FALSE)

##### Visualization Distributions of model similarity scores and ranks #####
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
  dplyr::select(model,hit_miss_mapping, similarity_score) %>%
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
  dplyr::select(model,hit_miss_mapping, similarity_score) %>%
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
  dplyr::select(model,rank, hit_miss_mapping) %>%
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
tiff(filename = paste0(path_data,"/results/figures/",mapping_project,
                       ".boxplot-model_similiarity_score-byAccuracy.tiff"),
     width=5.5, height=6.5, units="in", res=300, type="cairo", compression="lzw")
plot1
dev.off()
jpeg(filename = paste0(path_data,"/results/figures/",mapping_project,
                       ".boxplot-model_similiarity_score-byAccuracy.jpeg"),
     width=5.5, height=6.5, units="in", res=300, type="windows")
plot1
dev.off()
# Plot 2
tiff(filename = paste0(path_data,"/results/figures/",mapping_project,
                       ".density-model_similiarity_score-byAccuracy.tiff"),
     width=5.5, height=5, units="in", res=300, type="cairo", compression="lzw")
plot2
dev.off()
jpeg(filename = paste0(path_data,"/results/figures/",mapping_project,
                       ".density-model_similiarity_score-byAccuracy.jpeg"),
     width=5.5, height=5, units="in", res=300, type="windows")
plot2
dev.off()

# Plot 3
tiff(filename = paste0(path_data,"/results/figures/",mapping_project,
                       ".histogram-accurate_mapping_rank_by_model.tiff"),
     width=5.5, height=5, units="in", res=300, type="cairo", compression="lzw")
plot3
dev.off()

jpeg(filename = paste0(path_data,"/results/figures/",mapping_project,
                       ".histogram-accurate_mapping_rank_by_model.jpeg"),
     width=5.5, height=5, units="in", res=300, type="windows")
plot3
dev.off()

# Clean up environment
rm(plot1,plot2,plot3)

#### Analysis of Variance of Model Mapping Similarity Scores ####
##### Prepare additional categorical factor variables for ANOVA Test####
# Definition Treatment Group
data$treatment_groups <- "RAG Definition (Treatment)"
data[data$model=="human descriptions",]$treatment_groups <- "Human Definitions (Control)"
data$treatment_groups <- factor(data$treatment_groups, 
                                levels=c("RAG Definition (Treatment)",
                                         "Human Definitions (Control)"))
# Mapping Accuracy
data$accurate_mapping <- 
  factor(data$accuracy, 
         levels=c(1,0),
         labels=c("Accurate Mappings",
                  "Inaccurate Mappings"))

# Concept Group (Anatomical Structures & Cell Types)
data$mesh_concept_group <- 
  factor(data$mesh_concept_group,
         levels=c("Anatomical structure",
                  "Cell type"))

##### ANOVA Test: Homogeneity of Variance #####
######Test 1: Model comparisons ####
# Normalize similarity scores
data$similarity_score_norm <- 
  as.numeric(scale(data$similarity_score, center=T, scale=T))
# Levene's test
# H1
tmp1 <- leveneTest(similarity_score_norm ~ model, 
                   data=data, center=mean)
# H2
tmp2 <- leveneTest(similarity_score_norm ~ model * accurate_mapping, 
                   data=data, center=mean)
# Extract and combine result variables
parameter <- 
  data.frame(df=rbind(tmp1$Df,tmp2$Df))
f_stat <-
  data.frame(f.stat=rbind(tmp1$'F value',tmp2$'F value')[1:2])
p_val <- 
  data.frame(p.val = rbind(tmp1$'Pr(>F)',tmp2$'Pr(>F)')[1:2])
data_name <-
  data.frame(data.name = c("Compared similarity_score_norm to model.",
                           "Compared similarity_score_norm to model and accurate_mapping."))
levene_tests <- cbind(parameter,f_stat,p_val,data_name)
# Save results
write.csv(levene_tests, 
          file=paste0(path_results_data,"/similarity_score_variance/",
                      mapping_project,".hov_test.levene_test.model+accuracy.similiarity_score.csv"),
          row.names = F)
# Clean up environment
rm(tmp1,tmp2)
rm(parameter,f_stat,p_val,data_name)

###### Test 2: Individual Model F-Tests ####
# Comparing var. of similarity scores for a model's mappings, by accuracy
# Human Definitions
human_hit <- 
  data %>%
  filter(model=="human descriptions") %>%
  filter(hit_miss_mapping=="Hit")
human_miss <- 
  data %>%
  filter(model=="human descriptions") %>%
  filter(hit_miss_mapping=="Miss")
tmp1 <- var.test(human_hit$similarity_score, 
                 human_miss$similarity_score,
                 ratio=1, alternative="two.sided")
# Curate GPT
curategpt_hit <- 
  data %>%
  filter(model=="curategpt") %>%
  filter(hit_miss_mapping=="Hit")
curategpt_miss <- 
  data %>%
  filter(model=="curategpt") %>%
  filter(hit_miss_mapping=="Miss")
tmp2 <- var.test(curategpt_hit$similarity_score, 
                 curategpt_miss$similarity_score,
                 ratio=1, alternative="two.sided")
# llama3.2-3b.llm
llama_hit <- 
  data %>%
  filter(model=="llama3.2-3b.llm") %>%
  filter(hit_miss_mapping=="Hit")
llama_miss <- 
  data %>%
  filter(model=="llama3.2-3b.llm") %>%
  filter(hit_miss_mapping=="Miss")
tmp3 <- var.test(llama_hit$similarity_score, 
                 llama_miss$similarity_score,
                 ratio=1, alternative="two.sided")
# phi4-14b.llm
phi_hit <- 
  data %>%
  filter(model=="phi4-14b.llm") %>%
  filter(hit_miss_mapping=="Hit")
phi_miss <- 
  data %>%
  filter(model=="phi4-14b.llm") %>%
  filter(hit_miss_mapping=="Miss")
tmp4 <- var.test(phi_hit$similarity_score, 
                 phi_miss$similarity_score,
                 ratio=1, alternative="two.sided")
# gpt4o.llm
gpt_hit <- 
  data %>%
  filter(model=="gpt4o.llm") %>%
  filter(hit_miss_mapping=="Hit")
gpt_miss <- 
  data %>%
  filter(model=="gpt4o.llm") %>%
  filter(hit_miss_mapping=="Miss")
tmp5 <- var.test(gpt_hit$similarity_score, 
                 gpt_miss$similarity_score,
                 ratio=1, alternative="two.sided")
# Extract model mapping similarity score var comparison results
f_stat <- 
  data.frame(rbind(tmp1$statistic,tmp2$statistic,tmp3$statistic,
        tmp4$statistic,tmp5$statistic))
parameter <-
  data.frame(rbind(tmp1$parameter,tmp2$parameter,tmp3$parameter,
             tmp4$parameter,tmp5$parameter))
p_val <- 
  data.frame(p.val = rbind(tmp1$p.value,tmp2$p.value,tmp3$p.value,
                           tmp4$p.value,tmp5$p.value))
conf_int <- 
  data.frame(rbind(tmp1$conf.int,tmp2$conf.int,tmp3$conf.int,
                   tmp4$conf.int,tmp5$conf.int))
names(conf_int) <- c("conf_5","conf_95")
null_value <- 
  data.frame(ratio.of.variances=
              rbind(tmp1$null.value,tmp2$null.value,tmp3$null.value,
                    tmp4$null.value,tmp5$null.value))
alternative <- 
  data.frame(alternative=
               rbind(tmp1$alternative,tmp2$alternative,tmp3$alternative,
                     tmp4$alternative,tmp5$alternative))
method <- 
  data.frame(method=
               rbind(tmp1$method,tmp2$method,tmp3$method,
                     tmp4$method,tmp5$method))
data_name <- 
  data.frame(data.name =
               rbind(tmp1$data.name,tmp2$data.name,tmp3$data.name,
                     tmp4$data.name,tmp5$data.name))
# Combine F-test result variables
model_accuracy_f_test <- 
  cbind(f_stat, p_val, conf_int, null_value, alternative, method, data_name)
# Save results
write.csv(model_accuracy_f_test, 
          file=paste0(path_results_data,"/similarity_score_variance/",
                      mapping_project,".hov_test.ftest.model+accuracy.similiarity_score_var.csv"),
          row.names = F)
# Clean up environment
rm(human_hit, human_miss, llama_miss, llama_hit, curategpt_hit, curategpt_miss,
   gpt_hit, gpt_miss, phi_miss, phi_hit)
rm(tmp1,tmp2,tmp3,tmp4,tmp5)
rm(f_stat, p_val, conf_int, null_value, alternative, method, data_name)

##### ANOVA Test: Independence of Variables (three ways) ####
###### Chi-Squared test ####
# Compare categorical variable pairs
# model and accuracy
tmp1 <- chisq.test(data$model, data$accurate_mapping, correct = FALSE)
# model and concept group
tmp2 <- chisq.test(data$model, data$mesh_concept_group, correct = FALSE)
# concept group and accuracy
tmp3 <-
  chisq.test(data$mesh_concept_group, data$accurate_mapping, correct = FALSE)

# Extract results
statistic <- 
  data.frame(x.squared=rbind(tmp1$statistic,tmp2$statistic,tmp3$statistic))
parameter <-
  data.frame(df=rbind(tmp1$parameter,tmp2$parameter,tmp3$parameter))
p_val <- 
  data.frame(p.val=rbind(tmp1$p.value,tmp2$p.value,tmp3$p.value))
method <- 
  data.frame(method=rbind(tmp1$method,tmp2$method,tmp3$method))
data_name <- 
  data.frame(data.name=rbind(tmp1$data.name,tmp2$data.name,tmp3$data.name))

# Combine ChiSq Results
chi_squared_var_comp <- 
  cbind(statistic, parameter, p_val, method, data_name)
# Save results
write.csv(chi_squared_var_comp, 
          file=paste0(path_results_data,"/similarity_score_variance/",
                      mapping_project,".iov_test.chisquared.model+mapping_accuracy+concept_group.csv"),
          row.names = F)
# Clean up environment.
rm(tmp1,tmp2,tmp3)
rm(statistic, parameter, p_val, method, data_name)

##### Set-up GLM models for Type I, II ANOVA or MANOVA Analysis #####
# Note on these results: Data does not meet the conditions homogeneity of 
# variance required to reliably use ANOVA for drawing statistical conclusions 
# difference in models' mapping similarity scores.

# H2. Type I models
h1_anova_t1.1 <- 
  glm(similarity_score_norm ~ model,
      data=data)
h1_anova_t1.2 <- 
  glm(similarity_score_norm ~ mesh_concept_group,
      data=data)
h1_anova_t1.3 <- 
  glm(similarity_score_norm ~ accurate_mapping,
      data=data)

# H2. Type II models
h2_anova_t2.1 <- 
  glm(similarity_score_norm ~ model * accurate_mapping,
      data=data)
h2_anova_t2.2 <- 
  glm(similarity_score_norm ~ model * mesh_concept_group * accurate_mapping,
      data=data)

# Compare model AIC
model.set <- list(h1_anova_t1.1, h1_anova_t1.2, h1_anova_t1.3, 
                  h2_anova_t2.1, h2_anova_t2.2)
model.names <- c("h1_anova_t1.1", "h1_anova_t1.2","h1_anova_t1.3",
                 "h2_anova_t2.1", "h2_anova_t2.2")
mod_aic <- aictab(model.set, modnames = model.names)
mod_aic

# Analysis interpretation: Concept Type Factors account for more variance. Use a MANOVA.

##### Run ANOVA Test
# Type I
h1_anova_t1 <- Anova(mod=h1_anova_t1.1, multivariate=F, type="II", 
                      test.statistic=c("F"))
h1_anova_t1

# Type II
h2_anova_t2 <-
  Anova(mod=h2_anova_t2.2, multivariate=T, type="II", test.statistic=c("F"))
h2_anova_t2

##### Post-hoc tests #####
###### Test for Independence of Factor Variables ####
durbinWatsonTest(aov(h1_anova_t1.1))
durbinWatsonTest(aov(h2_anova_t2.2))

###### Test for Normal Distribution ####
# H1
# Shapiro-Wilks test (5000 sample)
shapiro.test(sample(h1_anova_t1.1$residuals, 5000, replace=T))

# histogram
hist(h1_anova_t1.1$residuals)
# QQ-plot
qqPlot(h1_anova_t1.1$residuals,
       id = FALSE)

# H2 & H3
# Shapiro-Wilks test (5000 sample)
shapiro.test(sample(h2_anova_t2.2$residuals, 5000, replace=T))

# Visual checks
# histogram
hist(h2_anova_t2.2$residuals)
# QQ-plot
qqPlot(h2_anova_t2.2$residuals,
       id = FALSE)

###### Tukey HSD Test - Unreliable conclusions ####
# H1
post_test_h1 <- TukeyHSD(aov(h1_anova_t1.1))
post_test_h1 <- data.frame(post_test_h1$model)
post_test_h1$comparison <- rownames(post_test_h1)
row.names(post_test_h1) <- 1:nrow(post_test_h1)
post_test_h1 <-
  post_test_h1 %>% 
  select(comparison,p.adj,diff,lwr,upr)
write.csv(post_test_h1, 
          file=paste0(path_data,"/results/similarity_score_variance/",mapping_project,
                      ".h1.1.post_hoc.TukeyHSD.model.csv"),
          row.names = FALSE)

# H2
post_test_h2 <- 
  TukeyHSD(aov(h2_anova_t2.2))
# Comparisons of Model+MeSH Concept Group
post_test.h2.mod_mcg <- data.frame(post_test_h2$`model:mesh_concept_group`)
post_test.h2.mod_mcg$comparison <- rownames(post_test.h2.mod_mcg)
row.names(post_test.h2.mod_mcg) <- 1:nrow(post_test.h2.mod_mcg)
# Select model level comparisons between concept group. (5 of 45 comps)
cases <- 
  c("human descriptions:Cell type-human descriptions:Anatomical structure",
    "llama3.2-3b.llm:Cell type-llama3.2-3b.llm:Anatomical structure",
    "gpt4o.llm:Cell type-gpt4o.llm:Anatomical structure",
    "phi4-14b.llm:Cell type-phi4-14b.llm:Anatomical structure",
    "curategpt:Cell type-curategpt:Anatomical structure")
post_test.h2.mod_mcg <- 
  post_test.h2.mod_mcg[post_test.h2.mod_mcg$comparison %in% cases,] %>%
  select(comparison,p.adj,diff,lwr,upr)
# Save results
write.csv(post_test.h2.mod_mcg, 
          file=paste0(path_data,"/results/similarity_score_variance/",mapping_project,
                      ".h2.2.post_hoc.TukeyHSD.model+mesh_group.csv"),
          row.names = FALSE)

# Comparisons of Model+Mapping Accuracy
post_test.h2.mod_acc <- data.frame(post_test_h2$`model:accurate_mapping`)
post_test.h2.mod_acc$comparison <- rownames(post_test.h2.mod_acc)
row.names(post_test.h2.mod_acc) <- 1:nrow(post_test.h2.mod_acc)
# Select model level comparisons between concept group. (5 of 45 comps)
cases <- 
  c("human descriptions:Inaccurate Mappings-human descriptions:Accurate Mappings",
    "llama3.2-3b.llm:Inaccurate Mappings-llama3.2-3b.llm:Accurate Mappings",
    "gpt4o.llm:Inaccurate Mappings-gpt4o.llm:Accurate Mappings",
    "phi4-14b.llm:Inaccurate Mappings-phi4-14b.llm:Accurate Mappings",
    "curategpt:Inaccurate Mappings-curategpt:Accurate Mappings")
post_test.h2.mod_acc <- 
  post_test.h2.mod_acc[post_test.h2.mod_acc$comparison %in% cases,] %>%
  select(comparison,p.adj,diff,lwr,upr)
# Save results
write.csv(post_test.h2.mod_acc, 
          file=paste0(path_data,"/results/similarity_score_variance/",mapping_project,
                      ".h2.2.post_hoc.TukeyHSD.model+accuracy.csv"),
          row.names = FALSE)