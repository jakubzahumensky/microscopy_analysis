// *******************************************************************
// * title: "Quantification of cell parameters in microscopy images" *
// * author: Jakub Zahumensky; e-mail: jakub.zahumensky@iem.cas.cz   *
// * - Department of Functional Organisation of Biomembranes         *
// * - Institute of Experimental Medicine CAS                        *
// * - citation: doi: https://doi.org/10.1101/2024.03.28.587214)     *
// *******************************************************************
//
// SUMMARY:
//
// This macro takes raw microscopy images and ROIs defined elsewhere and then analyses each ROI separately.
// Multiple parameters for each ROI are analyzed and written into the Results table.
// These include: area (size), mean and intergal fluorescence intensity of the whole ROI, its circumference (i.e., plasma membrane if a ROI corresponds to the cell), its inside,
// number of high-intensity foci (microdomains) in the plasma membrane, etc.
//
// Additional plugins required:
// Adjustable_Watershed - https://imagej.net/plugins/adjustable-watershed/adjustable-watershed (donwload the .class file to the plugins folder)
// Interactive Watershed - add SCF-MPI-CBG update site
// StackReg (and possibly others) - add BIG-EPFL update site
// Graylevel watershed - download from http://bigwww.epfl.ch/sage/soft/watershed/ and put in the plugins folder of Fiji/ImageJ
//
// The macros were used for microscopy data analyses in the following publications:
// Zahumensky et al., 2020 - Microdomain Protein Nce102 Is a Local Sensor of Plasma Membrane Sphingolipid Balance (doi: 10.1128/spectrum.01961-22)
// Vesela et al., 2022 - Lsp1 partially substitutes for Pil1 function in eisosome assembly under stress conditions (doi: 10.1242/jcs.260554)
// Balazova et al., 2020 - Two Different Phospholipases C, Isc1 and Pgc1, Cooperate To Regulate Mitochondrial Function (doi: 10.1128/spectrum.02489-22)
//
// Abbreviations used:
// cyt - cytosol
// CV - coefficient of variance

// for testing, simply uncomment the "test = 1;" line (i.e., delete the "//")
// this changes some things:
// - batchMode does not start, so all intermediary images are shown
// - only a small amount of ROIs is analyzed

version = "15.0"; // not backward compatible with 8.x versions of ROI_prep!

test = 0;
//test = 1;
if (test == 0)
	setBatchMode(true);
default_subset = "";
default_directory = "";
//default_directory = "D:/Yeast/EXPERIMENTAL/microscopy/JZ-M-073-250218 - Pil1 vs TORC1 inhibition (RAP)/250218/";

// Definitions of initial variables used in the macro below.
var extension_list = newArray("czi", "oif", "lif", "tif", "vsi"); // only files with these extensions will be processed; if your filetype is not in the group, simply add it
extlist = ""; // the list is converted to a string so that it can be used in the Dialog window to inform user about what file formats will be used
for (i = 0; i < extension_list.length; i++) {
    extlist += extension_list[i];
    if (i < extension_list.length - 1) {
        extlist += ", ";
    }
}
image_types = newArray("transversal", "tangential"); // there are either tranversal (going through the middle) or tangential (showing the surface) microscopy images. Z-stack projections are a special case of the latter.
boolean = newArray("yes","no");
RoiSet_suffix = "-RoiSet.zip";

// initial values of variables that change within functions
var temp_files_count = 0;
var count = 0;
var counter = 1;
var proc_files_number = 0;
var proc_files = "";

var title = "";
var roiDir = "";
var fociDir = "";

var bit_depth = 0;
var pixelHeight = 0;
var pixelWidth = 0;
var image_area = 0;
var maxIndices = newArray();

var CHANNEL = newArray(1);
var ch = 1; // iterative variable for cycling through channels

var plasma_membrane_base_background = 0;
var plasma_membrane_length = 0;
var background_DUP_Gauss = 0;
var start_year = 0;
var start_month = 0;
var start_dayOfMonth = 0;
var start_hour = 0;
var start_minute = 0;
var start_second = 0;

cell_size_min = 5; // by default, cells with area smaller than 5 um^2 are excluded from the analysis. Can be changed in the dialog window below when analysis is run
Gauss_Sigma = 1; // smoothing radius for Gaussian blur (in pixels)
foci_prominence = 1.666; // patch prominence threshold (for transversal images) - set semi-empirically

// Display the "Quantify" dialog window, including a help message defined in the 'html0' variable. Multiple parameters need to be set by the user.
// Detailed explanation in the help message (and protocol)
html0 = "<html>"
	+"<b>Directory</b><br>"
	+"Specify the directory where you want <i>Fiji</i> to start looking for folders with images. The macro works <i>recursively</i>, i.e., it looks into all <i>sub</i>folders. "
	+"All folders with names <i>ending</i> with the word \"<i>data</i>\" are processed. All other folders are ignored.<br>"
	+"<br>"
	+"<b>Subset</b><br>"
	+"If used, only images with filenames containing specified <i>string</i> (i.e., group of characters and/or numbers) will be processed. "
	+"This option can be used to selectively process images of a specific strain, condition, etc. "
	+"Leave empty to process all images in specified directory (and its subdirectories).<br>"
	+"<br>"
	+"<b>Channel(s)</b><br>"
	+"Specify image channel(s) to be processed. Use comma(s) to specify multiple channels or a dash to specify a range.<br>"
	+"<br>"
	+"<b>Naming scheme</b><br>"
	+"Specify how your files are named (without extension). Results are reported in a comma-separated table, with the parameters specified here used as column headers. "
	+"The default \"<i>strain,medium,time,condition,frame</i>\" creates 5 columns, with titles \"strains\", \"medium\" etc. "
	+"Using a consistent naming scheme across your data enables automated downstream data processing.<br>"
	+"<br>"
	+"<b>Experiment code scheme</b><br>"
	+"Specify how your experiments are coded. The macro assumes a folder structure of <i>\".../experimental_code/biological_replicate_date/image_type/data/\"</i>. See protocol for details.<br>"
	+"<br>"
	+"<b>Image type</b><br>"
	+"Select if your images represent <i>transversal</i> (also called <i>equatorial</i>) or <i>tangential</i> sections of the cells.<br>"
	+"<br>"
	+"<b>Cell size from - to</b><br>"
	+"Specify lower (<i>min</i>) and upper (<i>max</i>) limit for cell area (in &micro;m<sup>2</sup>; as appears in the microscopy images). "
	+"Only cells within this range will be included in the analysis (this does not change the saved RoiSets). The default lower limit is set to 5 &micro;m<sup>2</sup>, which corresponds to a small bud of a haploid yeast. "
	+"<i>The user is advised to measure a handful of cells before adjusting these limits. If in doubt, set limits 0-Infinity and filter the results table.</i><br>"
	+"<br>"
	+"<b>Coefficient of variance (CV) threshold</b><br>"
	+"Cells whose intensity coefficient of variance (standard deviation/mean) is below the specified value will be excluded from the analysis. Can be used for automatic removal of dead cells, "
	+"but <i>a priori</i> knowledge about the system is required. Filtering by CV can be performed <i>ex post</i> by filtering the results table.<br>"
	+"<br>"
	+"<b>Quantify microdomains</b><br>"
	+"Select if you wish to quantify plasma membrane microdomains: number per cell image, density, mean intensity etc. The analysis run is much shorter when microdomains are not being analyzed.<br>"
	+"<br>"
	+"<b>Deconvolved</b><br>"
	+"Select if your images have been deconvolved. If used, no Gaussian smoothing is applied to images before quantification of foci in the plasma membrane. "
	+"In addition, prominence of 1.333 is used instead of the 1.666 used for confocal images. The measurements of intensities (cell, cytosol, plasma membrane) are not affected by this. "
	+"Note that the macro has been tested with a limited set of deconvolved images from a wide-field microscope (solely for the purposes of <i>Zahumensky et al., 2022</i>). "
	+"Proceed with caution and verify that the results make sense.<br>"
	+"</html>";
Dialog.create("Quantify");
	Dialog.addMessage("Note: Images with following extensions are processed: " + extlist +". \nIf your files have another extension, please add it to the 'extension_list' array in line 42.");
	Dialog.addDirectory("Directory:", default_directory);
	Dialog.addString("Subset (optional):", default_subset);
	Dialog.addString("Channel(s):", ch);
	Dialog.addString("Naming scheme:", "strain,medium,time,condition,frame", 33);
	Dialog.addString("Experiment code scheme:", "XY-M-000", 33);
	Dialog.addChoice("Image type:", image_types);
	Dialog.addNumber("Cell size from:", cell_size_min);
	Dialog.addToSameRow();
	Dialog.addNumber("to:","Infinity",0,6, fromCharCode(181) + "m^2");
	Dialog.addNumber("Coefficient of variance (CV) threshold", 0);
	Dialog.addChoice("Quantify microdomains:", boolean ,"yes");
	Dialog.addChoice("Deconvolved:", boolean ,"no");
	Dialog.addMessage("Click \"Help\" for more information on the parameters.");
	Dialog.addHelp(html0);
 Dialog.show();
	dir = replace(Dialog.getString(), "\\", "/");
	subset = Dialog.getString();
	channel = replace(Dialog.getString(), " ", "");
	naming_scheme = Dialog.getString();
	experiment_scheme = Dialog.getString();
	image_type = Dialog.getChoice();
	cell_size_min = Dialog.getNumber();
	cell_size_max = Dialog.getNumber();
	CV = Dialog.getNumber();
	microdomains = Dialog.getChoice();
	deconvolved = Dialog.getChoice();

// if the dir name does not end with a slash, add one (this can happen if the path is copy pasted into the dialog window)
if (!endsWith(dir, "/"))
	dir = dir + "/";
// if the analysis has been run from the actual data folder, move one level up (analysis cannot run from the data folder for some reason)
if (indexOf(File.getName(dir), "data") == 0)
	dir = File.getParent(dir) + "/";
dirMaster = dir; //directory into which Result summary is saved; it is the same dir as is used by the user as the starting point

// if images have been deconvolved, do not use smoothing and decrease the threshold for the identification of microdomains
if (deconvolved == "yes"){
	Gauss_Sigma = 0; // no smoothing is used
	foci_prominence = 1.333; // patch prominence can be set lower compared to regular confocal images
}

// Process the input channels (list, range) to get an array of individual channel numbers to be processed (functions defined below)
CHANNEL = sort_channels(channel);
continue_analysis = check_temporary(CHANNEL);

// count the number of images to be processed (used for the status window) - those that have an extension listed in the 'extension_list' array variable (line 43)
count_files(dir);

// the "code" :) multiple functions are used, see below
for (ii = 0; ii <= CHANNEL.length-1; ii++){
	ch = CHANNEL[ii];
	counter = 1;
	temp_file = "results-temporary_" + image_type + "_channel_"+ ch +".csv";
	no_ROI_files = "files_without_ROIs_" + image_type + "_channel_"+ ch +".tsv";
	processed_files = "processed_files_" + image_type + "_channel_"+ ch +".tsv";
	initialize(continue_analysis);
	process_folder(dir);
	channel_wrap_up();
}
final_wrap_up();
setBatchMode(false); // exit the batch mode to return ImageJ back to normal

//________________________________________________________definitions of functions________________________________________________________

// Definition of "processFolder" function:
// Makes a list of contents of specified folder (folders and files) and goes through it one by one.
// If it finds another directory, it enters it and makes a new list and does the same. In this way, it enters all subdirectories and looks for files.
// If a list item is an image of type specified in the 'extension_list', it runs process_file() on that image file.
function process_folder(dir){
	list = getFileList(dir);
	for (i = 0; i < list.length; i++){
		showProgress(i + 1, list.length);
		if (endsWith(list[i], "/")) // if the list item is a folder, go in and get a list of items
 			process_folder("" + dir + list[i]);
		else {	// if an item is not a folder, it is a file - get its name with the whole path
			file = dir + list[i];
			// process file if:
			// it is in the correct directory based on the image type
			// it is not in the list of files that have already been processed (for resumed analysis)
			// it belongs to the subset defined by the user
			if (endsWith(dir, image_type + "/data/") && indexOf(proc_files, file) < 0 && indexOf(file, subset) >= 0)
				if (check_ROIs(dir, list[i])){
					extIndex = lastIndexOf(file, ".");
					ext = substring(file, extIndex + 1);
					// process file if its extension corresponds to any of those stored in the "extension_list" variable
					if (array_contains(extension_list, ext)){
						// inform user about the progress of the analysis
						print("\\Clear");
						print("Processing:");
						print("channel: " + ch + "; user channel input: " + channel);
						print("file: " + counter + "/" + count-proc_files_number);
						remaining_time = estimate_remaining_time(ii);
						print("remaining time (estimate): " + remaining_time[0] + " hour(s), " + round(remaining_time[1]) + " minute(s)");
						print("(time started/resumed: " + start_year + "-" + String.pad(start_month + 1,2) + "-" + String.pad(start_dayOfMonth,2) + " " + String.pad(start_hour,2) + ":" + String.pad(start_minute,2) + ":" + String.pad(start_second,2)+")");
						// perform operations based on the selected image type
						if (matches(image_type, "transversal")) analyze_transversal(file);
							else analyze_tangential(file);
						counter++;
					}
				}
		}
	}
}

// count the files to be analysed and check that all have the channels that the user selected for analysis in the initial Dialog window
// the general structure of the function is the same as the process_folder() function above
function count_files(dir){
	list = getFileList(dir);
	for (i = 0; i < list.length; i++){
		if (endsWith(list[i], "/"))
			count_files("" + dir + list[i]);
		else {
			file = dir + list[i];
			if (endsWith(dir, image_type + "/data/") && indexOf(proc_files, file) < 0 && indexOf(file, subset) >= 0){
				count++;
				// check that the opened image actually has the channels to be analysed; CHANNEL is a sorted array, i.e., the highest value is the last one
				// the image needs to be opened for this
				open(dir + list[i]);
				getDimensions(width, height, channels, slices, frames);
				// if the number of channels is lower than the number in the last position in the CHANNEL array (i.e., the highers value), cansel macro run and inform user
				if (channels < CHANNEL[CHANNEL.length-1])
					exit("One or more images in the data set do not have one or more selected channels (" + channel + "). Check your data and restart analysis.");
				close();
			}
		}
	}
}

// helper function for checking if an array contains a specified string
function array_contains(array, value){
	for (i = 0; i < array.length; i++)
		if (array[i] == value)
			return true;
	return false;
}

// Create an array containing the selected channels to be processed
// The channel selection in the Dialog window is read as a string and can be an individual number, a comma-separated list, or a range (with a dash)
// The last two options need to be handled separately
function sort_channels(channel){
	if (channel <= 0)
		exit("Selected channel (" + channel + ") does not exit.");
	// if a range is defined, use the lower number as the beginning and the higher as end value; create an array containing these and all integer numbers between them
	if (indexOf(channel, "-") >= 0){
		X = "--";
		channel_temp = split(channel,"--");
		// sort the array in an ascending manner
		channel_temp = Array.sort(channel_temp);
		j = 0;
		for (i = channel_temp[0]; i <= channel_temp[1]; i++){
			CHANNEL[j] = i;
			j++;
		}
	// if a list of channels is defined, simply split the values into an array; any spaces are removed immediately after the input is read from the initial dialog window
	} else
		CHANNEL = split(channel,",,");
	return CHANNEL;
}

// Check for the existence of temporary files, which are kept if an analysis is interrupted; this allows the analysis to be resumed
// If at least one temporary file is found, user is notified and asked whether to continue the analysis or start from the beginning (the latter overwrites the previous temporary results)
function check_temporary(CHANNEL){
	for (ii = 0; ii <= CHANNEL.length - 1; ii++){
		ch = CHANNEL[ii];
		temp_file = "results-temporary_" + image_type + "_channel_"+ ch +".csv";
		if (array_contains(getFileList(dirMaster), temp_file))
			temp_files_count++;
	}
	if (temp_files_count > 0)
		continue_analysis = getBoolean("Incomplete analysis dectected.", "Continue previous analysis", "Start fresh");
		return continue_analysis;
}

// Check that the image to be analyzed has defined ROIs. If not, skip it and write its name into a list.
// If the list is non-empty at the end of the analysis run, the user is informed that not all files were processed due to non-defined ROIs.
// The analysis can be re-run (resumed) to analyze these images once the ROIs are prepared.
// In such a case, the data from these images is added to the results from the already analyzed ones, into the same file.
function check_ROIs(dir, string){
	title = substring(string, 0, lastIndexOf(string, "."));
	core_title = clean_title(title);
	roiDir = File.getParent(dir)+"/"+replace(File.getName(dir), "data", "ROIs")+"/";
	if (File.exists(roiDir + core_title + RoiSet_suffix)){
		return true;
	} else {
		print("[" + no_ROI_files + "]", file + "\n");
		selectWindow(no_ROI_files);
		saveAs("Text", dirMaster + no_ROI_files);
		return false;
	}
}

// Preparatory operations that are required for each image:
// get the path to ROIs, extract basic parameters of the image: name, bitDepth, dimensions, pixel size, image area
function prepare(file){
	open(file);
	rename(list[i]);
	title = File.nameWithoutExtension;
	core_title = clean_title(title);
	bit_depth = bitDepth();
	getPixelSize(unit, pixelWidth, pixelHeight);
	Stack.setChannel(ch); // switch to the channel selected by the user
	// Clear the ROI manager and open the ROIs corresponding to the current image.
	// Remove all channel-related information about the ROIs, which enables the same ROIs to be used with all channels.
	// !!! This will create issues if one channels has the whole cells and another nuclei, for example. !!!
	// If this is the case, the "Remove channel Info" will have to be removed. Also adjust the ROI_check macro to remove this (around line 510).
	roiDir = File.getParent(dir) + "/" + replace(File.getName(dir), "data", "ROIs") + "/";
	roiManager("reset");
	roiManager("Open", roiDir + core_title + RoiSet_suffix);
	roiManager("Remove Channel Info");
	// There are currently multiple ways how the raw images are analysed for the number of high-intensity foci in the plasma membrane.
	// Each of these requires a different preparation. The raw image is duplicated (and renamed by the same command) and processed.
	// These processed images are used solely for the purpose of counting of the microdomains. All intensity readings are made from the raw images.
	// This first option is used for both transversal and tangential images.
	selectWindow(list[i]);
		run("Duplicate...", "title=DUP_CLAHE channels="+ch);
		run("Normalize Local Contrast", "block_radius_x=5 block_radius_y=5 standard_deviations=10 center stretch");
		run("Enhance Local Contrast (CLAHE)", "blocksize=8 histogram=64 maximum=3 mask=*None*");
		run("Unsharp Mask...", "radius=1 mask=0.6");
		run("Gaussian Blur...", "sigma=Gauss_Sigma");
	// The following are only prepared for transversal images
	// This is the reason why the analysis of transversal images is approx. an order of magnitute slower than that of tangential images
	if (matches(image_type, "transversal") && microdomains == "yes"){
		// Basic Gauss smoothing
		selectWindow(list[i]);
			run("Duplicate...", "title=DUP_Gauss channels=" + ch);
			run("Gaussian Blur...", "sigma=Gauss_Sigma");
		// Mean smoothing
		selectWindow(list[i]);
			run("Duplicate...", "title=DUP_mean channels=" + ch);
			run("Convolve...", "text1=[1 1 1\n1 1 1\n1 1 1\n] normalize");
		// Mean filtering combined with a "Dotfind" filter developed by Jan Malinsky a long time ago
		// this filetering creates negative values in some pixels - all negative pixels are converted to zero-intensity pixels
		selectWindow(list[i]);
			run("Duplicate...", "title=DUP_dotfind channels=" + ch);
			run("Convolve...", "text1=[1 1 1\n1 1 1\n1 1 1\n] normalize");
			run("Convolve...", "text1=[-1 -1 -1 -1 -1\n-1 0 0 0 -1\n-1 0 16 0 -1\n-1 0 0 0 -1\n-1 -1 -1 -1 -1\n]");
			run("Subtract Background...", "rolling=5");
			changeValues("-Infinity", -1, 0);
		watershed_segmentation(core_title);
	}
}

// To get an estimate of the image background, the background is subtracted in the original image using brute force (rolling ball approach).
// The result is then subtracted from the original image, creating an image of the background.
// The mean intensity of this image is then used as background intensity estimate.
function measure_background(image_title){
	selectWindow(image_title);
	getDimensions(width, height, channels, slices, frames);
	run("Duplicate...", "duplicate channels=" + ch);
	run("Select None");
	run("Clear Results");
	run("Measure");
	// If offset is set correctly during image acquisition, zero pixel intensity usually originates when multichannel images are aligned.
	// In this case, they need to be cropped before the background estimation.
	MIN = getResult("Min", 0);
		if (MIN == 0) run("Auto Crop (guess background color)");
	rename("DUP-CROP");
	run("Duplicate...", "duplicate");
	rename("DUP-CROP-background");
	// Brute-force background subtraction (by using the "rolling ball" approach), the width of the whole image is used as the diameter of the ball.
	run("Subtract Background...", "rolling=" + width + " stack");
	imageCalculator("Difference create stack", "DUP-CROP", "DUP-CROP-background");
	run("Clear Results");
	run("Measure");
	MEAN = getResult("Mean", 0);
	selectWindow("DUP-CROP");
	setThreshold(0, MEAN);
	run("Create Selection");
	run("Measure");
	run("Select None");
	// the mean intensity is measured as the background estimate for the raw image and returned by the function
	background_image = getResult("Mean", 1);
	close("DUP-CROP-background");
	close("DUP-CROP");
	close("Result of DUP-CROP");
	return background_image;
}

// analyze transversal images
function analyze_transversal(file){
	// perform the preparatory steps and measure background (functions above)
	prepare(file); // bit-depth and pixel size of the image are read, ROI-Set is opened, CLAHE-processed image is made
	background = measure_background(list[i]);
	background_DUP_Gauss = measure_background("DUP_Gauss");
	// quantification - open ROIs prepared with ROI_prep.ijm macro (or any other means, as long as they are stored in the "ROIs" folder) and cycle through them one by one
	numROIs = roiManager("count"); // number of ROIs in the manager
	init = 0; // first ROI
	// a shortened loop that can be used for testing; activated in the beginning of the script by assigning: test = 1; only last 4 ROIs are analyzed	
	if (test == 1)
		init = numROIs - 4;
	// for each cell (ROI) measure: area, integrated_intensity, mean_intensity, intensity_SD (standard deviation of the mean), intensity_CV (coefficient of variance)
	// all reported intensities are corrected for background
	for(j = init; j < numROIs; j++){
		// measure cell parameters from raw image:
		// [0] - area, [1] - integrated_intensity_background, [2] - mean_intensity_background, [3] - SD, [4] - CV, [5] - major axis, [6] - minor axis, [7] - eccentricity
		// 0.166 makes the ROI slightly bigger to include the whole plasma membrane; the enlarged ROI is used to make a ROI mask below
		cell = measure_ROI(list[i], j, 0.166);
		// only analyse cells that fall into the cell size range and CV specified by the user when the macro is run
		// cell[0] corresponds to cell area; cell[4] to intensity CV (see above)
		if (cell[0] > cell_size_min && cell[0] < cell_size_max && cell[4] > CV){
			// preparation for plasma membrane segmentation
			run("Create Mask"); // creates a mask of the entire cell
			rename("Mask-cell");
			// measure cytosol characteristics and return them in an array: area, integrated_intensity_background, mean_intensity_background, SD, CV
			// -0.166 makes the ROI smaller to exclude the plasma membrane (ROI circumference)
			// the shrunk ROI is used to make the cytosol mask
			cytosol = measure_ROI(list[i], j, -0.166);
			run("Create Mask"); // creates a cytosol mask
			rename("Mask-cytosol");
			// plasma membrane segmentation
			imageCalculator("Subtract create", "Mask-cell","Mask-cytosol");
			selectWindow("Result of Mask-cell");
			run("Create Selection"); // selection of the plasma membrane from the computed mask
			selectWindow(list[i]);
			run("Restore Selection"); // transfer the selection to the raw microscopy image (i.e., no smoothing or any other processing)
			// measures plasma membrane characteristics and returns them in an array: area, integrated_intensity_background, mean_intensity_background, SD, CV
			// the measure_ROI(window, ROI, buff) function above also calls the measure_area_selection() function, but first makes a selection of a specified ROI and makes it bigger/smaller
			// the measure_area_selection() function measures whatever selection is currently active
			plasma_membrane = measure_area_selection();
			plasma_membrane_DIV_cytosol = plasma_membrane[2]/cytosol[2]; // ratio of MEAN fluorescence intensities in the plasma mebrane and in the cytosol
			cytosol_DIV_cell_integrated = cytosol[1]/cell[1]; // ratio of integrated fluorescence intensities in the cytosol and the whole cell (ROI)
			plasma_membrane_DIV_cell_integrated = plasma_membrane[1]/cell[1]; // ratio of integrated fluorescence intensities in the plasma membrane and the whole cell (ROI)
			// only calculate the following parameters if "yes" was selected for "quantify microdomains" in the inital dialog window
			// this saves time if the experimenter is not interested in plasma membrane microdomains
			if (microdomains == "yes"){
				// as descrived above, high-intensity foci in the plasma membrane (ROI circumference) are analyzed in multiple ways, or rather the images are processed by multiple ways before analysis
				// here, each of the image is loaded and analyzed using the count_foci_from_intensity_profile(window_title,relative_outlier_intensity_threshold) function
				// foci quantified from intensity profiles
				count_foci_from_intensity_profile_Gauss = count_foci_from_intensity_profile("DUP_Gauss","Infinity");
				// calculate the base of the plasma membrane, i.e., the mean intensity of the valleys between fluorescence peaks in the intensity profile
				base_of_plasma_membrane = plasma_membrane_base_background;
				count_foci_from_intensity_profile_CLAHE = count_foci_from_intensity_profile("DUP_CLAHE","Infinity");
				count_foci_from_intensity_profile_dotfind = count_foci_from_intensity_profile("DUP_dotfind","Infinity");
				// foci quantified from thresholding - the pre-processed images are thresholded to make a binary image
				// the foci (high-intensity foci) are then counted
				count_foci_from_thresholding_Gauss = count_foci_from_thresholding("DUP_Gauss");
				count_foci_from_thresholding_CLAHE = count_foci_from_thresholding("DUP_CLAHE");
				count_foci_from_thresholding_dotfind = count_foci_from_thresholding("DUP_dotfind");
				// separate analysis using the "WS_foci" image created by the "Watershed segmentation" plugin
				watershed_foci = count_foci_from_watershed_segmentation();
				// calculation of additional interesting parameters to be reported
				protein_fraction_in_foci = (1-base_of_plasma_membrane/plasma_membrane[2])*100; // calculates how much of the fluorescence signal is in the high-intensity foci (microdomains)
			}

			// get the experimental code (grandparent) and biological replicate date (parent)
			parents = find_parents();
			// write analysis results for the current ROI into the temporary text file - this is converted into the final Results table at the end of the analysis run
			cell_res = parents[0] +","+ parents[1] // [0] - experiment code, [1] - biological replicate date
				+","+ replace(title," ","_") +","+ background +","+ (j+1) // image title, background intensity and current ROI number
				// in the following three lines: [0] - area, [1] - integrated_intensity, [2] - mean_intensity, [3] - SD, [4] - CV
				+","+ cell[0] +","+ cell[1] +","+ cell[2] +","+ cell[3] +","+ cell[4] +","+ cell[5] +","+ cell[6] +","+ cell[7] // [5] - major axis, [6] - minor axis, [7] - eccentricity
				+","+ cytosol[0] +","+ cytosol[1] +","+ cytosol[2] +","+ cytosol[3] +","+ cytosol[4]
				+","+ plasma_membrane[0] +","+ plasma_membrane[1] +","+ plasma_membrane[2] +","+ plasma_membrane[3] +","+ plasma_membrane[4]
				+","+ plasma_membrane_DIV_cytosol +","+ plasma_membrane_DIV_cell_integrated +","+ cytosol_DIV_cell_integrated;
				// only print out the following parameters if "yes" was selected for "quantify microdomains" in the inital dialog window
			if (microdomains == "yes")
				cell_res = cell_res
				+","+ count_foci_from_intensity_profile_Gauss[0] +","+ count_foci_from_intensity_profile_Gauss[1] +","+ count_foci_from_intensity_profile_Gauss[2] +","+ base_of_plasma_membrane +","+ count_foci_from_intensity_profile_Gauss[3] // foci, foci_density, foci_intensity, plasma membrane base, foci_prominence
				+","+ count_foci_from_intensity_profile_Gauss[4] //foci_outliers at the end
				// in the following: [0] - foci; [1] - foci_density
				+","+ count_foci_from_intensity_profile_CLAHE[0] +","+ count_foci_from_intensity_profile_CLAHE[1]
				+","+ count_foci_from_intensity_profile_dotfind[0] +","+ count_foci_from_intensity_profile_dotfind[1]
				+","+ count_foci_from_thresholding_Gauss[0] +","+ count_foci_from_thresholding_Gauss[1]
				+","+ count_foci_from_thresholding_CLAHE[0] +","+ count_foci_from_thresholding_CLAHE[1]
				+","+ count_foci_from_thresholding_dotfind[0] +","+ count_foci_from_thresholding_dotfind[1]
				+","+ watershed_foci[0] +","+ watershed_foci[1]
				+","+ protein_fraction_in_foci;
			cell_res = cell_res + "\n";
			print("[" + temp_file + "]", cell_res);

			// close all temporary images and results tables
			close("Mask-cell");
			close("Mask-cytosol");
			close("Mask-cyt-outer");
			close("Mask-cyt-inner");
			close("Result of Mask-cell");
			close("Result of Mask-cyt-outer");
		}
	}
	// close all images and save results for the current image
	// results are saved after each image is done being analyzed, which allows the analysis to be resumed
	close("*");
	save_temp();
}

// analyze transversal images
function analyze_tangential(file){
	prepare(file); // bit-depth and pixel size of the image are read, ROI-Set is opened, CLAHE-processed image is made
	background = measure_background(list[i]);
	numROIs = roiManager("count"); // number of ROIs in the manager
	init = 0; // first ROI
	// a shortened loop that can be used for testing; activated in the beginning of the script by assigning: test = 1; only last 4 ROIs are analyzed
	if (test == 1)
		init = numROIs - 4;
	// for each cell (ROI) measure (all reported intensities are corrected for background):
	// - area, intensity (mean + integrated), SD and CV of mean intensity (same as for transversal images) 
	// - total number of microdomains (by two different approaches), their surface density, shape, intensity and surface area taken up by them
	for(j = init; j < numROIs; j++){
		// measure cell parameters from raw image:
		// explanations: [0] - area, [1] - integrated_intensity_background, [2] - mean_intensity_background, [3] - SD, [4] - CV, [5] - major axis, [6] - minor axis, [7] - eccentricity
		cell = measure_ROI(list[i], j, 0);
		if (cell[0] > cell_size_min && cell[0] < cell_size_max){ // continue if the cell size falls between the lower and upper limit specified by the user when the macro is run
			// analyze patch density from the image with local contrast adjustment, using the "Find Maxima..." plugin
			select_window("DUP_CLAHE");
			select_ROI(j);
//			Delta = axis_major/2*(1-sqrt(2/3)); // the ROI is made smaller by this amount in the following step to exclude background areas from the analysis
//			run("Enlarge...", "enlarge=-" + Delta);
			cell_background_CLAHE = measure_cell_background(); // [0] - mean, [1] - SD of the fl. intensity of area in-betweem foci; serves as baseline for maxima identification and thresholding
			foci_prominence = cell_background_CLAHE[0]*0.1; // [0] - mean
			number_of_foci = 0; // initial value
			run("Clear Results");
			run("Find Maxima...", "prominence=foci_prominence exclude output=Count");
			if (cell[4] > CV_threshold) // [4] - cell intensity CV; if the CV is not greater than CV_threshold (set by the user in the initial Dialog window), the cells are deemed to have no microdomains
				number_of_foci = getResult("Count", 0);
			foci_density_find_maxima = number_of_foci/cell[0];
			// foci quantification using thresholding and the "Analyze particles..." plugin
			// set initial values for multiple parameters; witten into the Results table if no foci are detected
			foci_area_fraction = 0;
			foci_density_analyze_particles = 0;
			foci_size = NaN;
			foci_size_SD = NaN;
			foci_length = NaN;
			foci_length_SD = NaN;
			foci_width = NaN;
			foci_width_SD = NaN;
			// if there is at least one microdomain identified by the "Find Maxima..." plugin
			// make mask from current ROI, setting the threshold based on the intensity of signal in between foci
			if (number_of_foci > 0){
				// duplicate current ROI (i.e., cell; actually a rectangle circumscribed to it) from the RAW and CLAHE-processed image with new names: DUP_cell and DUP_cell_CLAHE, respectively
				select_window(list[i]);
				select_ROI(j);
//				run("Enlarge...", "enlarge=-"+Delta);
				run("Duplicate...", "title=DUP_cell duplicate channels=" + ch);
				select_window("DUP_CLAHE");
				select_ROI(j);
//				run("Enlarge...", "enlarge=-"+Delta);
				run("Duplicate...", "title=DUP_cell_CLAHE duplicate channels=" + ch);
				run("Select None");
				// threshold the CLAHE-proceesed cell image to make a mask of the microdomains (foci)
				// this mask is then applied to the raw image to measure foci intensities
				setThreshold(cell_background_CLAHE[0] + 3*cell_background_CLAHE[1], pow(2,bit_depth) - 1); // lower limit: mean + 3*SD; upper limit: highest image intensity ("Infinity" would probably work as well)
				run("Create Mask");
				rename("mask");
				run("Adjustable Watershed", "tolerance=0.01"); // separate aggregate objects
				run("Clear Results");
				run("Measure");
				// measure mean fl. intensity of the mask image; if there are no foci (microdomains), the mean I = 0
				// the subsequent commands are relevant ony if there are foci
				mask_mean = getResult("Mean", 0);
				if (mask_mean > 0){
					// remove the part of the mask that is outside of the cell
					run("Restore Selection"); // the "selection" here refers to the cell ROI
					setBackgroundColor(0, 0, 0);
					run("Clear Outside");
					setBackgroundColor(255, 255, 255);
					run("Enlarge...", "enlarge=1 pixel");
					run("Translate...", "x=-1 y=-1 interpolation=None"); // move the mask so that only foci touching the upper and left edge are excluded; without the translation, all foci touching edges would be excluded from the analysis
					run("Clear Results");
					run("Analyze Particles...", "size=" + 5*pow(pixelHeight,2) + "-" + 120*pow(pixelHeight,2) + " show=Nothing display exclude clear stack"); // only particles that take at least 5 pixels (smallest possible cross) are included
					number_of_foci = nResults; 
					foci_density_analyze_particles = number_of_foci/cell[0];
					// get info if there is a single focus
					if (number_of_foci == 1){
						foci_size = getResult("Area", 0);
						foci_length = getResult("Major", 0);
						foci_width = getResult("Minor", 0);
					}
					// summarize only if there is more than one focus (it does not work when there is a single result)
					if (number_of_foci > 1){
						run("Summarize");
						foci_size = getResult("Area", number_of_foci);
						foci_size_SD = getResult("Area", number_of_foci+1);
						foci_length = getResult("Major", number_of_foci);
						foci_length_SD = getResult("Major", number_of_foci+1);
						foci_width = getResult("Minor", number_of_foci);
						foci_width_SD = getResult("Minor", number_of_foci+1);
					}
					// move the binary mask "back", make selection from it and apply it to the duplicated cell from the raw image to measure area and intensity
					selectWindow("mask");
					run("Translate...", "x=1 y=1 interpolation=None");
					run("Create Selection");
					selectWindow("DUP_cell");
					run("Restore Selection");
					foci = measure_area_selection(); // [0] - area, [1] - integrated_intensity_background, [2] - mean_intensity_background, [3] - SD, [4] - CV
					foci_area_fraction = 100*foci[0]/cell[0];
					protein_in_foci = 100*foci[1]/cell[1]; // ratio of integrated intensities: foci/cell
				}
				// close temporary windows
				close("mask");
				close("DUP_cell");
				close("DUP_cell_CLAHE");
			}
			// print measured values into a text window - this ultimately becomes the Results table when the last image is analyzed
			parents = find_parents(); // [0] - experiment code, [1] - biological replicate date
			cell_res = parents[0] +","+ parents[1]
				+","+ replace(title," ","_") +","+ background +","+ j+1
				+","+ cell[0] +","+ cell[1] +","+ cell[2] +","+ cell[3] +","+ cell[4] // [0] - area, [1] - integrated_intensity, [2] - mean_intensity, [3] - SD, [4] - CV
				+","+ cell[5] +","+ cell[6] +","+ cell[7] // [5] - major axis, [6] - minor axis, [7] - eccentricity
				+","+ foci_density_find_maxima +","+ foci_density_analyze_particles +","+ foci_area_fraction
				+","+ foci_length +","+ foci_length_SD +","+ foci_width +","+ foci_width_SD +","+ foci_size +","+ foci_size_SD
				+","+ foci[2] +","+ foci[3] // [2] - mean intensity; [3] - SD
				+","+ protein_in_foci; // ratio of integrated intensities: foci/cell
			print("[" + temp_file + "]", cell_res + "\n");
		}
	}
	close("*");
	save_temp();
}

// Function to extract the biological replicate date and experiment accession code
// For this to work properly, correct data structure is required:
// folder with a name that starts with the accession code, containing subfolders, each starting with the date in the YYMMDD format
// each biological replicate folder contains the "transversal" and/or "tangential" folders
// each of these contains at least the "data" and "ROIs" folder
function find_parents(){
	parent = File.getParent(File.getParent(dir)); // bio replicate date (two levels up from the "data" folder)
	grandparent = File.getParent(parent); // one level above the bio replicate folder; name starts with the experiment code (accession number)
	// replace spaces with underscores in both to prevent possible issues in automatic R processing of the Results table
	BR_date = replace(File.getName(parent)," ","_");
	exp_code = replace(File.getName(grandparent)," ","_");
	// date is expected in YYMMDD (or another 6-digit) format; if it is shorter, the whole name is used; analogous with the "experimental code"
	if (lengthOf(BR_date) > 6)
		BR_date = substring(BR_date, 0, 6);
	if (lengthOf(exp_code) > lengthOf(experiment_scheme))
		exp_code = substring(exp_code, 0, lengthOf(experiment_scheme));
	return newArray(exp_code, BR_date);
}

// prepare Fiji and find out if previous analysis run was concluded
function initialize(continue_analysis){
	// close all open image windows, including specific text windows that might be open
	// create new text windows to write temporary results, names of processed files and files without defined ROIs
	close("*");
	if(isOpen("Log"))
		close("Log");
	if(isOpen(temp_file))
		print("[" + temp_file + "]","\\Close");
	if(isOpen(processed_files))
		print("[" + processed_files + "]","\\Close");
	if(isOpen(no_ROI_files))
		print("[" + no_ROI_files + "]","\\Close");
	run("Text Window...", "name=["+temp_file+"] width=180 height=40");
	setLocation(0,0);
	run("Text Window...", "name=["+processed_files+"] width=180 height=20");
	setLocation(0,screenHeight/2);
	run("Text Window...", "name=["+no_ROI_files+"] width=90 height=20");
	setLocation(screenWidth*2/3,screenHeight/2);
	setBackgroundColor(255, 255, 255); // this is important for proper work with masks - a Fiji update might ruin this (it did once before already)
	// define what things are to be measured; has effect on all measurements in the macro
	run("Set Measurements...", "area mean standard modal min integrated centroid fit redirect=None decimal=5");
	getDateAndTime(start_year, start_month, start_dayOfWeek, start_dayOfMonth, start_hour, start_minute, start_second, start_msec);
	// if an analysis is resumed from a previously interrupted one, load the temporary result file and the files listing processed files and files without defined ROIs
	if (continue_analysis == 1 && File.exists(dirMaster + temp_file)){ // if File.exists() - when the analysis is continued and multiple channels are selected, some may not have temporary files
		if (File.exists(dirMaster + no_ROI_files)){
			File.delete(dirMaster + no_ROI_files);
			close("Log");
		}
		print("[" + temp_file + "]", File.openAsString(dirMaster + temp_file));
		proc_files = File.openAsString(dirMaster + processed_files);
		print("[" + processed_files + "]", proc_files);
		proc_files_array = split(proc_files,"\n");
		proc_files_number = proc_files_array.length;
	} else
		print_header();
}

// print the header of the Results output file
// the first couple of lines give a general overview of the analysis run
function print_header(){
	print("[" + temp_file + "]","# Basic macro run statistics:"+"\n");
	print("[" + temp_file + "]","# Date and time: " + start_year + "-" + String.pad(start_month + 1,2) + "-" + String.pad(start_dayOfMonth,2) + " " + String.pad(start_hour,2) + ":" + String.pad(start_minute,2) + ":" + String.pad(start_second,2)+"\n");
	print("[" + temp_file + "]","# Macro version: " + version+"\n");
	print("[" + temp_file + "]","# Channel: " + ch+"\n");
	print("[" + temp_file + "]","# Cell (ROI) size interval: " + cell_size_min + "-" + cell_size_max +" um^2"+"\n");
	print("[" + temp_file + "]","# Coefficient of variance threshold: " + CV+"\n");
	if (matches(image_type, "transversal")){
		print("[" + temp_file + "]","# Smoothing radius (Gaussian blur): " + Gauss_Sigma+"\n");
		print("[" + temp_file + "]","# Patch prominence: " + foci_prominence+"\n");
	}
	print("[" + temp_file + "]","#"+"\n"); // empty line that is ignored in bash and R
	// the column names coincide up to the cell shape eccentricity, then differs, since different parameters are being analyzed transversal and tangential images
	column_names = "exp_code,BR_date,"
		+ naming_scheme + ",mean_background,cell_no"
		+ ",cell_area,cell_I.integrated,cell_I.mean,cell_I.SD,cell_I.CV"
		+ ",axis_major,axis_minor,eccentricity";
	// the following parameters are quantified only in the transversal images
	if (matches(image_type, "transversal")){
		column_names = column_names
			+ ",cytosol_area,cytosol_I.integrated,cytosol_I.mean,cytosol_I.SD,cytosol_I.CV"
			+ ",plasma_membrane_area,plasma_membrane_I.integrated,plasma_membrane_I.mean,plasma_membrane_I.SD,plasma_membrane_I.CV"
			+ ",plasma_membrane_I.div.cyt_I(mean),plasma_membrane_I.div.cell_I(integrated),cyt_I.div.cell_I(integrated)";
		// the following parameters are quantified only in the transversal images and only if the user ticks that they wish to quantify microdomains
		if (microdomains == "yes")
			column_names = column_names
				+ ",foci_number,foci_density,foci_I.mean,plasma_membrane_base,foci_prominence,foci_outliers"
				+ ",foci_profile_CLAHE,foci_density_profile_CLAHE"
				+ ",foci_profile_dotfind,foci_density_profile_dotfind"
				+ ",foci_threshold_Gauss,foci_density_threshold_Gauss"
				+ ",foci_threshold_CLAHE,foci_density_threshold_CLAHE"
				+ ",foci_threshold_dotfind,foci_density_threshold_dotfind"
				+ ",foci_from_watershed,foci_density_from_watershed"
				+ ",protein_in_microdomains[%]";
	// the following parameters are quantified only in the tangential images
	// in this case, microdomains are always quantified
	} else
		column_names = column_names
			+ ",foci_density(find_maxima),foci_density(analyze_particles),area_fraction(foci_vs_ROI)"
			+ ",length[um],length_SD[um],width[um],width_SD[um],size[um^2],size_SD[um^2]"
			+ ",mean_foci_intensity,mean_foci_intensity_SD"
			+ ",protein_in_microdomains[%]";
	print("[" + temp_file + "]",column_names + "\n");
	setLocation(0,0);
}

// estimate how much time is required to finish the current analysis run
// the estimate is based on the average time spent analysing a single image, multiplied by the number of images left to be analysed
// should get more accurate as more images are analysed
// since the number of ROIs can vary significantly from image to image, the estimate is very rough and should not be taken at face value
function estimate_remaining_time(ii){
	getDateAndTime(year, month, dayOfWeek, dayOfMonth, current_hour, current_minute, current_second, current_msec);
	elapsed_hours = current_hour-start_hour;
	if (elapsed_hours < 0)
		elapsed_hours = elapsed_hours + 24;
	elapsed_minutes = current_minute-start_minute;
	if (elapsed_minutes < 0)
		elapsed_minutes = elapsed_minutes + 60;
	elapsed_seconds = current_second-start_second;
	if (elapsed_seconds < 0)
		elapsed_seconds = elapsed_seconds + 60;
	elapsed_time_in_minutes = 60*elapsed_hours + elapsed_minutes + elapsed_seconds/60;
	time_per_file = elapsed_time_in_minutes/counter;
	files_left_current_channel = (count - proc_files_number - counter);
	files_left_other_channels = (CHANNEL.length - ii - 1)*count;
	files_left = files_left_current_channel + files_left_other_channels;
	time_to_finish = files_left*time_per_file;
	time_to_finish_hours = floor(time_to_finish/60); // floor() - rounds the number down
	time_to_finish_minutes = time_to_finish - 60*floor(time_to_finish/60); // the remainder after the assigning of whole hours (complete 60-min periods) to the time_to_finish_hours variable
	return newArray(time_to_finish_hours, time_to_finish_minutes);
}

// save the Results from already analyzed images as a temporary file
// this file is converted at the end of the analysis to the final Results file
// this file is also used for resuming an interrupted analysis
function save_temp(){
	selectWindow(temp_file);
	saveAs("Text", dirMaster + temp_file);
	setLocation(0, 0);
	print("[" + processed_files + "]", file + "\n");
	selectWindow(processed_files);
	saveAs("Text", dirMaster + processed_files);
}

// save the output in csv format and clean the Fiji (ImageJ) space to make it ready for the quantification of the next channel (if applicable)
function channel_wrap_up(){
	getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
	res = "Results of " + image_type + " image analysis, channel " + ch + " (" + year + "-" + String.pad(month + 1,2) + "-" + String.pad(dayOfMonth,2) + "," + String.pad(hour,2) + "-" + String.pad(minute,2) + "-" + String.pad(second,2) + ").csv";
	selectWindow(temp_file);
	saveAs("Text", dirMaster + res);
	close("Results");
	close("ROI manager");
	print("[" + processed_files + "]","\\Close");
	print("[" + no_ROI_files + "]","\\Close");
	print("[" + res + "]","\\Close");
	if (File.length(dirMaster + no_ROI_files) == 0){
		File.delete(dirMaster + temp_file);
	}
	close("Log");
}

// after saving the Results, check how many images have not been analysed due to missing ROIs and inform the user
function final_wrap_up(){
	setBackgroundColor(0, 0, 0); // reverts the background to default ImageJ settings
	processed_files_count = 0;
	no_ROI_files_count = 0;
	for (ii = 0; ii <= CHANNEL.length-1; ii++){
		ch = CHANNEL[ii];
		processed_files = "processed_files_" + image_type + "_channel_"+ ch +".tsv";
		no_ROI_files = "files_without_ROIs_" + image_type + "_channel_"+ ch +".tsv";
		if (File.length(dirMaster + processed_files) > 0)
			processed_files_count++;
		if (File.length(dirMaster + no_ROI_files) > 0)
			no_ROI_files_count++;
	}
	if (processed_files_count == 0)
		waitForUser("This is curious...", "No images were analysed. Check if you had prepared ROIs before you ran the analysis. Also check that the file format of your images is included in the 'extension_list' array at line 42 of the macro code (add the extension if it is not included).");
	else
		if (File.length(dirMaster + no_ROI_files) > 0)
			waitForUser("Finito!", "Analysis finished successfully, but one or more images were not processed due to missing ROIs.\nThese are listed in the \"files_without_ROIs\" file.");
		else
			waitForUser("Finito!", "Analysis finished successfully."); // informs the user that the analysis has finished successfully
}

// measure the fluorescence intensity in the plasma membrane in the areas in-between microdomains
function measure_plasma_membrane_base(ROI_no){
	select_ROI(ROI_no);
	run("Area to Line");
	profile = getProfile(); // measure intensity profile along the line, store in an array
	Array.getStatistics(profile, profile_min, profile_max, profile_mean, profile_stdDev);
	minIndices = Array.findMinima(profile, 1.5*profile_stdDev, 1);
	minima = newArray(0);
	for (jj = 0; jj < minIndices.length; jj++){
		x = minIndices[jj];
		minima[jj] = profile[x];
	}
	Array.getStatistics(minima, minima_min, minima_max, minima_mean, minima_stdDev);
	if (minima.length == 0)
		minima_mean = (profile_mean+profile_min)/2;
	return newArray(minima_mean, minima_stdDev);
}

// measure parameters in specified ROI (ROI_no) within a specified image (window title), making the ROI bigger/smaller by a defined value (buff)
function measure_ROI(window_title, ROI_no, buff){
	select_window(window_title);
	select_ROI(ROI_no);
	run("Enlarge...", "enlarge=" + buff);
	measurements = measure_area_selection();
	return measurements;
}

// measure parameters of the selected area:
// area, intensity (mean + integrated), standard deviation, coefficient of variance; fit with an ellipse and measure both axes and its eccentricity
function measure_area_selection(){
	run("Clear Results");
	run("Measure");
	area = getResult("Area", 0); // area of the selection
	integrated_intensity = getResult("IntDen", 0); // integrated fluorescence intensity
	integrated_intensity_background = integrated_intensity - area * background; // backgorund correction
	mean_intensity = getResult("Mean", 0); // mean fluorescence intensity
	mean_intensity_background = mean_intensity - background; // background correction
	SD = getResult("StdDev", 0); // standard deviation of the mean intensity
	CV = SD/mean_intensity_background;
	axis_major = getResult("Major", 0); // the ROI is fitted with an ellipse and its parameters are measured
	axis_minor = getResult("Minor", 0);
	eccentricity = sqrt(1-pow(axis_minor/axis_major, 2)); // according to the standard formula
	return newArray(area, integrated_intensity_background, mean_intensity_background, SD, CV, axis_major, axis_minor, eccentricity);
}

// measure fluorescence intensity just below the plasma membrane.
// used to discriminate foci in the intensity profile approach
// especially important for microdomain proteins that are cytosolic and can be bound to the plasma membrane under specific conditions, sometimes to only a few microdomains
// examples of such proteins in yeast are the exoribonuclease Xrn1 and the flavodoxin-like proteins
function measure_cort(window_title, ROI_no){
	select_window(window_title);
	select_ROI(ROI_no);
	run("Enlarge...", "enlarge=-0.249");
	run("Create Mask");
	rename("Mask-cyt-outer");
	selectWindow(list[i]); //selects raw microscopy image again
	select_window(list[i]);
	select_ROI(j);
	run("Enlarge...", "enlarge=-0.415");
	run("Create Mask");
	rename("Mask-cyt-inner");
	imageCalculator("Subtract create", "Mask-cyt-outer","Mask-cyt-inner");
	selectWindow("Result of Mask-cyt-outer");
	run("Create Selection");
	selectWindow(list[i]);
	run("Restore Selection"); //transfer of the selection to the raw microscopy image
	run("Clear Results");
	run("Measure");
	CortCyt_mean = getResult("Mean", 0);
	CortCyt_mean_background = CortCyt_mean - background;
	CortCyt_mean_SD = getResult("StdDev", 0);
	return newArray(CortCyt_mean, CortCyt_mean_SD);
}

// Count foci from intensity profile along the plasma membrane in transversal images.
function count_foci_from_intensity_profile(window_title,relative_outlier_intensity_threshold){
	plasma_membrane_from_line = measure_plasma_membrane(window_title, j);
	select_ROI(j);
	plasma_membrane_from_area = measure_area_selection();
	cortical_cytosol = measure_cort(window_title, j); // array: mean, SD; neither corrected for background; serves for direct comparison of intensities when plasma_membrane microdomains are counted
	background_window_title = measure_background(window_title);
	plasma_membrane_base = measure_plasma_membrane_base(j);
	plasma_membrane_base_background = plasma_membrane_base[0] - background_window_title;
	if ((cortical_cytosol[0] - background_window_title) > plasma_membrane_from_area[2]){ // if the mean intensity of cortical cytosol is greater than the mean intensity in the plasma membrane (happens in the case that the protein is (mostly) cytosolic, due to how the ROIs are drawn)
		Peak_MIN = foci_prominence*cortical_cytosol[0]+background_window_title;
	} else {
		Peak_MIN = foci_prominence*plasma_membrane_base_background+background_window_title;
	}
	select_window(window_title);
	select_ROI(j);
	run("Area to Line");
	profile = getProfile();
	Array.getStatistics(profile, profile_min, profile_max, profile_mean, profile_stdDev);
	maxIndices = Array.findMaxima(profile, profile_stdDev/2, 2);
	maxima = newArray(0);
	M = 0;
	foci_outliers = 0;
	for (jj = 0; jj < maxIndices.length; jj++){
		x = maxIndices[jj];
		if ((profile[x]-background_window_title)/plasma_membrane_base_background > relative_outlier_intensity_threshold){
			foci_outliers++;
		} else
			if (profile[x] > Peak_MIN){
				maxima[M] = profile[x];
				x = maxIndices[jj];
			M++;
			}
	}
	Array.getStatistics(maxima, maxima_min, maxima_max, maxima_mean, maxima_stdDev);
 	foci = maxima.length;
	foci_intensity_background = maxima_mean-background_window_title;
	foci_density = foci/plasma_membrane_from_line[0];
	mean_foci_prominence = foci_intensity_background/plasma_membrane_base_background;
	return newArray(foci, foci_density, foci_intensity_background, mean_foci_prominence, foci_outliers);
}

// Count foci along the plasma membrane in transversal images processed by thresholding to get binary images. 
function count_foci_from_thresholding(window_title){
	select_window(window_title);
	run("Select None");
	run("Duplicate...", "duplicate channels="+ch);
//	rename("DUP");
	plasma_membrane = measure_plasma_membrane(window_title, j); //plasma_membrane[0] - length, plasma_membrane[1] - mean intensity
//	setThreshold(plasma_membrane[1], pow(2,bit_depth)-1);
//	plasma_membrane_base = measure_plasma_membrane_base(j);
	background_window_title = measure_background(window_title+"-1");
//	plasma_membrane_base_background = measure_plasma_membrane_base(j) - background_window_title;
	plasma_membrane_base = measure_plasma_membrane_base(j);
	plasma_membrane_base_background = plasma_membrane_base[0] - background_window_title;
	setThreshold(foci_prominence*plasma_membrane_base_background + plasma_membrane_base[1] + background_window_title, pow(2,bit_depth)-1);
//	setThreshold(foci_prominence*plasma_membrane_base_background + background_window_title, pow(2,bit_depth)-1);
	run("Convert to Mask");
	imageCalculator("Multiply", window_title+"-1", "plasma_membrane_mask-WS");
	run("Despeckle");
	run("Adjustable Watershed", "tolerance=0.1");
	run("Convert to Mask");
	select_ROI(j);
	Delta = 0.166;
	run("Enlarge...", "enlarge=" + Delta);
	run("Analyze Particles...", "size=0.01-0.03 circularity=0.50-1.00 show=Overlay display clear overlay");
//	run("Analyze Particles...", "size=0.02-" + size_MAX +" circularity=0.50-1.00 show=Overlay display clear overlay");
//	run("Analyze Particles...", "size=0.03-0.20 circularity=0.75-1.00 show=Overlay display clear overlay");
//	run("Analyze Particles...", "size=0-0.36 circularity=0.50-1.00 show=Overlay display clear overlay");
	foci = nResults;
	foci_density = foci/plasma_membrane[0];
	close(window_title+"-1");
	return newArray(foci, foci_density);
}

// Measure the length and mean intensity in the plasma membrane.
// Intensity is measured from a line following the ROI circumference in this case.
// The obtained value is similar to that obtained from plasma membrane segmentation, but differenc, as the line has a small gap between end and beginning.
function measure_plasma_membrane(window_title, ROI_no){
	select_window(window_title);
	select_ROI(ROI_no);
	run("Area to Line"); // convert the ellipse (area object) to a line that has a beginning and end
	run("Line Width...", "line=" + 0.332/pixelHeight); // the thickness of the line is set to correspond to the thickness of the plasma membrane obtained from segmentation
	run("Clear Results");
	run("Measure");
		plasma_membrane_mean = getResult("Mean", 0);
		plasma_membrane_length = getResult("Length", 0);
	return newArray(plasma_membrane_length, plasma_membrane_mean);
}

// used for tangential images only
// measure the fluorescence intensity of the plasma membrane in the areas where high-intensity foci are absent (base plasma membrane intensity)
// function is similar to the measure_background() function in the first half, then additional thresholding is used
function measure_cell_background(){
	run("Duplicate...", "duplicate");
	rename("DUP-CROP");
	run("Duplicate...", "duplicate");
	rename("DUP-CROP-background");
	getDimensions(cell_width, height, channels, slices, frames);
	run("Subtract Background...", "rolling=" + cell_width);
	imageCalculator("Difference create stack", "DUP-CROP", "DUP-CROP-background");
	run("Clear Results");
	run("Restore Selection");
	run("Measure");
		cell_mean = getResult("Mean", 0);
	selectWindow("DUP-CROP");
	setThreshold(0, 1.3*cell_mean);
	run("Select None");
	run("Create Mask");
	run("Restore Selection");
	setBackgroundColor(0, 0, 0);
	run("Clear Outside");
	run("Create Selection");
	selectImage("DUP-CROP");
	run("Restore Selection");
	run("Measure");
		cell_background = getResult("Mean", 1);
		cell_background_SD = getResult("StdDev", 1);
	close("DUP-CROP-background");
	close("DUP-CROP");
	close("Result of DUP-CROP");
	close("mask");
	setBackgroundColor(255, 255, 255);
	return newArray(cell_background, cell_background_SD);
}

// Prepare the image for foci counting by the "Watershed segmentation" plugin and a bit of subsequent processing.
// As this takes a lot of time, the resulting image is saved.
// The segmentation itself ignores ROIs, so the resulting segmentation mask files can be used even if the ROIs are adjusted and analysis run again.
// The segmentation masks need to be removed only if the parameters of the actual segmentation are changed.
function watershed_segmentation(core_title){
	watershedDir = File.getParent(dir) + "/" + replace(File.getName(dir), "data", "watershed_segmentation-ch" + ch) + "/";
	if (!File.exists(watershedDir))
		File.makeDirectory(watershedDir);
	if (File.exists(watershedDir + core_title + "-WS.png")){
		open(watershedDir + core_title + "-WS.png");
		rename("Watershed-Segmented");
	} else {
		selectWindow(list[i]);
		run("Duplicate...", "title=DUP_watershed channels=" + ch);
		run("Select None");
		run("8-bit");
		run("Watershed Segmentation", "blurring='0.0' watershed='1 1 0 255 1 0' display='2 0' ");
			// written by Daniel Sage (http://bigwww.epfl.ch/sage/soft/watershed)
			// Description of the arguments of the blurring command (mandatory)
			// 	argument 1: Radius of the Gaussian blurring; 0 or less than 0 means no blurring
			// Description of the arguments of the watershed command (all mandatory)
			// 	argument 1: 0 for dark objects on bright background, 1 otherwise
			// 	argument 2: 0 a neighborhood of 4 pixels, 1 a neighborhood of 8 pixels
			// 	argument 3: minimum level [0..255]
			// 	argument 4: maximum level [0..255]
			// 	argument 5: 1 to show the progression messages, 0 otherwise
			// 	argument 6: 1 to create an animation, 0 otherwise. Not allowed for image stack.
			// Description of the arguments of the display output command (all optional)
			//	0 for object/background binary image
			//	1 for watershed lines
			//	2 for red overlaid dams
			//	3 for labelized basins
			//	4 for colorized basins
			//	5 for composite image
			//	6 for showing input image of the watershed operation
			while(!isOpen("Dams"))
				wait(1);
		selectWindow("Binary watershed lines");
		run("Despeckle");
		saveAs("PNG", watershedDir + core_title + "-WS");
		rename("Watershed-Segmented");
		close("Dams");
	}
	// Using the defined ROIs, create a segmentation mask of all plasma membranes in the image.
	// This is used to filter out objects in the Watershed segmentation image that have nothing to do with our defined ROIs.
	// The result of the filtering is then saved for future work, such as object-based colocalization analysis.
	// This is calculated every time the analysis is run, so if the ROIs change, nothing has to be removed.
	selectImage(list[i]);
	bounds = newArray(-1, 2); // used to make the ROI smaller by delta, then bigger by delta (the enlargement uses the shrunk ROI, hence 2 is used) - use of the array allows for usage of a for cycle
	names = newArray("inner", "outer");
	Delta = 5*pow(0.166,2)/pixelWidth;
	numROIs = roiManager("count");
	for (k = 0; k <= 1; k++){
		for (j = 0; j < numROIs; j++){
			roiManager("select", j);
			run("Enlarge...", "enlarge=" + bounds[k]*Delta + " pixel");
			roiManager("update");
		}
		roiManager("show all without labels");
		run("ROI Manager to LabelMap(2D)");
		run("Grays");
		// binarize the image to make a mask
		setMinAndMax(0, 1);
		run("Apply LUT");
		rename(names[k]);
	}
	imageCalculator("Difference create", names[0], names[1]);
	rename("plasma_membrane_mask-WS");
	// filtering of the Watershed segmentation image by the calculated plasma membrane mask image
	selectWindow("Watershed-Segmented");
	run("Invert");
	imageCalculator("Multiply", "Watershed-Segmented", "plasma_membrane_mask-WS");
	run("Despeckle"); // smoothing of the result, removal of tiny objects
	run("Convert to Mask");
	// only keep objects that are bigger than 4 pixels (total) and smaller than 0.16 um^2 (i.e., 400x400 nm)
	size_MAX = 0.16/pow(pixelWidth, 2);
	run("Analyze Particles...", "size=4.00-" + size_MAX + " circularity=0.50-1.00 show=Masks");
	saveAs("PNG", watershedDir + core_title + "-WS_foci");
	rename("WS_foci");
	roiManager("reset");
	roiManager("Open", roiDir + core_title + RoiSet_suffix);
	roiManager("Remove Channel Info");
}

// count foci in the image prepared by the "Watershed segmentation" plugin and a bit of subsequent processing
function count_foci_from_watershed_segmentation(){
	selectWindow("WS_foci");
	Delta = 5*pow(0.166,2)/pixelWidth;
	size_MAX = 0.16/pow(pixelWidth, 2);
	select_ROI(j);
	run("Enlarge...", "enlarge=" + Delta);
	run("Set Measurements...", "area mean standard modal min integrated centroid fit redirect=DUP_Gauss decimal=5");
	run("Analyze Particles...", "size=4-" + size_MAX + " circularity=0.50-1.00 show=Overlay display clear");
	WS_foci = 0;
	for (x = 0; x < nResults; x++){
		y = getResult("Mean", x);
		if (y > 1.75*base_of_plasma_membrane + background_DUP_Gauss)
			WS_foci++;
	}
	run("Set Measurements...", "area mean standard modal min integrated centroid fit redirect=None decimal=5");
	return newArray(WS_foci, WS_foci/plasma_membrane_length);
}

// Functions to select a specific ROI/window; now probably obsolete.
// Functions was developed when the macro could not be run in BatchMode and sometimes had a tendency to run ahead of itself, resulting in a crash.
// ROI/window is selected, then it is verified that the active ROI/window is the one that was expected. If not, it is selected again after a 1 ms delay.
function select_ROI(j){
	roiManager("Select", j);
	while(selectionType() == -1){
		wait(1);
		roiManager("Select", j);
	}
}

function select_window(window_title){
	selectWindow(window_title);
	while(!(getTitle == window_title)){
		wait(1);
		selectWindow(window_title);
	}
}

// ROISets are saved without any of the suffixes listed here, to ensure compatibility with other macros.
// Note that the switch to this approach makes this version incompatible with previous versions of 8.x and lower
// and also incompatible with Quatify version 14.x and lower!
function clean_title(string){
	suffixes = newArray("-AVG", "-SUM", "-MAX", "-MIN", "-processed", "-corr");
	for (i = 0; i < suffixes.length; i++){
		string = replace(string, suffixes[i], "");
	}
	return string;
}