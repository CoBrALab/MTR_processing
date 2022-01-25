library(ggplot2)
library(lme4)
library(nlme)
library(grid)
library(gplots)
library(plyr)
library(ggsignif)
library(splines)
library(dplyr)
library(RMINC)
library(tidyverse)
library(grid)
library(MRIcrotome)
library(magrittr)
#I can use an lm since I don't have repeated measures (ie multiple scans from the same subject), thus each of my scans fits the independence assumption.
#if I did have repeated measures, I would need to use an lmer to account for the random effect of subject

#load file
mtr_maps_uncorr_df = read.csv("/home/minc/data/chamal/projects/mila/2021_mtr/ex-vivo_mtr_dan_harvard/part3_group_comparison/3_analysis/mtr_map_uncorr_list_for_group_comparison.csv", head = TRUE, sep = ",")
mtr_maps_uncorr_df$Group = as.factor(mtr_maps_uncorr_df$Group)
mtr_maps_uncorr_df$subjectID = as.factor(mtr_maps_uncorr_df$subjectID)
mtr_maps_df = read.csv("/home/minc/data/chamal/projects/mila/2021_mtr/ex-vivo_mtr_dan_harvard/part3_group_comparison/3_analysis/mtr_map_list_for_group_comparison.csv", head = TRUE, sep = ",")
mtr_maps_df$Group = as.factor(mtr_maps_df$Group)
mtr_maps_df$subjectID = as.factor(mtr_maps_df$subjectID)


#mask 
mask = "/home/minc/data/chamal/projects/mila/2019_Magnetization_Transfer/tissue_labels/DSURQE_200micron_mask_nocsf_binary.mnc"

#model
model <- mincLm(mtr_map ~ Group , mtr_maps_df, mask=mask)
model_uncorr <- mincLm(mtr_map ~ Group , mtr_maps_uncorr_df, mask=mask)

#find FDR (value at which to set slider) - necessary because comparing across voxels
FDR = mincFDR(model, mask=mask)
FDR_uncorr = mincFDR(model_uncorr, mask=mask)
FDR
FDR_uncorr


anatVol = "/home/minc/data/chamal/projects/mila/2019_Magnetization_Transfer/tissue_labels/DSURQE_200micron_masked.mnc"
launch_shinyRMINC(model, anatVol, keepBetas = T)
launch_shinyRMINC(model_uncorr, anatVol, keepBetas = T)



