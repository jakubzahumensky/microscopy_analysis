This repository contains **Fiji (ImageJ) macros for automatic analysis of microscopy images**. Their use is explained in detail in the **Zahumensky J., Malinsky J. Live cell fluorescence microscopy—an end-to-end workflow for high-throughput image and data analysis**. *Biology Methods and Protocols*, Volume 9, Issue 1, 2024, bpae075, (doi: <https://doi.org/10.1093/biomethods/bpae075>). The following text describes the output of the analysis, i.e., the *Results table*.

# **The *Results table***

The output of the *Quantify* macro is a single large comma-separated table with data from all cells across all analyzed experiments. The table starts with a header that contains basic information on the macro run, followed by the results of the analysis, where each row contains data on individual cells (ROIs). These are separated into columns whose meaning is explained below.

------------------------------------------------------------------------

## **Table header**

Each line of the header starts with the pound sign (`#`) so that it is automatically ignored by the provided scripts, both *bash* and *R*.

-   **Date and time** - date and time of the macro's execution (in YYYY-MM-DD HH:MM:SS format); note that the date and time of when the macro finished is written in the file name, using the same format.
-   **Macro version** - version of the *Quantify* macro used for the analysis; this is specified in both the macro file name and in the actual macro code, under the *version* variable (at/around line 35)
-   **Channel** - specifies which channel of the fluorescence microscopy images was selected for quantification (also stated in the file name)
-   **Cell (ROI) size interval** - the range of sizes (areas) of the cells (ROIs) that were quantified; cells (ROIs) with area outside this range are automatically ignored during the analysis; default is from 5 $\mu m^2$ to infinity
-   **Coefficient of variance threshold** - threshold used to automatically filter out cells based on the coefficient of variation of their mean fluorescence intensity; the idea is that the fluorescence of dead cells is quite uniform; the default value is 0 (i.e., nothing is filtered out); should be used with caution
-   **Smoothing radius (Gaussian blur)** *(transversal images only)* - the images are pre-processed before the analysis using a *Gaussian filter* to smooth out noise; the default value is 1
-   **Patch prominence** *(transversal images only)* - threshold value that designates how bright high-intensity foci need to be relative to their surroundings to be reported by the *foci_number* (see below); the value is set semi-empirically within the code to 1.666

------------------------------------------------------------------------

## **Columns**

For each cell/ROI, multiple parameters are quantified. While some parameters are common for transversal and tangential images, others are specific to the given image type. In the list below, they are grouped accordingly and ordered as they appear in the respective *Results table* for easier orientation. Note that all reported intensity values are background corrected.

------------------------------------------------------------------------

### **Common parameters**

#### extracted from the names of folders:

-   **exp_code** – experiment identifier (accession code), extracted from the folder three levels above the data folder
-   **BR_date** - date of biological replicate; extracted from the name of the folder 2 levels above the data folder (first 6 characters)

*for details on data structure consult Fig. 6 in [Zahumensky & Malinsky, 2024](https://doi.org/10.1093/biomethods/bpae075)*

#### extracted from the file names:

The names of the following parameters are set as default in the *Naming scheme* field of the *Quantify* macro dialog window. They should be changed to reflect the actual names of the user's files. Make sure that the number of comma-separated fields in the *Naming scheme* input is the same as in the actual file names. Here, the parameters are explained as an example for microscopy images of yeast cells.

-   **strain** - the strain of the used yeast
-   **medium** - medium in which the cells were cultivated
-   **time** - cultivation time
-   **condition** - how the cells were treated - control, heat stress, chemical treatment, etc.
-   **frame** - typically multiple frames are obtained from a single culture/sample

#### quantified from individual ROIs:

-   **mean_background** - mean intensity of the background of the image; assessed automatically by the macro; all reported intensity values are corrected for this number
-   **cell_no** - each cell (ROI) has a designated number; corresponds to the ones displayed in the ROI manager in *Fiji* when both the image and the *ROI_Set* are loaded
-   **cell_area** - the area of the specified ROI; note that the ROIs should be defined so that their edge is in the middle of the plasma membrane (if the ROIs correspond to cells); for the measurement of the cell area, the ROI is made *bigger* by 0.166 $\mu m$ in each direction
-   **cell_I.integrated** - total fluorescence intensity within a specified ROI made *bigger* by 0.166 $\mu m$ in each direction (see *cell_area*)
-   **cell_I.mean** - mean fluorescence intensity of the cell (ROI), i.e., *integrated fluorescence intensity* in the cell divided by the *cell area*, i.e., $`I^{integrated}_{cell}/area_{cell}`$
-   **cell_I.SD** - standard deviation of the mean fluorescence intensity of the cell
-   **cell_I.CV** - coefficient of variation of the mean fluorescence intensity of the cell, calculated as $SD/mean$
-   **axis_major** and **axis_minor** - the length of the major and minor axis of the ellipse fitted to the respective ROI
-   **eccentricity** - deviation from a perfect circle of the ellipse fitted to the respective ROI; calculated as $\sqrt{1-(axis_{minor}/axis_{major})^2}$

------------------------------------------------------------------------

### **Parameters for *transversal* images**

-   **cytosol_area** - area of the cytosol of the corresponding cell; the ROIs should be defined so that their edge is in the middle of the plasma membrane (if the ROIs correspond to cells); for the measurement of the cytosol area, the ROI is made *smaller* by 0.166 $\mu m$ in each direction
-   **cytosol_I.integrated** - total fluorescence intensity within a specified ROI made *smaller* by 0.166 $\mu m$ in each direction
-   **cytosol_I.mean** - mean fluorescence intensity of the cytosol, i.e., integrated fluorescence intensity of the cytosol divided by the cytosol area, i.e., $`I^{integrated}_{cytosol}/area_{cytosol}`$
-   **cytosol_I.SD** - standard deviation of the mean fluorescence intensity in the cytosol
-   **cytosol_I.CV** - coefficient of variation of the mean fluorescence intensity in the cytosol, calculated as $SD/mean$
-   **plasma_membrane_area** - area of the plasma membrane (PM), i.e., $area_{cell}-area_{cytosol}$
-   **plasma_membrane_I.integrated** - total fluorescence intensity within the plasma membrane
-   **plasma_membrane_I.mean** - mean fluorescence intensity in the plasma membrane (PM), i.e., integrated fluorescence intensity of the plasma membrane divided by the plasma membrane area, i.e., $`I^{integrated}_{PM}/area_{PM}`$
-   **plasma_membrane_I.SD** - standard deviation of the mean fluorescence intensity in the plasma membrane
-   **plasma_membrane_I.CV** - coefficient of variation of the mean fluorescence intensity in the plasma membrane, calculated as $SD/mean$
-   **plasma_membrane_I.div.cyt_I(mean)** - ratio of mean fluorescence intensities in the plasma membrane and the cytosol, i.e., $`I^{mean}_{PM}/I^{mean}_{cytosol}`$
-   **plasma_membrane_I.div.cell_I(integrated)** - ratio of integrated fluorescence intensities in the plasma membrane and the whole cell, i.e., $`I^{integrated}_{PM}/I^{integrated}_{cell}`$
-   **cyt_I.div.cell_I(integrated)** - ratio of integrated fluorescence intensities in the cytosol and the whole cell, i.e., $`I^{integrated}_{cytosol}/I^{integrated}_{cell}`$
-   **foci_number** - number of detected high-intensity foci in the plasma membrane that may correspond to microdomains; detected from an intensity profile after minimal image processing, based on predefined thresholds for absolute intensity and intensity relative to the surrounding valleys (local minima)
-   **foci_density** - linear density of detected high-intensity foci in the plasma membrane, i.e., $number_{foci}/length_{PM}$, where $length_{PM}$ corresponds to the circumference of the respective ROI
-   **foci_I.mean** - mean fluorescence intensity of the maxima of detected high-intensity foci in the plasma membrane within a single cell
-   **plasma_membrane_base** - mean fluorescence intensity of the valleys (local minima) between detected high-intensity foci in the plasma membrane within a single cell
-   **foci_prominence** - the ratio of *foci_I.mean* and *plasma_membrane_base*
-   **foci_outliers** - number of detected high-intensity foci in the plasma membrane with intensity higher than ***XYZ*** $\times$ *plasma_membrane_base*
-   **foci_profile_CLAHE** and **foci_density_profile_CLAHE** - analogous to *foci_number* and *foci_density*, but after local contrast enhancement using the built-in CLAHE plugin with he following parameters: "blocksize=8 histogram=64 maximum=3 mask=*None*”
-   **foci_profile_dotfind** and **foci_density_profile_dotfind** - analogous to *foci_number* and *foci_density*, but after local contrast enhancement performed by filtering the image using a custom-made matrix that makes the high-intensity foci more prominent:

$$
\begin{pmatrix}
 -1 & -1 & -1 & -1 & -1 \\
 -1 & 0 & 0 & 0 & -1 \\
 -1 & 0 & 16 & 0 & -1 \\
 -1 & 0 & 0 & 0 & -1 \\
 -1 & -1 & -1 & -1 & -1
 \end{pmatrix}
$$

-   **foci_threshold_Gauss** and **foci_density_threshold_Gauss** - number of detected high-intensity foci in the plasma membrane that may correspond to microdomains, detected after cell/ROI-limited intensity thresholding after minimal image processing; linear density of these foci (see foci_density above)
-   **foci_threshold_CLAHE** and **foci_density_threshold_CLAHE** - analogous to *foci_threshold_Gauss* and *foci_density_threshold_Gauss*, but after local contrast enhancement using the built-in CLAHE plugin with he following parameters: "blocksize=8 histogram=64 maximum=3 mask=*None*”
-   **foci_threshold_dotfind** and **foci_density_threshold_dotfind** - analogous to *foci_threshold_Gauss* and *foci_density_threshold_Gauss*, but after local contrast enhancement performed by filtering the image using the *dotfind* matrix (see above)
-   **foci_from_watershed** and **foci_density_from_watershed** - analogous to *foci_number* and *foci_density*, but after binarization of the image using the *Watershed Segmentation* plugin developed by *EPFL* (<http://bigwww.epfl.ch/sage/soft/watershed>) with the following settings: “blurring='0.0' watershed='1 1 0 255 1 0' display='2 0'”
-   **protein_in_microdomains[%]** - an integrated intensity-based estimate of how much of the fluorescent protein in the plasma membrane localizes to microdomains (high-intensity foci)
-   **internal_foci_count** - the number of high intensity foci found in the cell cytosol
-   **internal_foci_average_size** - average size of the high intensity foci found in the cell cytosol
-   **internal_foci_total_area** - total area taken up by the high intensity foci found in the cell cytosol ($count \times average size$)
-   **internal_foci_I.mean** - mean fluorescence intensity of the internal foci
-   **internal_foci_I.SD** - standard deviation of the mean fluorescence intensity of the internal foci

------------------------------------------------------------------------

### **Parameters for *tangential* images**

-   **foci_density(find_maxima)** - areal density of high-intensity foci in the plasma membrane, detected using the built-in *Find maxima* Fiji plugin (with *prominence* set to 1.666 and *exclude on edges* activated), i.e., $number_{foci}/area_{ROI}$, where $area_{ROI}$ corresponds to the area of the respective ROI
-   **foci_density(analyze_particles)** - areal density of high-intensity foci in the plasma membrane detected using the *Analyze particles* plugin and taking objects with area between 5 and 120 pixels. The image of the respective cell (ROI) is first binarized using adaptive thresholding. From the objects at the ROI boundary, only those touching the lower and right "edges" are counted (analogous to how a Bürker chamber is used to count cells in a suspension)
-   **area_fraction(foci_vs_ROI)** - total area of objects reported in *foci_density(analyze_particles)* divided by the area of the ROI, i.e., $area_{particles}/area_{ROI}$; gives an estimate of how much of the plasma membrane is covered with the studied microdomains
-   **length[um]** and **length_SD[um]** - mean and standard deviation of the length of the particles counted in *foci_density(analyze_particles)*, i.e., high-intensity foci (microdomains)
-   **width[um]** and **width_SD[um]** - mean and standard deviation of the width of the particles counted in *foci_density(analyze_particles)*, i.e., high-intensity foci (microdomains)
-   **size[um]** and **size_SD[um]** - mean and standard deviation of the size (area) of the particles counted in *foci_density(analyze_particles)*, i.e., high-intensity foci (microdomains)
-   **mean_foci_intensity** and **mean_foci_intensity_SD** - mean and standard deviation of the fluorescence intensity of the particles counted in *foci_density(analyze_particles)*, i.e., high-intensity foci (microdomains)
-   **protein_in_microdomains[%]** - an integrated intensity-based estimate of how much of the fluorescent protein in the plasma membrane localizes to microdomains (high-intensity foci)
