setwd("~/UC Davis/Research Projects/Solar radiation/solar-radiation")

library(sf)
library(raster)
library(tidyverse)
library(rasterVis)
library(viridis)
library(gridExtra)

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


#### Compute other topography-related values (e.g., TPI) ####
rad.mccune.n = raster("data/output/annual_radiation_rasters/annual_mccune_n.tif")
tpi.n = raster("data/output/other_indices_rasters/tpi_n.tif")
aspect.n = raster("data/output/other_indices_rasters/aspect_n.tif")
northness.n = raster("data/output/other_indices_rasters/northness_n.tif")
dem.n = raster("data/output/other_indices_rasters/dem_n.tif")

#### Test relationship between radiation incorporating shading and not incorporating shading ####

rad.noshading.n = rad.noshading.n * 6.7e-7 # convert to MJ cm^2 yr^-1 
rad.shading.n = rad.shading.n * 6.7e-7 # convert to MJ cm^2 yr^-1 

a = gplot(dem.n) +
  geom_tile(aes(fill=value)) +
  scale_fill_viridis(name="Elevation (m)") +
  theme_bw() +
  labs(title="Elevation")

b = gplot(rad.noshading.n) +
  geom_tile(aes(fill=value)) +
  scale_fill_viridis(limits = c(0,2), name="Annual\nradiation\n(MJ cm-2 yr-1)") +
  theme_bw() +
  labs(title="GRASS solar radiation without topo shading")

c = gplot(rad.shading.n) +
  geom_tile(aes(fill=value)) +
  scale_fill_viridis(limits = c(0,2),name="Annual\nradiation\n(MJ cm-2 yr-1)") +
  theme_bw() +
  labs(title="GRASS solar radiation with topo shading")

d = gplot(rad.mccune.n) +
  geom_tile(aes(fill=value)) +
  scale_fill_viridis(name="Annual\nradiation\n(MJ cm-2 yr-1)") +
  theme_bw() +
  labs(title="McCune & Keon solar radiation")

grid.arrange(a,d,b,c)


layers.n = brick(rad.noshading.n,rad.shading.n,rad.mccune.n,tpi.n,aspect.n,northness.n)
names(layers.n) = c("rad.noshading","rad.shading","rad.mccune","tpi","aspect","northness")

rad.values.n = rasterToPoints(layers.n) %>% as.data.frame()


#take a subset of the pixels
keep.rows = seq(from=1,to=nrow(rad.values.n),by=10)
rad.subset.n = rad.values.n[keep.rows,]

a = ggplot(rad.subset.n,aes(x=rad.noshading,y=rad.shading)) +
  geom_point(alpha=.02,pch=16,size=2) +
  theme_bw() +
  labs(x="GRASS radiation without topo shading (MJ cm-2 yr-1)",
       y="GRASS radiation with topo shading (MJ cm-2 yr-1)") +
  annotate("text",x=0.75,y=1.75,label="R-sq = 0.87")

b = ggplot(rad.subset.n,aes(x=rad.noshading,y=rad.mccune)) +
  geom_point(alpha=.02,pch=16,size=2) +
  theme_bw() +
  labs(x="GRASS radiation without topo shading (MJ cm-2 yr-1)",
       y="McCune and Keon radiation (no topo shading) (MJ cm-2 yr-1)")


grid.arrange(a,b,nrow=1)


### Compute percent of points that are less than 10% of the noshading value
rad.subset.n = rad.subset.n %>%
  mutate(diff10 = rad.shading < 0.90*rad.noshading,
         propdiff = 100*(rad.noshading-rad.shading)/rad.noshading)

sum(rad.subset.n$diff10,na.rm=TRUE)/sum(!is.na(rad.subset.n))

cor(rad.subset.n$rad.shading,rad.subset.n$rad.noshading)^2


## plot prop diff vs. topo index
ggplot(rad.subset.n,aes(x=tpi,y=propdiff)) +
  geom_point(alpha=.01,pch=16,size=1.5) +
  theme_bw() +
  labs(x="Topographic position index (2.5 km radius)",
       y="Effect of topo. shading (% reduction in radiation)") +
  lims(y=c(0,50))


sum(rad.subset.n$propdiff > 0.9,na.rm=TRUE)/sum(!is.na(rad.subset.n))
