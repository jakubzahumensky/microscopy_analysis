This repository contains **Fiji (ImageJ) macros for automatic analysis of microscopy images**. Their use is explained in detail in **Zahumensky & Malinsky bioRxiv preprint: https://doi.org/10.1101/2024.03.28.587214**

# **Explanation of the Results table**  
For each cell/ROI, multiple paramers are quantified. As the *transversal (cross-sectional)* and *tangential* images show principally different things, the parameters decribing then are inherently different. At the same time, some parameters are common for the two image types. In the list below, they are grouped accordingly, and ordered as they are in the respective *Results table* for easier orientation.

## **Common parameters**
*extracted from the name of folders:*
- exp_code - experimental code; extracted from the name of the folder 3 levels above the data folder, based on used input in the dialog window shown when the *Quantify* macro is run; consult Fig. 3 in the Protocol
- BR_date - date of biological replicate; extracted from the name of the folder 2 levels above the data folder (first 6 characters); consult Fig. 3 in the Protocol

*extracted from the filename:*

The names of these parameters are set as default in the *Naming scheme* field of the dialog window shown when the *Quantify* macro is run. They should be changed to reflect the actual names of the user's files. Make sure that the number of comma-separated fields is the same in the filenames and in the *Naming scheme* input. Here, the parameters are explained as an example for microscopy images of yeast cells.

- strain - strain of the used yeast
- medium - medium in which the cells were cultivated
- time - cultivation time
- condition - how the cells were treated - control, heat stress, chemical treatment, etc.
- frame - typically multiple frames are obtained from a single culture/sample

*quantified from individual ROIs:*
- mean_background - mean intensity of the background of the image; assessed automatically by the macro
- cell_no - each cell/ROI has a designated number; corresponds to the ones displayed using the ROI manager in Fiji when both the image and the ROI_Set is loaded
- cell_area - corresponds to the area of the defined ROI
- cell_I.integral - integrated (total) fluorescence intensity within a specified ROI
- cell_I.mean - mean cellular intensity, i.e., integrated fluorescence intensity divided by the area of the ROI
- cell_I.SD - standard deviation of the mean cellular intensity
- cell_I.CV - coefficient of variation of the mean cellular intensity, calculated as SD/mean
- major_axis
- minor_axis
- eccentricity

## **Parameters for *transversal* images**
- cytosol_area
- cytosol_I.integral
- cytosol_I.mean
- cytosol_I.SD
- cytosol_I.CV
- plasma_membrane_area
- plasma_membrane_I.integral
- plasma_membrane_I.mean
- plasma_membrane_I.SD
- plasma_membrane_I.CV
- plasma_membrane_I.div.Cyt_I(mean)
- plasma_membrane_I.div.cell_I(integral)
- Cyt_I.div.cell_I(integral)
- foci_number
- foci_density
- foci_I.mean
- plasma_membrane_base
- foci_prominence
- foci_outliers
- foci_profile_CLAHE
- foci_density_profile_CLAHE
- foci_profile_dotfind
- foci_density_profile_dotfind
- foci_from_watershed
- foci_density_from_watershed
- protein_in_microdomains[%]

## **Parameters for *tangential* images**
- foci_density(find_maxima)
- foci_density(analyze_particles)
- area_fraction(foci_vs_ROI)
- length[um]
- length_SD[um]
- width[um]
- width_SD[um]
- size[um]
- size_SD[um]
- mean_foci_intensity
- mean_foci_intensity_SD
- protein_in_microdomains[%]
