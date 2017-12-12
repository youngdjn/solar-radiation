setwd("~/UC Davis/Research Projects/Solar radiation/solar-radiation")

library(sf)
library(raster)
library(tidyverse)

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


#### Load solar radiation layers ####
rad.noshading.n <- raster("data/output/annual_radiation_rasters/annual_noshading_n.tif") # north cascades
rad.shading.n <- raster("data/output/annual_radiation_rasters/annual_shading_n.tif") # north cascades

rad.noshading.c <- raster("data/output/annual_radiation_rasters/annual_noshading_c.tif") # siskiyous
rad.shading.c <- raster("data/output/annual_radiation_rasters/annual_shading_c.tif") #

rad.noshading.s <- raster("data/output/annual_radiation_rasters/annual_noshading_s.tif") # sequoia np
rad.shading.s <- raster("data/output/annual_radiation_rasters/annual_shading_s.tif") #

#### Test relationship between radiation incorporating shading and not incorporating shading ####

plot(rad.noshading.n)
plot(rad.shading.n)

noshading.values <- values(rad.noshading.n)
shading.values <- values(rad.shading.n)

plot(noshading.values,shading.values)

cor(noshading.values,shading.values,use="complete.obs") # correlation of 0.932
