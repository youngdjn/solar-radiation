setwd("~/Research Projects/Solar rad postfire-management_temp")

library(rgrass7)
library(sf)
library(raster)

wgs84 <- "+proj=longlat +datum=WGS84 +no_defs"



raster.file <- "C:/Users/DYoung/Documents/GIS/CA abiotic layers/DEM/CA/new ncal/CAmerged14_albers.tif"
dem <- raster(raster.file)

study.plots <- st_read("C:/Users/DYoung/Documents/Research Projects/Post-fire management/postfire-management/data/field-processed/spatial/plots_points.gpkg")


study.area <- st_buffer(study.plots,15000)
study.area <- st_union(study.area)
study.area <- as(study.area,"Spatial")
study.area <- spTransform(study.area,projection(dem))

dem.crop <- crop(dem,study.area)
dem.crop <- mask(dem.crop,study.area)

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



execGRASS("r.sun", flags="overwrite", parameters=list(elevation="tmprast", linke_value=2, glob_rad="rad_winter", day=355, slope="sloperast", aspect="asprast") )
execGRASS("r.sun", flags="overwrite", parameters=list(elevation="tmprast", linke_value=2, glob_rad="rad_winter_spring", day=35, slope="sloperast", aspect="asprast") )
execGRASS("r.sun", flags="overwrite", parameters=list(elevation="tmprast", linke_value=2, glob_rad="rad_spring", day=79, slope="sloperast", aspect="asprast") )
execGRASS("r.sun", flags="overwrite", parameters=list(elevation="tmprast", linke_value=2, glob_rad="rad_spring_summer", day=125, slope="sloperast", aspect="asprast") )
execGRASS("r.sun", flags="overwrite", parameters=list(elevation="tmprast", linke_value=2, glob_rad="rad_summer", day=171, slope="sloperast", aspect="asprast") )




r <- readRAST("sloperast")
r2 <- raster(r)
writeRaster(r2,"slope.tif",overwrite=TRUE)

r <- readRAST("asprast")
r2 <- raster(r)
writeRaster(r2,"asp.tif",overwrite=TRUE)





##!! need to write it and make sure it ignored the masked out areas
r <- readRAST("rad_winter")
r2 <- raster(r)
writeRaster(r2,"rad_winter.tif",overwrite=TRUE)

r <- readRAST("rad_winter_spring")
r2 <- raster(r)
writeRaster(r2,"rad_winter_spring.tif",overwrite=TRUE)

r <- readRAST("rad_spring")
r2 <- raster(r)
writeRaster(r2,"rad_spring.tif",overwrite=TRUE)

r <- readRAST("rad_spring_summer")
r2 <- raster(r)
writeRaster(r2,"rad_spring_summer.tif",overwrite=TRUE)

r <- readRAST("rad_summer")
r2 <- raster(r)
writeRaster(r2,"rad_summer.tif",overwrite=TRUE)


