
chelsa_bioclim_get <- function(layer){
  
  if(!dir.exists("CHELSA")){
    dir.create("CHELSA")
  }
  if(!file.exists(paste0("CHELSA/CHELSA_bio10_",stringr::str_pad(layer, 2, pad = "0"), ".tif"))){
    download.file(paste0("https://envidatrepo.wsl.ch/uploads/chelsa/chelsa_V1/bioclim/integer/CHELSA_bio10_",stringr::str_pad(layer, 2, pad = "0"),".tif"), destfile = paste0("CHELSA/CHELSA_bio10_",stringr::str_pad(layer, 2, pad = "0"), ".tif"))
  } else{
    print("file already downloaded")
  }
  
}


wwf_ecoregions_get <- function(){
  if(!dir.exists("WWF_Ecoregions")){
    dir.create("WWF_Ecoregions")
  }
  download.file("https://c402277.ssl.cf1.rackcdn.com/publications/15/files/original/official_teow.zip?1349272619", destfile = "WWF_Ecoregions.zip")
  unzip("WWF_Ecoregions.zip", exdir = "WWF_Ecoregions/")
  lf <- list.files("WWF_Ecoregions/", recursive = TRUE, full.names = TRUE)
  nlf <- basename(lf)
  file.rename(lf, paste0("WWF_Ecoregions/",nlf))
  file.remove("WWF_Ecoregions/official/")
}


gbifCountData <- function(sp_name, ext_sp) {
  # Include something for if there is nothing in GBIF...
  gen <- strsplit(sp_name, "_")[[1]][1]
  sp <- strsplit(sp_name, "_")[[1]][2]
  
  # count records.
  .count <- dismo::gbif(
    genus = gen,
    species = sp,
    ext = ext_sp,
    geo = TRUE,
    removeZeros = TRUE,
    download = FALSE
  )
  
  output_data <-  data.frame(sp_name, .count)
  print(paste(sp_name, "done!"))
  return(output_data)
}


gbifData <- function(sp_name, ext_sp = NULL, ext_occ , out_dir, min_occ = 0) {
  # Include something for if there is nothing in GBIF...
  gen <- strsplit(sp_name, "_")[[1]][1]
  sp <- strsplit(sp_name, "_")[[1]][2]
  
  if (is.null(ext_sp)){ext_sp = ext_occ}
  
  # count records.
  .count <- dismo::gbif(
    genus = gen,
    species = sp,
    #ext = ext_sp,
    geo = TRUE,
    removeZeros = TRUE,
    download = FALSE
  )
  if (.count >= 10 & .count <= 200000) {
    .xx <<- dismo::gbif(
      genus = gen,
      species = sp,
      ext = ext_occ,
      geo = TRUE,
      removeZeros = TRUE,
      download = TRUE
    )
    # remove NAs and duplicates
    if (is.null(.xx)) {
      output_data <- NULL
    } else {
      if (all(c("lon", "lat") %in% colnames(.xx))) {
        .xx <- .xx %>% 
          dplyr::filter((basisOfRecord == "HUMAN_OBSERVATION" | basisOfRecord == "LIVING_SPECIMEN" | basisOfRecord == "MACHINE_OBSERVATION") & year >= 2010 )
        xx <- cbind(.xx$lon, .xx$lat)
        output_data <-
          matrix(unique(xx[complete.cases(xx), ]), ncol = 2)
        output_data <- cbind(sp_name, output_data)
        colnames(output_data) <- c("species", "x", "y")
        if(nrow(output_data) >= min_occ){
          write.csv(output_data, paste0(out_dir, "/", sp_name, ".csv"), row.names = FALSE)
        }
      } else {
        output_data <- NULL
      }
    }
  } else {
    output_data <- paste0(sp_name, " too many records")
  }
  print(paste(sp_name, "done!"))
  #return(output_data)
}


cc_wrapper <- function(sp_name, in_dir, out_dir, min_occ = 0){
  
  if (!dir.exists(out_dir)) {
    dir.create(out_dir, recursive = T)}
  
  sp_df <- read.csv(paste0(in_dir,"/", sp_name, ".csv"))
  sp_cc <- CoordinateCleaner::clean_coordinates(sp_df,
                                                lon = "x",
                                                lat = "y",
                                                species = "species",
                                                tests = c("capitals",
                                                          "centroids",
                                                          "equal", 
                                                          "gbif", 
                                                          "institutions",
                                                          "seas",
                                                          "zeros"))
  sp_df<-sp_df[which(sp_cc$.summary == TRUE),]
  
  print(paste(sp_name, "cleaned!"))
  if (nrow(sp_df)>= min_occ){
  write.csv(sp_df, paste0(out_dir, "/", sp_name, ".csv"), row.names = FALSE)
  }
}

ras_stack <- function(path, ext_occ) {
  bio_layers <- list.files(path, pattern = "tif") # Climate tifs
  bio_layers1<-paste(path, bio_layers, sep="") # this line makes sure that it knows the full path, compare prints of bio_layers and bio_layers1
  bio_layers2 <-lapply(bio_layers1,raster)
  env_layers <- raster::stack(bio_layers2)
  # crop returns a geographic subset of an object as specified by an Extent object 
  env_crop <- raster::crop(env_layers, ext_occ)
  return(env_crop)
}

ras_extract <- function(sp_name, in_dir, out_dir, raster_in) {
  if (!dir.exists(out_dir)) {
    dir.create(out_dir, recursive = T)}
  
  df <- vroom::vroom(paste0(in_dir, "/", sp_name, ".csv"), delim = ",")
  xy <- sp::SpatialPointsDataFrame(matrix(c(df$x, df$y), ncol = 2), df)
  ras_ext <- raster::extract(raster_in, xy)
  pres_ext <- data.frame(df, ras_ext)
  pres_ext <- pres_ext[complete.cases(pres_ext),]
  write.csv(x = pres_ext,
            file = paste0(out_dir, "/", sp_name, ".csv"),
            row.names = FALSE)
  print(sp_name)
}


loadBioclim <-
  function(path,
           extension,
           extent = NULL,
           prjctn = NULL) {
    bio_layers <- list.files(path,
                             pattern = paste0(extension, "$"),
                             full.names = TRUE)
    bioclim <- raster::stack(bio_layers)
    if (!is.null(extent)) {
      bioclim <- raster::crop(bioclim, extent)
    }
    if (!is.null(prjctn)) {
      if (class(prjctn) != "CRS") {
        stop("Projection must be an object of class CRS.")
      }
      bioclim <- raster::projectRaster(bioclim, crs = prjctn)
    }
    return(bioclim)
  }

rarefyPoints<-function(sp_name, in_dir, out_dir, ref_map, min_occ = 0 ){
  
  if (!dir.exists(out_dir)) {
    dir.create(out_dir, recursive = T)}
  
  df <- read.csv(paste0(in_dir, "/", sp_name, ".csv"))
  pnts <- SpatialPointsDataFrame(matrix(c(df$x, df$y), ncol = 2), df)
  
  cells <- raster::cellFromXY(ref_map, pnts)
  pres_cells <- ref_map
  pres_cells[unique(cells)] <- 1
  rarefied_presence <- raster::rasterToPoints(
    pres_cells,
    fun = function(x) {
      x == 1
    }
  )[, c(1, 2)]
  rarefied_presence <- sp::SpatialPoints(rarefied_presence)
  sp::proj4string(rarefied_presence) <- sp::proj4string(ref_map)
  df_rar <- data.frame(sp_name,rarefied_presence)
  
  print(paste0(sp_name, " rarefied!"))
  
  if (nrow(df_rar) >= min_occ){
    write.csv(df_rar, paste0(out_dir, "/", sp_name, ".csv"), row.names = FALSE)
  }
  
}

####
###@dens_abs - whether you want to use sampling based on density or an absolute number e.g. 10000
###@density - what that density is in terms of per km. e.g. 1000 would be 1 point per 1000km2
###@no_pnts - number of points if using an absolute number
###@type - type of points to use, either background or pseudoabsence. Background will distribute points randomly across the polygons in which points fall. 
### Pseudo-absence will also do this but exclude points less than @buffer km from a presence point
###@buffer - the size of the buffer used in type = "pseudoabsence"
###@polygon - the polygon shapefile used as the background - here we use ecoregions but could be any shapefile with multiple polygons

background_sampler <- function(sp_name, in_dir, out_dir, dens_abs = "absolute", 
                               density = NULL, no_pnts = NULL, type = "background", buffer = NULL, polygon = NULL) 
{
  
  if (!dir.exists(out_dir)) {
    dir.create(out_dir, recursive = T)}
  
  in_file <- list.files(in_dir, full.names = TRUE)[grepl(sp_name, list.files(in_dir))]
  
  sf_int <- read_csv(paste0(in_dir, "/", sp_name, ".csv")) %>%
    dplyr::select("x", "y") %>%
    dplyr::distinct() %>%
    sf::st_as_sf(.,
             coords = c("x", "y"),
             crs = 4326) %>%
    sf::st_intersection(., polygon)
  
  bkg_polygon <- polygon %>%
    dplyr::filter(ECO_NAME %in% sf_int$ECO_NAME)
  
  if (dens_abs == "density"){
    no_pnts <- round(as.numeric(sum(st_area(bkg_polygon)))/(1000000*density))   
  }
  
  if (type == "background"){
    points_out <- bkg_polygon %>% 
      sf::st_sample(., size = no_pnts, type = "random")  
  }
  
  if (type == "pseudoabsence"){
    
    diss_bkg_polygon <- sf::st_union(bkg_polygon)
    sf_int_trans <- st_transform(sf_int, "+proj=robin +lon_0=0 +x_0=0 +y_0=0 +ellps=WGS84 +datum=WGS84 +units=m no_defs") #robinson projection
    buff_pnts <- sf::st_buffer(sf_int_trans, buffer*1000)  
    buff_pnts <- st_transform(buff_pnts, crs(sf_int)) #should maybe get the original crs and have that here instead
    buff_pnts <- sf::st_union(buff_pnts)
    diff_bkg_polygon <- sf::st_difference(diss_bkg_polygon, buff_pnts)  
    points_out <- diff_bkg_polygon %>% 
      sf::st_sample(., size = no_pnts, type = "random")
    
  }
  
  tibb <- as_tibble(points_out)
  
  sep_df <- tibb %>%
    mutate(x = unlist(purrr::map(tibb$geometry, 1)),
           y = unlist(purrr::map(tibb$geometry, 2))) %>%
    dplyr::select(x, y)
  
  df_out <- data.frame(sp_name, sep_df)
  
  write.csv(df_out,
            file = paste0(out_dir, "/", sp_name, ".csv"),
            row.names = FALSE)
  
  print(basename(sp_name))
  #return(df_out)
}



clustEvalPa <-
  function(num,
           pres_pts,
           backg_pts,
           kfolds_p,
           kfolds_a,
           curr,
           mod) {
    pres_train <- pres_pts[kfolds_p != num,]
    pres_test <- pres_pts[kfolds_p == num,]
    backg_test <- backg_pts[kfolds_a == num,]
    if (mod == "bioclim") {
      .m <- dismo::bioclim(curr, pres_train)
    } else if (mod == "domain") {
      .m <- dismo::domain(curr, pres_train)
    }
    e <- dismo::evaluate(pres_test, backg_test, .m, curr)
    return(e)
  }


clustEvalSdm <- function(num, sdm_set, kfolds, model, mod) {
  train <- sdm_set[kfolds != num,]
  test_p <- sdm_set[kfolds == num & sdm_set[, "pb"] == 1,]
  test_a <- sdm_set[kfolds == num & sdm_set[, "pb"] == 0,]
  if (mod == "glm") {
    .m <- stats::glm(stats::formula(model),
                     data = train,
                     family = binomial(link = "logit"))
  } else if (mod == "rf") {
    .m <-
      suppressWarnings(randomForest::randomForest(model, data = train))
  }
  
  e <- dismo::evaluate(test_p, test_a, .m)
  e
}



getThresholds <- function(aucs) {
  thresholds <- vector(mode = "list", length = 5)
  names(thresholds) <- c("spec_sens",
                         "no_omission",
                         "prevalence",
                         "equal_sens_spec",
                         "tss")
  thresholds[[1]] <- sapply(aucs, function(x)
    dismo::threshold(x, "spec_sens"))
  thresholds[[2]] <- sapply(aucs, function(x)
    dismo::threshold(x, "no_omission"))
  thresholds[[3]] <- sapply(aucs, function(x)
    dismo::threshold(x, "prevalence"))
  thresholds[[4]] <- sapply(aucs, function(x)
    dismo::threshold(x, "equal_sens_spec"))
  thresholds[[5]] <- sapply(aucs, function(x)
    tssCalc(x))
  return(thresholds)
}


tssCalc <- function(eval) {
  res <- data.frame(threshold = eval@t,
                    tss = apply(eval@confusion, 1, function(x) {
                      cm <- t(matrix(rev(x), nrow = 2))
                      dimnames(cm) <- list(pred = c("0", "1"),
                                           obs = c("0", "1"))
                      class(cm) <- "table"
                      sens <- caret::sensitivity(cm)
                      spec <- caret::specificity(cm)
                      tss <- sens + spec - 1
                      return(tss)
                    }))
  thresh <- res$threshold[which.max(res$tss)]
  return(thresh)
}

fitBC <- function(sp_name,
                  pres_dir,
                  backg_dir,
                  predictor_names,
                  predictors,
                  predictors_future,
                  pred_out_dir,
                  pred_out_dir_future,
                  eval_out_dir,
                  overwrite = T,
                  threads = 4,
                  eval = TRUE) {
  print(sp_name)
  
  # Loading a preparing predictors
  predictor_names <- stringr::str_pad(predictor_names, 2, pad = "0")
  CHELSA_predictor_names <- paste0("CHELSA_bio10_", predictor_names)
  curr <- raster::dropLayer(predictors, which(!names(predictors) %in% CHELSA_predictor_names))
  pres_pts <- as.matrix(data.table::fread(paste0(pres_dir, "/", sp_name, ".csv"), select = c("x", "y")), ncol = 2)
  
  # if (length(predictors_future) != length(pred_out_dir_future)) errorCondition("Number of futures not equal to number of future directories")
  
  # Fit bioclim model
  if (nrow(pres_pts) < 10) {
    cat("Fewer than 10 data points - cannot fit model!")
  } else {
    backg_pts <-
      as.matrix(data.table::fread(paste0(backg_dir, "/", sp_name, ".csv"), select = c("x", "y")))
    
    cat("Fitting bioclim model...\n")
    bc <- dismo::bioclim(curr, pres_pts)
    cat("Done.\n")
    cat("...\n")
    cat("Evaluating bioclim model...\n")
    
    
    kfolds_p <- dismo::kfold(pres_pts, 4)
    kfolds_a <- dismo::kfold(backg_pts, 4)
    
    if (.Platform$OS.type == "unix") {
      cl <- parallel::makeForkCluster(threads)
    } else {
      cl <- parallel::makeCluster(threads)
    }
    parallel::clusterExport(
      cl,
      varlist = c(
        "pres_pts",
        "backg_pts",
        "kfolds_p",
        "kfolds_a",
        "curr",
        "clustEvalPa"
      ),
      envir = environment()
    )
    aucs <- parallel::clusterApply(cl, 1:4, function(x) {
      clustEvalPa(x, pres_pts, backg_pts, kfolds_p, kfolds_a, curr, mod = "bioclim")
    })
    parallel::stopCluster(cl)
    cat("Done.\n")
    cat("...\n")
    thresholds <- getThresholds(aucs)
    
    cat("Predicting from bioclim model...\n")
    res <- dismo::predict(curr, bc)
    
    cat("Done.\n")
    cat("...\n")
    cat("Writing bioclim predictions...\n")
    out_file <- paste0(sp_name, "_bioclim.tif")
    
    
    if (!dir.exists(pred_out_dir)) {
      dir.create(pred_out_dir, recursive = T)
    }
    
    raster::writeRaster(
      res,
      filename = paste(pred_out_dir, out_file, sep = "/"),
      format = "GTiff",
      overwrite = overwrite
    )
    cat("Done. Move on to future.\n")
    
    # Predict future scenarios (can do multiple)
    for (i in 1:length(predictors_future)) {
      curr_future <- raster::dropLayer(predictors_future[[i]], which(!names(predictors_future[[i]]) %in% CHELSA_predictor_names))
      cat("Predicting future", i, "of", length(predictors_future), "\n")
      res_fut <- dismo::predict(curr_future, bc)

      if (!dir.exists(pred_out_dir_future[i])) dir.create(pred_out_dir_future[i], recursive = T)
      cat("Writing bioclim future predictions... \n")
      out_file_future <- paste0(sp_name, "_bioclim_future.tif")
      raster::writeRaster(res_fut,
                          filename = paste(pred_out_dir_future[i], out_file_future, sep = "/"),
                          format = "GTiff",
                          overwrite = overwrite)
      gc()
      cat("Done", i, "of", length(predictors_future), "\n")
    }
    cat("... \n")

    if (!dir.exists(eval_out_dir)) {
      dir.create(eval_out_dir, recursive = TRUE)
    }
    
    if (eval) {
      evals <- list(sp_name = sp_name, model = "bioclim", aucs = aucs, thresholds = thresholds)
      #evals <- data.frame(sp_name = sp_name, model = "bioclim", aucs = unlist(aucs), thresholds = unlist(thresholds))
      save(evals, file = paste0(eval_out_dir, "/", sp_name, "_bioclim_eval.RDA"))
      #save(evals, file = paste0(eval_out_dir, "/", sp_name, "_bioclim_eval.csv"))      
      
    }
  }
  
}


fitGLM <-
  function(sp_name,
           pres_dir,
           backg_dir,
           predictor_names,
           predictors,
           predictors_future,
           pred_out_dir,
           pred_out_dir_future,
           eval_out_dir,
           overwrite = T,
           threads = 4,
           eval = TRUE) {
    print(sp_name)
    
    predictor_names <- stringr::str_pad(predictor_names, 2, pad = "0")
    
    predictor_names <- paste0("CHELSA_bio10_", predictor_names)
    
    curr <- raster::dropLayer(predictors, which(!names(predictors) %in% predictor_names))
    model <- stats::formula(paste("pb ~", paste(predictor_names, collapse = "+")))
    
    pres <- data.frame(pb = 1, data.table::fread(paste0(pres_dir, "/", sp_name, ".csv"), select = predictor_names))
    
    
    if (nrow(pres) < 10) {
      cat("Fewer than 10 data points - cannot fit model!")
      
    } else {
      backg <-
        data.frame(pb = 0,
                   data.table::fread(paste0(backg_dir, "/", sp_name, ".csv"), select = predictor_names))
      
      sdm_set <- rbind(pres, backg)
      
      cat("Fitting GLM...\n")
      m <- stats::glm(stats::formula(model),
                      data = sdm_set,
                      family = binomial(link = "logit"))
      cat("Done.\n")
      cat("...\n")
      if (eval) {
        cat("Evaluating GLM...\n")
        kfolds <- dismo::kfold(sdm_set, 4)
        if (.Platform$OS.type == "unix") {
          cl <- parallel::makeForkCluster(4)
        } else {
          cl <- parallel::makeCluster(4)
          parallel::clusterExport(
            cl,
            varlist = c("sdm_set", "kfolds", "model", "clustEvalSdm"),
            envir = environment()
          )
          parallel::clusterCall(cl, function()
            library(dismo))
        }
        aucs <- parallel::clusterApply(cl, 1:4, function(x) {
          clustEvalSdm(x, sdm_set, kfolds, model, mod = "glm")
        })
        parallel::stopCluster(cl)
        cat("Done.\n")
        cat("...\n")
        thresholds <- getThresholds(aucs)
      }
      
      cat("Predicting from GLM...\n")
      res <- dismo::predict(curr, m)
      res <-
        raster:::calc(
          res,
          fun = function(x) {
            exp(x) / (1 + exp(x))
          }
        ) #backtransforming from logit space
      cat("Done.\n")
      cat("...\n")
      cat("Writing GLM predictions...\n")
      out_file <- paste0(sp_name, "_glm.tif")
      
      if (!dir.exists(pred_out_dir)) {
        dir.create(pred_out_dir, recursive = T)
      }
      
      raster::writeRaster(
        res,
        filename = paste(pred_out_dir, out_file, sep = "/"),
        format = "GTiff",
        overwrite = overwrite
      )
      
      cat("Predicting future from GLM...\n")
      
      for (i in 1:length(predictors_future)) {
        curr_fut<- raster::dropLayer(predictors_future[[i]], which(!names(predictors_future[[i]]) %in% predictor_names))
        cat("Predicting future", i, "of", length(predictors_future), "\n")
        res_fut <- dismo::predict(curr_fut, m)
        res_fut <- raster::calc(res_fut, fun = function(x) {
            exp(x) / (1 + exp(x))
          }
        ) #backtransforming from logit space

        if (!dir.exists(pred_out_dir_future[i])) dir.create(pred_out_dir_future[i], recursive = T)

        cat("Writing GLM future predictions... \n")
        out_file_fut <- paste0(sp_name, "_glm_future.tif")
        raster::writeRaster(
          res_fut,
          filename = paste(pred_out_dir_future[i], out_file_fut, sep = "/"),
          format = "GTiff",
          overwrite = overwrite
        )
        gc()
        cat("Done", i, "of", length(predictors_future), "\n")
      }
      
      if (!dir.exists(eval_out_dir)) {
        dir.create(eval_out_dir, recursive = TRUE)
      }
      
      if (eval) {
        evals <- list(sp_name = sp_name, model = "glm", aucs = aucs, thresholds = thresholds)
        save(evals, file = paste0(eval_out_dir, "/", sp_name, "_glm_eval.RDA"))
        
      }
    }
    
    
  }



fitRF <-   function(sp_name,
                    pres_dir,
                    backg_dir,
                    predictor_names,
                    predictors,
                    predictors_future,
                    pred_out_dir,
                    pred_out_dir_future,
                    eval_out_dir,
                    overwrite,
                    threads = 4,
                    eval = TRUE) {
  print(sp_name)
  
  predictor_names <- stringr::str_pad(predictor_names, 2, pad = "0")
  
  predictor_names <- paste0("CHELSA_bio10_", predictor_names)
  
  curr <- raster::dropLayer(predictors, which(!names(predictors) %in% predictor_names))
  
  model <- stats::formula(paste("pb ~", paste(predictor_names, collapse = "+")))
  
  pres <- data.frame(pb = 1,
                     data.table::fread(paste0(pres_dir, "/", sp_name, ".csv"), select = predictor_names))
  
  
  if (nrow(pres) < 10) {
    cat("Fewer than 10 data points - cannot fit model!")
    
  } else {
    backg <- data.frame(pb = 0,
                        data.table::fread(paste0(backg_dir, "/", sp_name, ".csv"), select = predictor_names))
    
    sdm_set <- rbind(pres, backg)
    
    sdm_set <- sdm_set[complete.cases(sdm_set),]  #should remove this line and just have no NAs background data
    
    cat("Fitting random forest model...\n")
    m <- suppressWarnings(randomForest::randomForest(model, data = sdm_set))
    cat("Done.\n")
    cat("...\n")
    if (eval) {
      cat("Evaluating Random Forest model...\n")
      kfolds <- dismo::kfold(sdm_set, 4)
      if (.Platform$OS.type == "unix") {
        cl <- parallel::makeForkCluster(4)
      } else {
        cl <- parallel::makeCluster(4)
      }
      parallel::clusterExport(
        cl,
        varlist = c("sdm_set", "kfolds", "model", "clustEvalSdm"),
        envir = environment()
      )
      aucs <- parallel::clusterApply(cl, 1:4, function(x) {
        clustEvalSdm(x, sdm_set, kfolds, model, mod = "rf")
      })
      parallel::stopCluster(cl)
      cat("Done.\n")
      cat("...\n")
      thresholds <- getThresholds(aucs)
    }
    
    cat("Predicting from random forest...\n")
    res <- dismo::predict(curr, m)
    cat("Done.\n")
    cat("...\n")
    cat("Writing random forest predictions...\n")
    out_file <- paste0(sp_name, "_rf.tif")
    
    if (!dir.exists(pred_out_dir)) {
      dir.create(pred_out_dir, recursive = T)
    }
    
    raster::writeRaster(
      res,
      filename = paste(pred_out_dir, out_file, sep = "/"),
      format = "GTiff",
      overwrite = overwrite
    )
    cat("Done. Move on to future.\n")
    
    for (i in 1:length(predictors_future)) {
      curr_future <-
        raster::dropLayer(predictors_future[[i]], which(!names(predictors_future[[i]]) %in% predictor_names))
      cat("Predicting future", i, "of", length(predictors_future), "\n")
      res_fut<-dismo::predict(curr_future, m)
      if (!dir.exists(pred_out_dir_future[i])) dir.create(pred_out_dir_future[i], recursive = T)
      cat("Writing RF future predictions... \n")
      out_file_future <- paste0(sp_name, "_rf_future.tif")
      raster::writeRaster(
        res_fut,
        filename = paste(pred_out_dir_future[i], out_file_future, sep = "/"),
        format = "GTiff",
        overwrite = overwrite
      )
      gc()
      cat("Done", i, "of", length(predictors_future), "\n")
    }
    
    if (!dir.exists(eval_out_dir)) {
      dir.create(eval_out_dir, recursive = TRUE)
    }
    
    if (eval) {
      evals <- list(sp_name = sp_name, model = "rf", aucs = aucs, thresholds = thresholds)
      save(evals, file = paste0(eval_out_dir, "/", sp_name, "_rf_eval.RDA"))

    }
  }
}


get_eval <- function(eval_file, threshold = "tss") {
  load(eval_file)
  model <- evals$model
  species <- evals$sp_name
  aucs <- mean(sapply(evals$aucs, function(x)
    x@auc))
  
  if (model == "glm") {
    thresholds  <-
      mean(exp(evals$thresholds[[threshold]]) / (1 + exp(evals$thresholds[[threshold]])))
  } else {
    thresholds  <- mean(evals$thresholds[[threshold]])
  }
  
  df_out <-
    data.frame(
      sp_name = species,
      model = model,
      auc = aucs,
      threshold = thresholds
    )
  return(df_out)
}


ensemble_model <-
  function(sp_names, eval_df, preds, out_dir, method = "weighted") {
    preds_f <- raster::stack(preds[grepl(sp_names, preds)])
    order <- gsub("_future", "", gsub(paste0(sp_names, "_"), "" , names(preds_f)))
    print(order)
    evals_f <- eval_df[eval_df$sp_name==sp_names,]#eval_df %>%
      #dplyr::filter(sp_name == sp_names)
    print(evals_f$model)
    aucs <- evals_f$auc
    print(all(order == evals_f$model))
    
    if (all(order == evals_f$model)) {
      if (method == "majority_pa") {
        ens_preds <- preds_f > evals_f$threshold
        ens_pa <- sum(ens_preds)
        ens_pa[ens_pa < round(raster::nlayers(preds_f))] <- 0
        ens_pa[ens_pa >= round(raster::nlayers(preds_f))] <- 1
        ens_out <- ens_pa
      }
      
      if (method == "weighted") {
        preds_w <- preds_f * aucs
        preds_sum <- sum(preds_w)
        ens_out <- preds_sum / sum(aucs)
        
      }
      
      if (method == "mean") {
        ens_out <- raster::calc(preds_f, mean, na.rm = TRUE)
        
      }
      
    }
    gc()
    
    if (!dir.exists(paste0(out_dir,"/", method))) {
      dir.create(paste0(out_dir,"/", method), recursive = T)
    }
    
    raster::writeRaster(ens_out, paste0(out_dir, "/",method, "/",sp_names, "_ensemble.tif"), overwrite = TRUE)
    return(ens_out)
  }



tax_out <- function(id) {
  out <- taxize::classification(id, db = "ncbi")
  sp_out <- NULL
  
  if (!is.na(out[[1]])) {
    profvis::pause(3)
    sp_out <-
      out[[1]][out[[1]]$rank %in% c("kingdom",
                                    "phylum",
                                    "class",
                                    "order",
                                    "family",
                                    "genus",
                                    "species"),]
    
    sp_out$kingdom <- sp_out$name[sp_out$rank == "kingdom"]
    sp_out$phylum <- sp_out$name[sp_out$rank == "phylum"]
    sp_out$class <- sp_out$name[sp_out$rank == "class"]
    sp_out$order <- sp_out$name[sp_out$rank == "order"]
    sp_out$family <- sp_out$name[sp_out$rank == "family"]
    sp_out$genus <- sp_out$name[sp_out$rank == "genus"]
    sp_out$species <- sp_out$name[sp_out$rank == "species"]
    
    
    sp_out <- sp_out %>%
      dplyr::select(kingdom, phylum, class, order, family, genus, species) %>%
      distinct()
    
  }
  return(sp_out)
}

ensembler <- function(sp_names, eval_df, preds, dir) {
  cuts = seq(0,1,0.05)#set breaks
  pal <- colorRampPalette(c("grey94","forestgreen","#339900"))
  
  pa_dir <- paste(dir, "ensemble/majority_pa", sep = "/")
  weighted_dir <- paste(dir, "ensemble/weighted", sep = "/")
  
  if (!dir.exists(here::here(pa_dir))) {
    dir.create(here::here(pa_dir), recursive = TRUE)
  }
  
  if (!dir.exists(here::here(weighted_dir))) {
    dir.create(here::here(weighted_dir), recursive = T)
  }
  
  pa <- ensemble_model(
    sp_names = sp_names,
    eval_df = eval_df,
    preds = preds,
    method = "majority_pa",
    out_dir = paste(dir, "ensemble", sep = "/")
  )
  
  wghtd <- ensemble_model(
    sp_names = sp_names,
    eval_df = eval_df,
    preds = preds,
    method = "weighted",
    out_dir = paste(dir, "ensemble", sep = "/")
  )
  
  plot(pa, main = "Future predicted distribtion", cex.main = 1, col = pal(length(cuts)))
  plot(wghtd, main = "Future predicted distribtion", cex.main = 1, col = pal(length(cuts)))
}

rasterGG <- function(raster){
  x <- as.data.frame(raster::rasterToPoints(raster))
  colnames(x) <- c("Longitude", "Latitude", "Occurrence")
  return(x)
}
