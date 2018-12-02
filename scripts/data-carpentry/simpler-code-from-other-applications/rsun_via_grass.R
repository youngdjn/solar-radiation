setwd("~/UC Davis/Research Projects/Solar rad/solar-radiation")

library(rgrass7)
library(sf)
library(raster)
library(tidyverse)

### Convenience functions ###

## Function to make a geospatial bounding box (e.g. for )
bbox_fun <- function(x,y,width,height) { # give it the center
  x1 <- x-width/2
  x2 <- x+width/2
  y1 <- y+width/2
  y2 <- y-width/2
  bbox <- st_polygon(list(cbind(c(x1,x2,x2,x1,x1),c(y1,y1,y2,y2,y1))))
}


## Define constants (projection EPSG codes)
wgs84 <- 4326
albers <- 3310
utm11n <- 2955


### Open DEM ###
raster.file <- "data/non-synced/dem/dem_full_area.tif"
dem <- raster(raster.file)

### Define project area ###
bbox1 <- bbox_fun(-121.4,48.8,0.2,0.2) # north cascades
bbox2 <- bbox_fun(-123.3,42.1,0.2,0.2) # siskiyous
bbox3 <- bbox_fun(-118.7,36.7,0.2,0.2) # sequoia
bboxes <- st_sfc(bbox1,bbox2,bbox3,crs=wgs84)
bboxes <- st_transform(bboxes,crs=utm11n)

### Crop the DEM to the study area ###
bboxes_sp <- as(bboxes,"Spatial")
dem.crop <- crop(dem,bboxes_sp)
dem.crop <- mask(dem.crop,bboxes_sp)

writeRaster(dem.crop,"elev_geo.tif",overwrite=TRUE) # write it so we can resume here (because it takes so long), and also because GRASS needs a file (not an R object)



##!! set a temp GRASS directory within repo but set it not to sync

# Set GRASS environment and database location 
loc <- initGRASS("C:/Program Files/GRASS GIS 7.2.2", 
                 home=getwd(), gisDbase="GRASS_TEMP", override=TRUE )

raster.file <- "elev_geo.tif"



# Import raster to GRASS and set region
execGRASS("r.in.gdal", flags="o", parameters=list(input=raster.file, output="tmprast"))
execGRASS("g.region", parameters=list(raster="tmprast") ) 

#get the name of the mapset so we can switch back to it
mapset <- execGRASS("g.mapset",flags="p",intern=TRUE)

execGRASS("g.mapset",parameters=list(mapset="PERMANENT"))
execGRASS("g.proj",flags="c",parameters=list(georef=raster.file))
execGRASS("g.mapset",parameters=list(mapset=mapset))

execGRASS("r.slope.aspect", flags="overwrite", parameters=list(elevation="tmprast", slope="sloperast", aspect="asprast"))

execGRASS("r.sun", flags="overwrite", parameters=list(elevation="tmprast", linke_value=2, glob_rad="out", day=74, slope="sloperast", aspect="asprast") )

##!! need to write it and make sure it ignored the masked out areas
r <- readRAST("out")
r2 <- raster(r)
writeRaster(r2,"march_rad.tif",overwrite=TRUE)

r <- readRAST("sloperast")
r2 <- raster(r)
writeRaster(r2,"slope.tif",overwrite=TRUE)

r <- readRAST("asprast")
r2 <- raster(r)
writeRaster(r2,"asp.tif",overwrite=TRUE)
