# This script downloads data from GBIF for a single species
# with defined properties
source("/home/dys7/Mopane-worm-network/pipeline_functions.R")

require("dplyr")

# Script takes commands of species name
args = commandArgs(trailingOnly=TRUE)
if(length(args)==0){stop("Error: No arguments...")}
species_list = read.csv(args[1],header = F)$V1
output_dir = args[2]
index = as.numeric(Sys.getenv("SLURM_ARRAY_TASK_ID"))

sp_name = species_list[index]
sp_name = sub(" ", "_", sp_name)

# Define extent
xmin <- 11      # East
xmax <- 41      # West
ymin <- -35     # North
ymax <- -10     # South
ext_occ <- raster::extent(xmin, xmax, ymin, ymax)

# Minimum number of records per species
min_occ <- 20


# Make output directories
if (!dir.exists(file.path(output_dir, "points/raw"))) {
  dir.create(file.path(output_dir, "points/raw"), recursive = TRUE)}
if (!dir.exists(file.path(output_dir, "points/cleaned_raw"))) {
  dir.create(file.path(output_dir, "points/cleaned_raw/"), recursive = T)}
if (!dir.exists(file.path(output_dir, "points/rarefied"))) {
  dir.create(file.path(output_dir, "points/rarefied/"), recursive = T)}
if (!dir.exists(file.path(output_dir, "environmental/presence/"))) {
  dir.create(file.path(output_dir, "environmental/presence/"), recursive = TRUE)}
if (!dir.exists(file.path(output_dir, "points/background/"))) {
  dir.create(file.path(output_dir, "points/background/"), recursive = T)}
if (!dir.exists(file.path(output_dir, "points/pseudoabsence/"))) {
  dir.create(file.path(output_dir, "points/pseudoabsence/"), recursive = T)}
if (!dir.exists(file.path(output_dir, "environmental/background/"))) {
  dir.create(file.path(output_dir, "environmental/background/"), recursive = T)}
if (!dir.exists(file.path(output_dir, "environmental/pseudoabsence/"))) {
  dir.create(file.path(output_dir, "environmental/pseudoabsence/"), recursive = T)}
if (!dir.exists(file.path(output_dir, "predictions/bioclim/"))) {
  dir.create(file.path(output_dir, "predictions/bioclim"), recursive = TRUE)}
if (!dir.exists(file.path(output_dir, "predictions/glm/"))) {
  dir.create(file.path(output_dir, "predictions/glm"), recursive = TRUE)}
if (!dir.exists(file.path(output_dir, "predictions/rf/"))) {
  dir.create(file.path(output_dir, "predictions/rf"), recursive = TRUE)}

# Download data for species from GBIF
gbifData(
  sp_name = sp_name,
  ext_occ = ext_occ, # area over which occurrence points will be downloaded
  out_dir = file.path(output_dir, "points/raw"), # where points will be saved
  min_occ = min_occ
)

# Cleaning the coordinates using the CoordinateCleaner package - https://cran.r-project.org/web/packages/CoordinateCleaner/CoordinateCleaner.pdf
cc_wrapper(
  sp_name = sp_name,
  in_dir = file.path(output_dir, "points/raw"),
  out_dir = file.path(output_dir, "points/cleaned_raw")
)