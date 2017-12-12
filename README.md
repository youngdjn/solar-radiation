# solar-radiation
A project to evaluate methods for incorporating solar radition into ecological analyses.

The analysis currently has three focal study areas: North Cascades National Park ("n"), Siskiyou Mountains ("c"), and Sequoia National Park ("s"). Input files (e.g., DEMs) and output files (e.g., solar radiation rasters) are created separately for each of the three study regions.

To preform analyses to address the study questions (e.g, to compare solar radition computed with and without topographic shading), it is not necessary to run the scripts in the "data-carpentry" folder (see below), as these scripts have already been run and their output (rasters of solar radition) saved in the "data" folder of the repository. It is possible (and much simpler) to use only the scripts in the "data-analysis" directory, as they use the data files (e.g., solar radiation rasters) that have already been computed and saved into the repo (in the "data" directory).

## Repository file structure:

* **data** (directory)
  * non-synced (directory): datasets (both input and output) that are too large to sync via github. These files are stored on Box at: https://ucdavis.box.com/v/solar-rad-non-synced. After you clone the GitHub repo, simply copy the whole folder "non-synced" from box into the "data" directory on your local computer and you will have all the files in the correct structure for use by the scripts.
  
  * **output** (directory): analysis outputs that are small enough to be synced on GitHub. Currently only contains rasters of total annual solar radiation (computed with and without topographic shading) for the focal study areas.
  
* **scripts** (directory)

  * **data-carpentry** (directory): Scripts to take existing datasets (i.e., so far only DEMs) and compute data layers necessary for the analyses of interest (i.e., so far only solar radiation rasters).
  
  * **data-analysis** (directory): Scripts to analyze the processed data to draw inferences and address the study questions
