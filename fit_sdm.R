source("/home/dys7/Mopane-worm-network/pipeline_functions.R")

# Define the study extent coordinates
xmin <- 11   # East
xmax <- 41  # West
ymin <- -35 # North
ymax <- -10 # South

ext_occ <- extent(xmin, xmax, ymin, ymax)

# Specify which bioclim layers are being used
bioclim_layers <- c(1, 5, 6, 12, 13, 14)

# Load and crop the environmental data
## Present
pres_clim <- ras_stack("CHELSA/", ext_occ)
## Future
fut4045_clim <- ras_stack("CHELSA_future/2041-2060/rcp45/", ext_occ)
fut4085_clim <- ras_stack("CHELSA_future/2041-2060/rcp85/", ext_occ)
fut6045_clim <- ras_stack("CHELSA_future/2061-2080/rcp45/", ext_occ)
fut6085_clim <- ras_stack("CHELSA_future/2061-2080/rcp85/", ext_occ)

# Vector of species with enough points for SDM
files <- list.files("points/cleaned_raw")
sp_names <- sub(".csv", "", files)


# Rarefy Points - so there is only one occurrence point per grid cell
# create large raster layer called ref_map
ref_map <- pres_clim[[1]]
ref_map[!is.na(ref_map)] <- 0   #ref_map should be full of non-1 values

rarefyPoints(
  sp_name = sp_name,
  in_dir = here::here("points/cleaned_raw"),
  out_dir = here::here("points/rarefied/"),
  ref_map = ref_map
)

# Extract environmental data for presence points
ras_extract(
  sp_name = sp_name,
  in_dir = here::here("points/rarefied"),
  out_dir = here::here("environmental/presence"),
  raster_in = pres_clim
)

# Generate background and pseudoabsence points

## wwf_ecoregions_get() # this should download the wwf ecoregions data and put it in the right place for you. 

ecoreg <- sf::st_read(here::here("WWF_Ecoregions/wwf_terr_ecos.shp")) %>%
  sf::st_crop(., ext_occ) %>%  ##cropping to the area of interest
  dplyr::select(OBJECTID, ECO_NAME) ##just selecting out the columns we're interested in

background_sampler(
  sp_name = sp_name,
  in_dir = here::here("points/rarefied"),
  out_dir = here::here("points/background"),
  dens_abs = "density",
  density = 100,
  type = "background",
  polygon = ecoreg
)

background_sampler(
  sp_name = sp_name,
  in_dir = here::here("points/rarefied"),
  out_dir = here::here("points/pseudoabsence"),
  dens_abs = "density",
  density = 100,
  type = "pseudoabsence",
  buffer = 100,
  polygon = ecoreg
)

# Extract environmental data for background points
ras_extract(
  sp_name = sp_name,
  in_dir = here::here("points/background"),
  out_dir = here::here("environmental/background"),
  raster_in = pres_clim
)

# Extract environmental data for pseudoabsence points
ras_extract(
  sp_name = sp_name,
  in_dir = here::here("points/pseudoabsence"),
  out_dir = here::here("environmental/pseudoabsence/"),
  raster_in = pres_clim
)

# Fit bioclim model for species
fitBC(sp_name = sp_name,
    pres_dir = here::here("environmental/presence/"),
    backg_dir = here::here("environmental/pseudoabsence/"),
    predictor_names = bioclim_layers,
    predictors = pres_clim,
    predictors_future = futures,
    pred_out_dir = here::here("predictions/bioclim/"),
    pred_out_dir_future = fut_dirs,
    eval_out_dir = here::here("evaluation/bioclim/"),
    overwrite = TRUE,
    eval = TRUE
)

# Fit GLM model for species
fitGLM(
    sp_name = sp_name,
    pres_dir = here::here("environmental/presence/"),
    backg_dir = here::here("environmental/pseudoabsence/"),
    predictor_names = bioclim_layers,
    predictors = pres_clim,
    predictors_future = futures,
    pred_out_dir = here::here("predictions/glm/"),
    pred_out_dir_future = fut_dirs,
    eval_out_dir = here::here("evaluation/glm/"),
    overwrite = TRUE,
    eval = TRUE
)

# Fit RF model for species
fitRF(
    sp_name = sp_name,
    pres_dir = here::here("environmental/presence/"),
    backg_dir = here::here("environmental/pseudoabsence/"),
    predictor_names = bioclim_layers,
    predictors = pres_clim,
    predictors_future = futures,
    pred_out_dir = here::here("predictions/rf/"),
    pred_out_dir_future = fut_dirs,
    eval_out_dir = here::here("evaluation/rf/"),
    overwrite = TRUE,
    eval = TRUE
)
