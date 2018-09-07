setwd("~/UC Davis/Research Projects/Solar radiation/solar-radiation") #Derek
setwd("~/Documents/research/solarrad/solar-radiation") #Jesse 
# Demo comment
library(rgrass7)
library(sf)
library(raster)
library(tidyverse)
library(spatialEco)

#### Constants and convenience functions ####

## Define constants (projection EPSG codes)
wgs84 <- 4326
albers <- 3310
utm11n <- 26911
utm10n <- 26910

## Function to make a geospatial bounding box (e.g. for study areas)
bbox_fun <- function(x,y,width,height) { # give it the center and its width and height
  x1 <- x-width/2
  x2 <- x+width/2
  y1 <- y+width/2
  y2 <- y-width/2
  bbox <- st_polygon(list(cbind(c(x1,x2,x2,x1,x1),c(y1,y1,y2,y2,y1))))
}

rad2deg <- function(rad) {
  return(rad*180/3.14)
}
deg2rad <- function(deg) {
  return((deg/180)*3.14)
}


#### Load DEMs ####
#(these extend way beyond the project boundaries so that they can be trimmed down later)
dem.n <- raster("data/non-synced/dem/dem_n.tif") # north cascades
dem.c <- raster("data/non-synced/dem/dem_c.tif") # siskoyous
dem.s <- raster("data/non-synced/dem/dem_s.tif") # sequoia np

#### Define project area ####
bbox1 <- bbox_fun(-121.4,48.8,0.1,0.1) # north cascades # was 0.2
bbox2 <- bbox_fun(-123.3,42.1,0.1,0.1) # siskiyous
bbox3 <- bbox_fun(-118.7,36.7,0.1,0.1) # sequoia
bboxes <- st_sfc(bbox1,bbox2,bbox3,crs=wgs84)
bboxes <- st_transform(bboxes,crs=utm10n)
bboxes_sp <- as(bboxes,"Spatial")

### Crop the DEM to study area ###
# north area
dem.crop.n <- crop(dem.n,bboxes_sp[1])

# central area
dem.crop.c <- crop(dem.c,bboxes_sp[2])

# south area
dem.crop.s <- crop(dem.s,bboxes_sp[3])

# save them in a list in order to loop through them
dems <- list(dem.crop.n,dem.crop.c,dem.crop.s)



#### Compute DEM-derived values (other than GRASS radiation) ####
#! currently only  for northern study region

## TPI
tpi.n = tpi(dem.crop.n,scale=51,win="rectangle",normalize=TRUE)

## aspect
aspect.n = terrain(dem.crop.n,opt="aspect",unit="radians")
northness.n = cos(aspect.n)
names(aspect.n) = "aspect"

## slope
slope.n = terrain(dem.crop.n,opt="slope",unit="radians")
names(slope.n) = "slope"

## latitude
lat.n = init(dem.crop.n,"y")

## longitude
long.n = init(dem.crop.n,"x")

## lat & long
coords.n = brick(lat.n,long.n)
coords.points.n = rasterToPoints(coords.n) %>% as.data.frame()

## convert to sf points so can reproject to lat/long
coords.sf = st_as_sf(coords.points.n,coords=c("x","y"),crs=utm10n)
coords.sf = st_transform(coords.sf,crs=wgs84)
lat.geo.n = st_coordinates(coords.sf)[,"Y"]

values(lat.n) = lat.geo.n
names(lat.n)= "latitude"


## Compute McCune radiation (not heat load) ##
mccune.rad = function(lat,slope,aspect) {
  ln.rad = -1.467 + 1.582*cos(lat)*cos(slope) + -1.500*cos(aspect)*sin(slope)*sin(lat) + -0.262*sin(lat)*sin(slope) + 0.607*sin(aspect)*sin(slope)
  return((ln.rad))
}

mccune.rad(deg2rad(40),deg2rad(30),deg2rad(180)) # in MJ cm^-2 yr^-1 ## testing using McCune's given test case; ##!! NOTE the ouput doesn't perfectly match what McCune says it should! There must be an error in the coefs that McCune reports

mccune.input.rast = brick(aspect.n,slope.n,lat.n)
mccune.input.data = rasterToPoints(mccune.input.rast) %>% as.data.frame()

mccune.rad.values = mccune.rad(lat = deg2rad(mccune.input.data$latitude),
                               slope = mccune.input.data$slope,
                               aspect = mccune.input.data$aspect)

mccune.rad.raster.n = mccune.input.rast[[1]]

values(mccune.rad.raster.n) = mccune.rad.values


## write them all
writeRaster(tpi.n,"data/output/other_indices_rasters/tpi_n.tif",overwrite=TRUE)
writeRaster(aspect.n,"data/output/other_indices_rasters/aspect_n.tif",overwrite=TRUE)
writeRaster(northness.n,"data/output/other_indices_rasters/northness_n.tif",overwrite=TRUE)
writeRaster(dem.crop.n,"data/output/other_indices_rasters/dem_n.tif",overwrite=TRUE)
writeRaster(mccune.rad.raster.n,"data/output/annual_radiation_rasters/annual_mccune_n.tif",overwrite=TRUE)


#### Compute GRASS solar radiation ####


rad.brick.shading <- list()
rad.sum.shading <- list()
rad.brick.noshading <- list()
rad.sum.noshading <- list()

for (i in 1:length(dems)) {
  
  dem <- dems[[i]]
  
  # write it because GRASS needs a file (not an R object)
  writeRaster(dem,"data/non-synced/temporary/dem_focal.tif",overwrite=TRUE)
  
  
  ##!! set a temp GRASS directory within repo but set it not to sync
  
  # Set GRASS environment and database location 
  loc <- initGRASS("C:/Program Files/GRASS GIS 7.2.2", 
                   home=getwd(), gisDbase="data/non-synced/GRASS_TEMP", override=TRUE )
  
  raster.file <- "data/non-synced/temporary/dem_focal.tif"
  
  # Import raster to GRASS and set region
  execGRASS("r.in.gdal", flags="o", parameters=list(input=raster.file, output="demfocal"))
  execGRASS("g.region", parameters=list(raster="demfocal") ) 
  
  #get the name of the mapset so we can switch back to it
  mapset <- execGRASS("g.mapset",flags="p",intern=TRUE)
  
  #set the projection of location (must be done in the "PERMANENT" mapset)
  execGRASS("g.mapset",parameters=list(mapset="PERMANENT"))
  execGRASS("g.proj",flags="c",parameters=list(georef=raster.file))
  execGRASS("g.mapset",parameters=list(mapset=mapset))
  
  # calculate slope and aspect from the DEM
  execGRASS("r.slope.aspect", flags="overwrite", parameters=list(elevation="demfocal", slope="sloperast", aspect="asprast"))
  
  # calculate horizon (speeds up r.sun later because we calculate horizon only once then we can use the result to compute radiation for each day, rather than computing horizon separately for each day)
  execGRASS("r.horizon",parameters=list(elevation="demfocal", step=30, bufferzone=200, output="horizonangle", maxdistance=5000))

  # for every 5th day of the year
  daily.rad.shading <- list()
  daily.rad.noshading <- list()
  for(j in 1:73) { # if for every third day: 121
    
    day <- j*5-4 # do it for every fifth day # previously when doing for every third day:  j*3-2
    day.name <- paste0("day",day)
    
    cat("Running rad for region ",i," day ",day)
    
    #rad.output.name <- paste0("region_",i,"_day_",j)
    
    # calculate radiation (with shading)
    execGRASS("r.sun", flags=c("overwrite"), parameters=list(elevation="demfocal", horizon_basename="horizonangle", horizon_step=30, linke_value=2, glob_rad="rad_out", day=day, slope="sloperast", aspect="asprast"),Sys_show.output.on.console=FALSE)
    daily.rad.shading[[day.name]] <- raster(readRAST("rad_out"))

    # calculate radiation (without shading)
    execGRASS("r.sun", flags=c("p","overwrite"), parameters=list(elevation="demfocal", horizon_basename="horizonangle", horizon_step=30, linke_value=2, glob_rad="rad_out", day=day, slope="sloperast", aspect="asprast"),Sys_show.output.on.console=FALSE)
    daily.rad.noshading[[day.name]] <- raster(readRAST("rad_out"))

  }
  
  rad.brick.shading[[i]] <- brick(daily.rad.shading)
  rad.sum.shading[[i]] <- sum(rad.brick.shading[[i]])*5 * 6.7e-7 # convert to MJ cm^2 yr^-1     # previously when doing for every third day: *3 + 2*rad.brick.shading[[i]][[nlayers(rad.brick.shading[[i]])]] # add the last day on twice more because otherwise we would have summed radiation for days 1-363
    
  rad.brick.noshading[[i]] <- brick(daily.rad.noshading)
  rad.sum.noshading[[i]] <- sum(rad.brick.noshading[[i]])*5 * 6.7e-7 # convert to MJ cm^2 yr^-1 # previously when doing for every third day: *3 + 2*rad.brick.noshading[[i]][[nlayers(rad.brick.noshading[[i]])]]
  
  
  
}



values.shading <- values(rad.sum.shading[[1]])
values.noshading <- values(rad.sum.noshading[[1]])



## write a multiband TIFF for each study region

writeRaster(rad.brick.shading[[1]],"data/non-synced/output_daily_radiation_rasters/daily_shading_n.grd",overwrite=TRUE)
writeRaster(rad.brick.shading[[2]],"data/non-synced/output_daily_radiation_rasters/daily_shading_c.grd",overwrite=TRUE)
writeRaster(rad.brick.shading[[3]],"data/non-synced/output_daily_radiation_rasters/daily_shading_s.grd",overwrite=TRUE)

writeRaster(rad.brick.noshading[[1]],"data/non-synced/output_daily_radiation_rasters/daily_noshading_n.grd",overwrite=TRUE)
writeRaster(rad.brick.noshading[[2]],"data/non-synced/output_daily_radiation_rasters/daily_noshading_c.grd",overwrite=TRUE)
writeRaster(rad.brick.noshading[[3]],"data/non-synced/output_daily_radiation_rasters/daily_noshading_s.grd",overwrite=TRUE)

writeRaster(rad.sum.shading[[1]],"data/output/annual_radiation_rasters/annual_shading_n.tiff",overwrite=TRUE)
writeRaster(rad.sum.shading[[2]],"data/output/annual_radiation_rasters/annual_shading_c.tiff",overwrite=TRUE)
writeRaster(rad.sum.shading[[3]],"data/output/annual_radiation_rasters/annual_shading_s.tiff",overwrite=TRUE)

writeRaster(rad.sum.noshading[[1]],"data/output/annual_radiation_rasters/annual_noshading_n.tiff",overwrite=TRUE)
writeRaster(rad.sum.noshading[[2]],"data/output/annual_radiation_rasters/annual_noshading_c.tiff",overwrite=TRUE)
writeRaster(rad.sum.noshading[[3]],"data/output/annual_radiation_rasters/annual_noshading_s.tiff",overwrite=TRUE)

