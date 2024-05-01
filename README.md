This repository contains **Fiji (ImageJ) macros for automatic analysis of microscopy images**. Their use is explained in detail in **Zahumensky & Malinsky bioRxiv preprint: https://doi.org/10.1101/2024.03.28.587214**

# **Explanation of the *Results table***

## **Table header**

The *Results table* header contains basic information about the run of the *Quantify* macro, so if the analysis is run multiple times, the changes in the results can be correlated with input parameters and macro version. Each line of the header starts with the pound (#) sign, so that it is automatically ignored by the provided scripts, both *bash* and *R*.


### Common parameters
- **Date and time** - date and time of when the macro was run in the YYYY-MM-DD HH:MM:SS format
- **Macro version** - version of the *Quantify* macro that was used, specified in both the macro file name and in the actual macro code, under the *version* variable (at/around line 35)
- **Channel** - specifies which channel of the fluorescence microscopy images was selected for quantification
- **Cell (ROI) size interval** - gives the range of sizes (areas) of the cells (ROIs) that were quantified; default is 5 $\mu m^2$-Infinity
- **Coefficient of variance threshold** - reports what threshold was used to automatically discard cells based on the coefficient of variation of their mean fluorescence intensity; the idea is that the fluorescence of dead cells is quite uniform; the default value is 0; should be used with caution

### Parameters for *transversal* images
- **Smoothing factor (Gauss):** - the images are pre-processed before the analysis using a *Gaussian filter* to smooth out noise; the default value is 1
- **Patch prominence** - designates how bright high-intensity foci need to be relative to their surroundings to be reported by the *foci_number* (see below); the value is set semi-empirically within the code to 1.666


## **Quantification parameters**

For each cell/ROI, multiple parameters are quantified. As the *transversal (cross-sectional)* and *tangential* images show principally different things, the parameters describing then are inherently different. At the same time, some parameters are common for the two image types. In the list below, they are grouped accordingly, and ordered as they are in the respective *Results table* for easier orientation. Note that all reported intensity values are background-corrected.

### **Common parameters**
***extracted from the name of folders:***

- **exp_code** - experimental code; extracted from the name of the folder 3 levels above the data folder, based on used input in the dialog window shown when the *Quantify* macro is run; consult Fig. 3 in the Protocol
- **BR_date** - date of biological replicate; extracted from the name of the folder 2 levels above the data folder (first 6 characters); consult Fig. 3 in the Protocol


***extracted from the file name:***

The names of these parameters are set as default in the *Naming scheme* field of the dialog window shown when the *Quantify* macro is run. They should be changed to reflect the actual names of the user's files. Make sure that the number of comma-separated fields is the same in the file names and in the *Naming scheme* input. Here, the parameters are explained as an example for microscopy images of yeast cells.

- **strain** - strain of the used yeast
- **medium** - medium in which the cells were cultivated
- **time** - cultivation time
- **condition** - how the cells were treated - control, heat stress, chemical treatment, etc.
- **frame** - typically multiple frames are obtained from a single culture/sample


***quantified from individual ROIs:***

- **mean_background** - mean intensity of the background of the image; assessed automatically by the macro
- **cell_no** - each cell/ROI has a designated number; corresponds to the ones displayed using the ROI manager in Fiji when both the image and the ROI_Set is loaded
- **cell_area** - the ROIs should be defined so that their edge is located in the middle of the plasma membrane (if the ROIs correspond to cells); for the measurement of the cell area, the ROI is made *bigger* by 0.166 $\mu m$ in each direction
- **cell_I.integral** - integrated (total) fluorescence intensity within a specified ROI made *bigger* by 0.166 $\mu m$ in each direction
- **cell_I.mean** - mean cellular intensity, i.e., integrated fluorescence intensity divided by the *cell area*
- **cell_I.SD** - standard deviation of the mean cellular intensity
- **cell_I.CV** - coefficient of variation of the mean cellular intensity, calculated as $SD/mean$
- **major_axis** - the length of the major axis of the ellipse fitted to the respective ROI
- **minor_axis** - the length of the minor axis of the ellipse fitted to the respective ROI
- **eccentricity** - i.e., deviation from a perfect circle, of the ellipse fitted to the respective ROI; calculated as $\sqrt{1-(axis_{minor}/axis_{major})^2}$


### **Parameters for *transversal* images**
- **cytosol_area** - the ROIs should be defined so that their edge is located in the middle of the plasma membrane (if the ROIs correspond to cells); for the measurement of the cell area, the ROI is made *smaller* by 0.166 $\mu m$ in each direction
- **cytosol_I.integral** - integrated (total) fluorescence intensity within a specified ROI made *smaller* by 0.166 $\mu m$ in each direction
- **cytosol_I.mean** - mean cytosol intensity, i.e., integrated fluorescence intensity divided by the *cytosol area*
- **cytosol_I.SD** - standard deviation of the mean cytosol intensity
- **cytosol_I.CV** - coefficient of variation of the mean cytosol intensity, calculated as $SD/mean$
- **plasma_membrane_area** - area of the plasma membrane, i.e., $area_{cell}-area_{cytosol}$
- **plasma_membrane_I.integral** - integrated (total) fluorescence intensity within the plasma membrane
- **plasma_membrane_I.mean** - mean fluorescence intensity in the plasma membrane, i.e., integrated fluorescence intensity divided by the *plasma membrane area*
- **plasma_membrane_I.SD** - standard deviation of the mean plasma membrane intensity
- **plasma_membrane_I.CV** - coefficient of variation of the mean cellular intensity, calculated as $`SD/mean`$
- **plasma_membrane_I.div.Cyt_I(mean)** - ratio of mean fluorescence intensities in the plasma membrane and the cytosol, i.e., $`I^{mean}_{PM}/I^{mean}_{cytosol}`$
- **plasma_membrane_I.div.cell_I(integral)** - ratio of integral fluorescence intensities in the plasma membrane and the whole cell, i.e., $`I^{integral}_{PM}/I^{integral}_{cell}`$
- **Cyt_I.div.cell_I(integral)** - ratio of integral fluorescence intensities in the cytosol and the whole cell, i.e., $`I^{integral}_{cytosol}/I^{integral}_{cell}`$
- **foci_number** - number of detected high-intensity foci in the plasma membrane that may correspond to microdomains; detected from an intensity profile after minimal image processing, based on predefined thresholds for absolute intensity and intensity relative to the surrounding valleys
- **foci_density** - linear density of detected high-intensity foci in the plasma membrane, i.e., $number_{foci}/length_{PM}$, where $length_{PM}$ corresponds to the circumference of the respective ROI
- **foci_I.mean** - mean fluorescence intensity of the maxima of detected high-intensity foci in the plasma membrane within a single cell
- **plasma_membrane_base** - mean fluorescence intensity of the minima (valleys) between detected high-intensity foci in the plasma membrane within a single cell
- **foci_prominence** - the ratio of *foci_I.mean* and *plasma_membrane_base*
- **foci_outliers** - number of detected high-intensity foci in the plasma membrane with intensity higher than XYZ* *plasma_membrane_base*
- **foci_profile_CLAHE** and **foci_density_profile_CLAHE** - analogous to *foci_number* and *foci_density*, but after local contrast enhancement using the built-in CLAHE plugin
- **foci_profile_dotfind** and **foci_density_profile_dotfind** - analogous to *foci_number* and *foci_density*, but after local contrast enhancement performed by filtering the image using a custom-made matrix that makes the high-intensity foci more prominent:
```math
\begin{bmatrix}
  -1 & -1 & -1 & -1 & -1 \\
  -1 & 0 & 0 & 0 & -1 \\
  -1 & 0 & 16 & 0 & -1 \\
  -1 & 0 & 0 & 0 & -1 \\
  -1 & -1 & -1 & -1 & -1
 \end{bmatrix}
```
- **foci_from_watershed** and **foci_density_from_watershed** - analogous to *foci_number* and *foci_density*, but after binarization of the image using the *Watershed Segmentation* plugin developed by *EPFL* (http://bigwww.epfl.ch/sage/soft/watershed), with following settings: blurring='0.0' watershed='1 1 0 255 1 0' display='2 0'
- **protein_in_microdomains[%]** - integral intensity-based estimate of how much of the fluorescent protein in the plasma membrane localizes to microdomains (high-intensity foci)

### **Parameters for *tangential* images**
- **foci_density(find_maxima)** - areal density of high-intensity foci in the plasma membrane, detected using the in-built *Find maxima* Fiji plugin (with *prominence* set to 1.666 and *exclude on edges* activated), i.e., $number_{foci}/length_{PM}$, where $length_{PM}$ corresponds to the circumference of the respective ROI
- **foci_density(analyze_particles)** - areal density of high-intensity foci in the plasma membrane, using the *Analyze particles* plugin and taking objects with area between 5 and 120 pixels. The image of respective cell (ROI) is first binarized using adaptive thresholding. From the objects at the ROI boundary, only those touching the lower and right "edges" are counted (analogous to how a Bruker chamber is used to count cells in a suspension)
- **area_fraction(foci_vs_ROI)** - total area of objects reported in *foci_density(analyze_particles)* divided by the area of the ROI, i.e., $area_{particles}/area_{ROI}$; gives an estimate of how much of the plasma membrane is covered with the studied microdomains
- **length[um]** and **length_SD[um]** - mean and standard deviation of the length of the particles counted in *foci_density(analyze_particles)*, i.e., high-intensity foci (microdomains)
- **width[um]** and **width_SD[um]** - mean and standard deviation of the width of the particles counted in *foci_density(analyze_particles)*, i.e., high-intensity foci (microdomains)
- **size[um]** and **size_SD[um]** - mean and standard deviation of the size (area) of the particles counted in *foci_density(analyze_particles)*, i.e., high-intensity foci (microdomains)
- **mean_foci_intensity** and **mean_foci_intensity_SD** - mean and standard deviation of the fluorescence intensity of the particles counted in *foci_density(analyze_particles)*, i.e., high-intensity foci (microdomains)
- **protein_in_microdomains[%]** - integral intensity-based estimate of how much of the fluorescent protein in the plasma membrane localizes to microdomains (high-intensity foci)
