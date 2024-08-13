# Automated analysis of microscopy data - from images to numbers and plots
This repository contains custom **Fiji (ImageJ)** macros and **R scripts (markdown)** that we have developed for automatic analysis of microscopy images. The required data structure and use of the code is described in detail in: **Zahumensky & Malinsky bioRxiv preprint - Live Cell Fluorescence Microscopy – From Sample Preparation to Numbers and Plots** (doi: https://doi.org/10.1101/2024.03.28.587214).
For detailed description of the parameters reported in the Results table see _results_table_legend.md_ in the _Fiji macros_ folder.  

## Required software:
### Segmentation of cells/objects:
**Cellpose 2.0** (Stringer et al., 2021): https://www.cellpose.org/  
- Installation instructions can be found at https://github.com/MouseLand/cellpose/blob/main/README.md  
- The *Cellpose Readme* website includes instructions on the installation of Python (https://www.python.org/downloads/) and Anaconda (https://www.anaconda.com/download); both are required for the running of Cellpose  
  
### Segmentation verification and the actual data analysis:
**Fiji** (ImageJ 1.53t or higher): https://imagej.net/software/fiji/downloads  
The macros require additional plugins/libraries that are not part of the general Fiji download:  
- *SCF-MPI-CBG* and *BIG-EPFL* - to install, navigate through Help → Update → Manage update sites, then tick checkboxes for BIG-EPFL and SCF MPI CBG. Click Apply and Close → Apply changes → OK; restart Fiji  
- *Watershed_* plugin - to install, download from http://bigwww.epfl.ch/sage/soft/watershed/ and place it in the plugins folder of Fiji/ImageJ  
- *Adjustable Watershed* plugin - to install, download *Adjustable_Watershed.class* from https://github.com/imagej/imagej.github.io/blob/main/media/adjustable-watershed and place it in the Plugins folder of Fiji/ImageJ  
  
### Data processing and graphing
Up-to-date version of **R (including R Studio)** – recommended for automatic data processing - scripts provided here, in the *processing in R* folder  
**bash (unix terminal)** - optional - less powerful than R, but can be used with a single biological replicate; script provided here, in the *processing in bash* folder  
**Prism 8 or higher (GraphPad)** – optional – for semi-automatic data processing  
**Microsoft Excel/LibreOffice Calc** – optional – for manual data processing (not recommended)  

## Copyright
The codes and scripts are available under the CC BY-NC licence. The users are free to distribute, remix, adapt, and build upon the material in any medium or format for noncommercial purposes. Attribution to the creator is required.
