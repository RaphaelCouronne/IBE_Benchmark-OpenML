# ----
rm(list = ls())

# If possible increase memory used
options( java.parameters = "-Xmx8g" )

# Check that all packages can be loaded
require(mlr)

require(ggplot2)
#require(snowfall)
require(cowplot)
require(RWeka) 
#require(doParallel)

require(gridExtra)
require(cowplot)

require(tuneRanger)
require(batchtools)
require(OpenML)
# Enter here nCores and myapikey
nCores = 2 # number of Cpus you want to use
myapikey = "7a4391537f767ea70db6af99497653e5" # OpenML API key
saveOMLConfig(apikey = myapikey, arff.reader = "RWeka", overwrite=TRUE)



#####################################################
#################### Main Document ##################
#####################################################


## 1 Benchmark Study ======================================================================================

## 1.1 Data Mining ----
# Get the tasks from OpenML
# Generates Data/OpenML/df.infos.RData which gives information about the processing of the datasets
# Generates Data/Results/clas_time.RData which contains information about our dataset pool
# 
# Options
# force = TRUE to force (re)computing of ALL dataset informations
# computeTime = TRUE to compute an estimate of training time for LR and RF. It may take up to several days
source(file = "Benchmark/benchmark_getData_OpenML.R")
get_data_OpenML(target_path = "Data/OpenML/clas_time.RData", force = FALSE, computeTime = FALSE)


## 1.2 Benchmark computation ---

###########################################
########## High Computation time ##########
###########################################

# Batchtools implementation
source(file = "Benchmark/benchmark_batchtools.R")
load("Data/OpenML/clas_time.RData")
clas_used = rbind(clas_time_small, clas_time_medium, clas_time_big, clas_time_toobig)

# [Commented] setBatchtoolsExperiment(seed = 1, ncpus = nCores, clas_used = clas_used) #Set up the benchmark (delete current results, use with caution)
regis = loadRegistry("Data/Results/Batchtools/batchtool_benchmark/Experiment_1//", writeable = TRUE)
regis$cluster.functions = makeClusterFunctionsMulticore(ncpus = 2) 
regis$cluster.functions = makeClusterFunctionsInteractive() 

# Launch benchmark
testJob(1) # Test a job
# [Commented] submitJobs(ids = 1, reg = regis) # Submit one job
# [Commented] submitJobs(ids = 1:273, reg = regis) # Submit all datasets


## 2 Visualization  ======================================================================================
 
# 2.1 Conversion of the benchmark results
regis = loadRegistry("Data/Results/Batchtools/batchtool_benchmark/Experiment_1//", writeable = TRUE)
load("Data/OpenML/clas_time.RData")
clas_used = rbind(clas_time_small, clas_time_medium, clas_time_big, clas_time_toobig)
#clas_used = rbind(clas_time_small)
source(file = "Benchmark/benchmark_Results_Conversion.R")
convert_results(clas_used = clas_used, regis = regis, target_path = "Data/Results/df_bmr.RData")

# 2.2 Overall Visualization (Figure 3)
# Plot boxplots of differences in performances
load(file = "Data/Results/df_bmr.RData")
source(file = "Visualization/Overall_Visualization.R")
overall_visualization(res.perfs.df, perfsAggr.diff)

# 2.3 Inclusion Criteria Visualization (Figure 5)
load(file = "Data/Results/df_bmr.RData")
source(file = "Visualization/Inclusion_Criteria_Plots.R")
inclusion_criteria(df.bmr.diff)


## 3. Analysis  ======================================================================================

# 3.1 Overall results (Table 2)
# Show bootstrap means, sd and confidence intervals
load(file = "Data/Results/df_bmr.RData")
source(file = "Benchmark/benchmark_Results_Overview.R")
benchmark_ResultsOverview(df.bmr.diff, res.perfs.df)

# 3.2 Meta Learning (Figure 6 + Table 3)
load(file = "Data/Results/df_bmr.RData")
source(file = "Benchmark/benchmark_Results_MetaLearning.R")
ResultsMetaLearning(df.bmr.diff)




## 4. Simulations  ======================================================================================

# 4.1 Subset analysis on 1 dataset (Figure 4)

###########################################
########## High Computation time ##########
###########################################

data.id = 310 #-mammography data.id 310 11183 7

source("Biological_datasets/subset_analysis_bio.R")
subset_analysis_bio(nCores=4, seed=1, data.id = 310,
                    n.simulation = 20, n.max = 1e3,
                    grid.n = c(5e2), grid.p = c(1,2,3,4,5,6))

subsetAnalysis_visualization_bio() # Visualize the results


# 4.2 Partial dependance plots simulations (Figure 1)
source("Simulations/PDP_Example_Simulations.R")
PlotPartialDependanceExample(seed = 2)





###########################################################################################
################################# Additional Files ########################################
###########################################################################################



#####################################################
## Additional File 2 : Study of biological datasets 
#####################################################

## Part 1 : Biological datasets
rm(list=ls())

# Source 
source(file = "Visualization/Overall_Visualization.R")
source(file = "Visualization/Inclusion_Criteria_Plots.R")
source(file = "Benchmark/benchmark_Results_Overview.R")
source(file = "Benchmark/benchmark_Results_MetaLearning.R")

# Load results and select subset
load(file = "Data/Results/df_bmr.RData")

df_biological = read.csv("df_biological.csv", sep = " ")
df_biological = na.omit(df_biological[df_biological$is_biology==1,])
df_biological <- df_biological[order(df_biological$n*df_biological$p),] 

index_bio = c(1:243)[clas_used$data.id %in% df_biological$data.id]
df.bmr.diff.bio = df.bmr.diff[index_bio,]
perfsAggr.diff.bio = perfsAggr.diff[index_bio,]
res.perfs.df.bio = res.perfs.df[c(2*index_bio,2*index_bio-1),]

# Plots
overall_visualization(res.perfs.df.bio, perfsAggr.diff.bio) # Boxplots of performance for biological datasets
inclusion_criteria(df.bmr.diff.bio) # Inclusion Criteria plots for biological datasets
benchmark_ResultsOverview(df.bmr.diff.bio, res.perfs.df.bio) # Bootstrap CI, mean and std for biological datasets
ResultsMetaLearning(df.bmr.diff.bio) # Meta-learning modelling for biological datasets


## Part 2 : Non biological datasets vs biological datasets

# Load subsets
index_bio = c(1:243)[clas_used$data.id %in% df_biological$data.id]
index_not.bio = c(1:243)[!(clas_used$data.id %in% df_biological$data.id)]

# Analysis
source(file = "Visualization/Biological_subgroup.R")
biological_subgroup_analysis(df.bmr.diff, index_bio, index_not.bio) # Boxplot of biological vs non-biological datasets + Bootstrap CI for non biological datasets 







########################################################
## Additional File 3 : Study of partial dependence plots
########################################################

rm(list=ls())

## 1 Computation of the difference in Partial Dependence ----

###########################################
########## High Computation time ##########
###########################################

# Batchtools implementation
#source(file = "Additional_Files/PartialDependence_Batchtools.R")
#load("Data/Results/df_bmr.RData")
#load("Data/OpenML/clas_time.RData")
#clas_used = rbind(clas_time_small, clas_time_medium, clas_time_big)

# Set up the benchmark (delete current results)

#[Commented] setBatchtoolsPDPExperiment(seed = 1, ncpus = 3, clas_used = clas_used)
#regis.pdp = loadRegistry("Data/Results/Batchtools/batchtool_PartialDependance///", writeable = TRUE)

# Launch benchmark
#[Commented] submitJobs(ids = 1:278, reg = regis.pdp) #small datasets

# Check benchmark


## 2 Visualization of the results ----
rm(list=ls())
load("Data/Results/df_bmr.RData")
regis.pdp = loadRegistry("Data/Results/Batchtools/batchtool_PartialDependance///", writeable = TRUE)
source("Additional_Files/PartialDependence_Extreme_Cases.R")
partialDependenceAnalysis_extremCases(regis = regis.pdp)









#####################################################
## Additional File 4 : Study of Random Forest Tuning 
#####################################################


rm(list=ls())
library(batchtools)
require(gdata)
nCores = 1


## 1 Load the biological datasets ----
# Read the .csv
df_biological = read.csv("df_biological.csv", sep = " ")
df_biological = na.omit(df_biological[df_biological$is_biology==1,])
df_biological <- df_biological[order(df_biological$n*df_biological$p),] 


## 2 Benchmark biological datasets----
# Batchtools implementation
source(file = "Benchmark/benchmark_batchtools.R")
load("Data/OpenML/clas_time.RData")
clas_used = rbind(clas_time_small, clas_time_medium, clas_time_big, clas_time_toobig)
clas_used = clas_used[clas_used$data.id %in% df_biological$data.id,]
clas_used <- clas_used[order(clas_used$n*clas_used$p),] 


# Set up the benchmark (delete current results)
# [Commented] setBatchtoolsExperiment(seed = 1, ncpus = nCores, clas_used = clas_used,
#                         work.dir = "Data/Results/Batchtools/batchtool_benchmark_bio",
#                         name = "Data/Results/Batchtools/batchtool_benchmark_bio/Experiment_1",
#                         tune = TRUE)

regis = loadRegistry("Data/Results/Batchtools/batchtool_benchmark_bio/Experiment_1//", writeable = TRUE)
regis$cluster.functions = makeClusterFunctionsMulticore(ncpus = 2) 
regis$cluster.functions = makeClusterFunctionsInteractive()
testJob(1)
# [Commented] submitJobs(ids = c(1:70), reg = regis) #small datasets# Errors ?

## 3 Show results with biological datasetss----
source(file = "Biological_datasets//benchmark_Results_Conversion_bio.R")
convert_results(clas_used = clas_used, regis = regis, target_path = "Data/Results/df_bmr_bio.RData")


# 3.1 Overall Visualization
load(file = "Data/Results/df_bmr_bio.RData")
source(file = "Biological_Datasets/Overall_Visualization_bio.R")
overall_visualization_bio(df.bmr.diff)

# 3.2 Inclusion Criteria Visualization
load(file = "Data/Results/df_bmr_bio.RData")
source(file = "Visualization/Inclusion_Criteria_Plots.R")
inclusion_criteria(df.bmr.diff[df.bmr.diff$rf_type=="RF",])
inclusion_criteria(df.bmr.diff[df.bmr.diff$rf_type=="TR",])

# 3.3 Overall results
load(file = "Data/Results/df_bmr_bio.RData")
source(file = "Benchmark/benchmark_Results_Overview.R")
benchmark_ResultsOverview(df.bmr.diff[df.bmr.diff$rf_type=="RF",], res.perfs.df)
benchmark_ResultsOverview(df.bmr.diff[df.bmr.diff$rf_type=="TR",], res.perfs.df)

# 3.4 Meta Learning
load(file = "Data/Results/df_bmr_bio.RData")
source(file = "Benchmark/benchmark_Results_MetaLearning.R")
ResultsMetaLearning(df.bmr.diff[df.bmr.diff$rf_type=="RF",])
ResultsMetaLearning_bio(df.bmr.diff)

