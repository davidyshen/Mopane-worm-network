#!/bin/bash

#SBATCH --mem=8G
#SBATCH --time=48:00:00
#SBATCH --array=211
#SBATCH --out=/home/dys7/bayes2/logs/%x_%A_%a.out
#SBATCH --job-name=data_download
#SBATCH --cpus-per-task=2
#SBATCH --ntasks=1

species_list=
output_dir=

module load R
Rscript data_prep.R $species_list $output_dir $SLURM_ARRAY_TASK_ID