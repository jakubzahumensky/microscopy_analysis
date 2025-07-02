# Automated analysis of microscopy data - from images to numbers and plots
This repository contains custom **Fiji (ImageJ)** macros and **R scripts (markdown)** that we have developed for automatic analysis of microscopy images. The required data structure and use of the code is described in detail in: **Zahumensky J., Malinsky J. Live cell fluorescence microscopy—an end-to-end workflow for high-throughput image and data analysis**. *Biology Methods and Protocols*, Volume 9, Issue 1, 2024, bpae075, 
(doi: https://doi.org/10.1093/biomethods/bpae075).

For detailed description of the reported parameterssee the [Results table legend](/Fiji%20macros/results_table_legend.md).

The Results table can be processed using our custom [R script](https://github.com/jakubzahumensky/microscopy_analysis/tree/main/processing%20in%20R) developed previously. For detailed description of the parameters reported in the Results table see the [Results table legend](results_table_legend.md).

---

## Required software
### Segmentation of cells/objects:
[**Cellpose 2.0**](https://www.cellpose.org/) ([Stringer et al., 2021](https://www.nature.com/articles/s41592-020-01018-x)):
-   [Installation instructions](https://github.com/MouseLand/cellpose/blob/main/README.md)
-   requires [Python](https://www.python.org/downloads/) and [Anaconda](https://www.anaconda.com/download); installation instructions can be found on the [Cellpose Readme website](https://github.com/MouseLand/cellpose/blob/main/README.md)
  
### Segmentation verification and the actual data analysis
[**Fiji** (ImageJ 1.53t or higher)](https://imagej.net/software/fiji/downloads)
The macros require additional plugins/libraries that are not part of the general Fiji download:  
- *SCF-MPI-CBG* and *BIG-EPFL* - to install, navigate through Help → Update → Manage update sites, then tick checkboxes for BIG-EPFL and SCF MPI CBG. Click Apply and Close → Apply changes → OK; restart Fiji  
- *Watershed_* plugin - to install, download [here](http://bigwww.epfl.ch/sage/soft/watershed/) and place it in the plugins folder of Fiji/ImageJ  
- *Adjustable Watershed* plugin - to install, download *Adjustable_Watershed.class* [here](https://github.com/imagej/imagej.github.io/blob/main/media/adjustable-watershed) and place it in the Plugins folder of Fiji/ImageJ
  
### Data processing and graphing
- Up-to-date version of **R (including R Studio)** – *recommended* for automatic data processing - scripts provided [here](/processing%20in%20R)
- **bash (unix terminal)** - *optional* - less powerful than R, but can be used with a single biological replicate; script provided here, in the *processing in bash* folder  
- **Prism 8 or higher (GraphPad)** – *optional* – for semi-automatic data processing  
- **Microsoft Excel/LibreOffice Calc** – *optional* – for manual data processing (not recommended)  

---

## Citation

Jakub Zahumensky, Jan Malinsky — **Live cell fluorescence microscopy—an end-to-end workflow for high-throughput image and data analysis**\
*Biology Methods and Protocols*, Volume 9, Issue 1, 2024, bpae075\
https://doi.org/10.1093/biomethods/bpae075


## Copyright
The codes and scripts are available under the CC BY-NC licence. The users are free to distribute, remix, adapt, and build upon the material in any medium or format for noncommercial purposes. Attribution to the creator is required.  

## Non-Liability Disclaimer
The software is provided “as is”, without warranty of any kind, express or implied, including but not limited to the warranties of merchantability, fitness for a particular purpose and noninfringement. In no event shall the authors or copyright holders be liable for any claim, damages or other liability, whether in an action of contract, tort or otherwise, arising from, out of or in connection with the software or the use or other dealings in the software.
