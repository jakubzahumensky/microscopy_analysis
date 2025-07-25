// This macro takes raw microscopy images and ROIs defined elsewhere and then analyses each ROI separately.
// Multiple parameters for each ROI are analyzed and written into the Results table.
// These include: area (size), mean and intergal fluorescence intensity of the whole ROI, its circumference (i.e., plasma membrane if a ROI corresponds to the cell), its inside,
// number of high-intensity foci (microdomains) in the plasma membrane, etc.

test = 0;
//test = 1;
if (test == 0)
	setBatchMode(true);
subset_default = "";

////////////////////////////////////////////////////////////////////////////////
// Abbreviations used:
// cyt - cytosol
// CV - coefficient of variance
////////////////////////////////////////////////////////////////////////////////

version = 13.51;
extension_list = newArray("czi", "oif", "lif", "tif", "vsi"); //only files with these extensions will be processed; if your filetype is not in the group, simply add it
image_types = newArray("transversal", "tangential"); //there are either tranversal (going through the middle) or tangential (showing the surface) microscopy images. Z-stack projections are a special case of the latter.
boolean = newArray("yes","no");

// initial values of variables that change within functions
var temp_files_count = 0;
var continue_analysis = 0;
var count = 0;
//var counter = 1;
var proc_files_number = 0;
var title = "";
var roiDir = "";
var fociDir = "";
var pixelHeight = 0;
var ch = 1; // iterative variable for cycling through channels
var proc_files = "";
var pixelWidth = 0;
var Image_Area = 0;
var plasma_membrane_base_background = 0;
var bit_depth = 0;
var plasma_membrane_length = 0;

CV_threshold = 0.3; // CV for discrimination of cells without foci; for tangential images only
cell_size_min = 5; // by default, cells with area smaller than 5 um^2 are excluded from the analysis. Can be changed in the dialog window below when analysis is run
Gauss_Sigma = 1; // smoothing factor (Gauss)
foci_prominence = 1.666; // patch prominence threshold (for transversal images) - set semi-empirically

// Display the "Quantify" dialog window, including a help message defined in the html0 variable. Multiple parameters need to be set by the user.
// Detailed explanation in the help message (and protocol)
html0 = "<html>"
	+"<b>Directory</b><br>"
	+"Specify the directory where you want <i>Fiji</i> to start looking for folders with images. The macro works <i>recursively</i>, i.e., it looks into all subfolders. "
	+"All folders with names <i>ending</i> with the word \"<i>data</i>\" for <i>transversal</i> image type) or \"<i>data-caps</i>\" (for <i>tangential</i> image type) are processed. "
	+"All other folders are ignored.<br>"
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
	+"Using a consistent naming scheme accross your data enables automated downstream data processing.<br>"
	+"<br>"
	+"<b>Experiment code scheme</b><br>"
	+"Specify how your experiments are coded. The macro assumes a folder structure of <i>\".../experimental_code/biological_replicate_date/data<sup>*</sup>/\"</i>. See protocol for details.<br>"
	+"<sup>*</sup> - or <i>\"data-caps\"</i> for tangential images. <br>"
	+"<br>"
	+"<b>Image type</b><br>"
	+"Select if your images represent <i>transversal</i> (also called <i>equatorial</i>) or <i>tangential</i> sections of the cells.<br>"
	+"<br>"
	+"<b>Min and max cell size</b><br>"
	+"Specify lower (<i>min</i>) and upper (<i>max</i>) limit for cell area (in &micro;m<sup>2</sup>; as appears in the microscopy images). "
	+"Only cells within this range will be included in the analysis. The default lower limit is set to 5 &micro;m<sup>2</sup>, which corresponds to a small bud of a haploid yeast. "
	+"<i>The user is advised to measure a handful of cells before adjusting these limits. If in doubt, set limits 0-Infinity and filter the results table.</i><br>"
	+"<br>"
	+"<b>Coefficient of variance (CV) threshold</b><br>"
	+"Cells whose intensity coefficient of variance (standard deviation/mean) is below the specified value will be excluded from the analysis. Can be used for automatic removal of dead cells, "
	+"but <i>a priori</i> knowledge about the system is required. Filtering by CV can be performed <i>ex post</i> in the results table.<br>"
	+"<br>"
	+"<b>Deconvolved</b><br>"
	+"Select if your images have been deconvolved. If used, no Gaussian smoothing is applied to images before quantification of foci in the plasma membrane. "
	+"In addition, prominence of 1.333 is used instead of 1.666 used for confocal images. The measurements of intensities (cell, cytosol, plasma membrane) are not affected by this. "
	+"Note that the macro has been tested with a limited set of deconvolved images from a wide-field microscope (solely for the purposes of <i>Zahumensky et al., 2022</i>). "
	+"Proceed with caution and verify that the results make sense.<br>"
	+"</html>";
Dialog.create("Quantify");
	Dialog.addDirectory("Directory:", "");
	Dialog.addString("Subset (optional):", subset_default);
	Dialog.addString("Channel(s):", ch);
	Dialog.addString("Naming scheme:", "strain,medium,time,condition,frame", 33);
	Dialog.addString("Experiment code scheme:", "XY-M-000", 33);
	Dialog.addChoice("Image type:", image_types);
	Dialog.addNumber("Cell size from:", cell_size_min);
	Dialog.addToSameRow();
	Dialog.addNumber("to:","Infinity",0,6, fromCharCode(181) + "m^2");
	Dialog.addNumber("Coefficient of variance (CV) threshold", 0);
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
	deconvolved = Dialog.getChoice();

// if the dir name does not end with a slash, add one
if (!endsWith(dir, "/"))
	dir = dir + "/";

// if images have been deconvolved, do not use smoothing and decrease the threshold for the identification of microdomains
if (deconvolved == "yes"){
	Gauss_Sigma = 0; //no smoothing is used
	foci_prominence = 1.333; //patch prominence can be set lower compared to regular confocal images
}

dirMaster = dir; //directory into which Result summary is saved; it is the same dir as is used by the user as the starting point

if (matches(image_type, "transversal")){
	dirType="data";
} else {
	dirType="data-caps";
}
// dirType = "data-"+image_type+"/";
// ROIsdirType = "ROIs-"+image_type+"/";

// Process the input channels (list, range) to get an array of individual channel numbers to be processed (defined below)
CHANNEL = sort_channels(channel);

// Check for the existence of temporary files, which are kept if an analysis is interrupted; this allows the analysis to be resumed
// If at least one temporary file is found, user is notified and asked whether to continue the analysis or start from the beginning (the latter overwrites the previous temp results)
for (ii = 0; ii <= CHANNEL.length-1; ii++){
	ch = CHANNEL[ii];
	temp_file = "results-temporary_" + image_type + "_channel_"+ ch +".csv";
	if (contains(getFileList(dirMaster), temp_file))
		temp_files_count++;
}
if (temp_files_count > 0)
	continue_analysis = getBoolean("Incomplete analysis dectected.", "Continue previous analysis", "Start fresh");

// Count files to be processed; used for the status window
countFiles(dir);

// the "code" :) multiple functions are used, see below
for (ii = 0; ii <= CHANNEL.length-1; ii++){
	ch = CHANNEL[ii];
	counter = 1;
	temp_file = "results-temporary_" + image_type + "_channel_"+ ch +".csv";
	no_ROI_files = "files_without_ROIs_" + image_type + "_channel_"+ ch +".tsv";
	processed_files = "processed_files_" + image_type + "_channel_"+ ch +".tsv";
	initialize();
	processFolder(dir);
	channel_wrap_up();
}
final_wrap_up();

//________________________________________________________definitions of functions________________________________________________________

// Definition of "processFolder" function: starts in selected directory, makes a list of what is inside then goes through it one by one
// If it finds another directory, it enters it and makes a new list and does the same.
// In this way, it enters all subdirectories and looks for data.
function processFolder(dir){
	list = getFileList(dir);
	for (i=0; i<list.length; i++){
		showProgress(i+1, list.length);
		// if the list item is a folder, go in and get a list of items
		if (endsWith(list[i], "/"))
        	processFolder(""+dir+list[i]);
	    // if the item is a file, get its name with the whole path
	    else {
			q = dir+list[i];
			// process file if:
			// it is in the correct directory based on the image type
			// it is not in the list of files that have already been processed (for resumed analysis)
			// it belongs to the subset defined by the user
			if (endsWith(dir, dirType+"/") && indexOf(proc_files, q) < 0 && indexOf(q, subset) >= 0)
				if (check_ROIs(dir, list[i])){
					extIndex = lastIndexOf(q, ".");
					ext = substring(q, extIndex+1);
					// process file if its extension corresponds to any of those stored in the "extension_list" variable
					if (contains(extension_list, ext)){
						// inform user about the progress of the analysis
						print("\\Update: Processing: channel " + ch + "/" + CHANNEL.length + "; file " + counter + "/" + count-proc_files_number);
						// perform operations based on the selected image type
						if (matches(image_type, "transversal")) analyze_transversal();
							else analyze_tangential();
						counter++;	
					}
				}
		}
	}
}

// count the files to be analysed and check that all have the channels that the user selected for analysis in the initial Dialog window
// the general structure of the function is the same as the processFolder() function above
function countFiles(dir){
	list = getFileList(dir);
	for (i = 0; i < list.length; i++){
		if (endsWith(list[i], "/"))
			countFiles("" + dir + list[i]);
		else {
			q = dir+list[i];
			if (endsWith(dir, dirType+"/") && indexOf(proc_files, q) < 0 && indexOf(q, subset) >= 0){
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

// check if an array contains a specified string
function contains(array, value){
    for (i=0; i < array.length; i++)
        if (array[i] == value)
        	return true;
    return false;
}

// Create an array containing the selected channels to be processed
// The channel selection is read as a string and be in the form of individual, comma-separated list, or a range (with a dash)
// These two options need to be handles separately
function sort_channels(channel){
	if (channel <= 0)
		exit("Selected channel ("+ channel +") does not exit.");
	// if a range is defined, use the lower number as the beginning and the higher as end value; create an array containing these and all integer numbers between them
	if (indexOf(channel, "-") >= 0){
		CHANNEL = newArray(1);
		X = "--";
		channel_temp = split(channel,"--");
		// sort the array in an ascending manner
		channel_temp = Array.sort(channel_temp);
		j = 0;
		for (i = channel_temp[0]; i <= channel_temp[1]; i++){
			CHANNEL[j] = i;
			j++;
		}
	// if a list of channels is defines, simply split the values into an array; any spaces are removed immediately after the input is read from the initial dialog window
	} else
		CHANNEL = split(channel,",,");
	return CHANNEL;
}

// check that the image to be analyzed has defined ROIs. If not, skip it and write its name into a list.
// If the list is non-empty at the end of the analysis run, the user is informed that not all files were processed due to non-defined ROIs
// the analysis can be re-run to analyze these images once the ROIs are prepared
function check_ROIs(dir, string){
	title = substring(string, 0, lastIndexOf(string, "."));
	roiDir = File.getParent(dir)+"/"+replace(File.getName(dir), "data", "ROIs")+"/";
	if (File.exists(roiDir + title + "-RoiSet.zip")){
		return true;
	} else {
		print("["+no_ROI_files+"]",q+"\n");
		selectWindow(no_ROI_files);
		saveAs("Text", dirMaster + no_ROI_files);
		return false;
	}
}

// Preparatory operations that are required for each image:
// Get the path to ROIs, extract basic parameters of the image: name, bitDepth, dimensions, pixel size, image area
function prep(){
	roiDir = File.getParent(dir)+"/"+replace(File.getName(dir), "data", "ROIs")+"/";
	open(q);
	rename(list[i]);
	title = File.nameWithoutExtension;
	bit_depth = bitDepth();
	run("Select None");
	getDimensions(width, height, channels, slices, frames);
	getPixelSize(unit, pixelWidth, pixelHeight);
	run("Clear Results");
	run("Measure");
	Image_Area = getResult("Area", 0);
	// switch to the channel selected by the user
	Stack.setChannel(ch);
	// There are currently multiple ways how the raw images are analysed for the number of high-intensity foci in the plasma membrane.
	// Each of these requires a different preparation. The raw image is duplicated (and renamed by the same command) and processed.
	// These processed images are used solely for the purpose of counting of the microdomains. All intensity readings are made from the raw images.
	// This first option is used for both transversal and tangential images
	selectWindow(list[i]);
		run("Duplicate...", "title=DUP_CLAHE channels="+ch);
		run("Normalize Local Contrast", "block_radius_x=5 block_radius_y=5 standard_deviations=10 center stretch");
		run("Enhance Local Contrast (CLAHE)", "blocksize=8 histogram=64 maximum=3 mask=*None*");
		run("Unsharp Mask...", "radius=1 mask=0.6");
		run("Gaussian Blur...", "sigma=Gauss_Sigma");
	// The following are only prepared for transversal images
	// This is the reason why the analysis of transversal images is approx. an order of magnitute slower than that of tangential images
	if (matches(image_type, "transversal")){
		// Basic Gauss smoothing
		selectWindow(list[i]);
			run("Duplicate...", "title=DUP_Gauss channels="+ch);
			run("Gaussian Blur...", "sigma=Gauss_Sigma");
		// Mean smoothing
		selectWindow(list[i]);
			run("Duplicate...", "title=DUP_mean channels="+ch);
			run("Convolve...", "text1=[1 1 1\n1 1 1\n1 1 1\n] normalize");
		// Mean filtering combined with a "Dotfind" filter developed by Jan Malinsky a long time ago
		selectWindow(list[i]);
			run("Duplicate...", "title=DUP_dotfind channels="+ch);
			run("Convolve...", "text1=[1 1 1\n1 1 1\n1 1 1\n] normalize");
			run("Convolve...", "text1=[-1 -1 -1 -1 -1\n-1 0 0 0 -1\n-1 0 16 0 -1\n-1 0 0 0 -1\n-1 -1 -1 -1 -1\n]");
			run("Subtract Background...", "rolling=5");
			// this filetering creates negative values in some pixels - all negative pixels are converted to zero-intensity pixels
			changeValues("-Infinity", -1, 0);
		watershed_segmentation();
	}
	// Clear the ROI manager and open the ROIs corresponding to the current image.
	// Remove all channel-related information about the ROIs, which enables the same ROIs to be used with all channels.
	// This will create issues if one channels has the whole cells and another nuclei, for example. 
	// If this is the case, the "Remove channel Info" will have to be removed. Also adjsut the ROI_check macro to remove this (around line 490).
	roiManager("reset");
	roiManager("Open", roiDir+title+"-RoiSet.zip");
	roiManager("Remove Channel Info");
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
	// if offset is set correctly during image acquisition, zero pixel intensity usually originates when multichannel images are aligned. In this case, they need to be cropped before the background estimation
	MIN = getResult("Min", 0);
		if (MIN == 0) run("Auto Crop (guess background color)");
	rename("DUP-CROP");
	run("Duplicate...", "duplicate");
	rename("DUP-CROP-background");
	// brute-force background subtraction (by using the "rolling ball" approach), the width of the whole image is used as the diameter of the ball.
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

// Function to extract the biological replicate date and experiment accession code
// For this to work properly, correct data structure is required:
// folder whose name starts with the accession code, containing subfolders, each starting with the date in the YYMMDD (ideally) format
// each biological replicate folder contains the "data", "ROIs" and other folders
function find_parents(){
	parent = File.getParent(dir); // bio replicate date
	grandparent = File.getParent(parent); // starts with the experiment code (accession number)
	// replace spaces with underscores in both
	BR_date = replace(File.getName(parent)," ","_");
	exp_code = replace(File.getName(grandparent)," ","_");
	// date is expected in YYMMDD (or another 6-digit) format
	if (lengthOf(BR_date) > 6)
		BR_date = substring(BR_date, 0, 6);
	if (lengthOf(exp_code) > lengthOf(experiment_scheme))
		exp_code = substring(exp_code, 0, lengthOf(experiment_scheme));
	// return experimental code and biological replicate date as an array
	return newArray(exp_code, BR_date);
}

// analyze transversal images
function analyze_transversal(){
	// perform the preparatory steps and measure background (functions above)
	prep();
	background = measure_background(list[i]);
	// quantification - open ROIs prepared with ROI_prep.ijm macro (or any other means, as long as they are stored in the "ROIs" folder) and cycle through them one by one
	init = 0; // first ROI
	numROIs = roiManager("count"); // number of ROIs in the manager
	// a shortened loop that can be used for testing; activated in line 8 by assigning: test = 1;
	if (test == 1){
		init = 4; // corresponds to ROI 5
		numROIs = 8; // corresponds to ROI 9
	}
	// for each cell (ROI) measure: area, integral_intensity, mean_intensity, intensity_SD (standard deviation of the mean), intensity_CV (coefficient of variance)
	// all reported intensities are corrected for background
	for(j = init; j < numROIs; j++){
		// measure ROI characteristics and return them in an array: area, integral_intensity_background, mean_intensity_background, SD, CV
		// 0.166 makes the ROI slightly bigger to include the whole plasma membrane
		// the enlarged ROI is used to make a ROI mask below
		cell = measure_ROI(list[i], j, 0.166);
		// shape characterization from the Results table created by the measure_ROI function
		// the ROI is fitted with an ellipse and its parameters are measured
		major_axis = getResult("Major", 0);
		minor_axis = getResult("Minor", 0);
		eccentricity = sqrt(1-pow(minor_axis/major_axis, 2));
		// only analyse cells that fall into the cell size range and CV specified by the user when the macro is run
		// cell[0] corresponds to cell area; cell[4] to intensity CV (see above)
		if (cell[0] > cell_size_min && cell[0] < cell_size_max && cell[4] > CV){
			// preparation for plasma membrane segmentation
			run("Create Mask"); // creates a mask of the entire cell
			rename("Mask-cell");
			// measure cytosol characteristics and return them in an array: area, integral_intensity_background, mean_intensity_background, SD, CV
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
			run("Restore Selection"); // transfer the selection to the RAW microscopy image (i.e., no smoothing or any other processing)
			// measures plasma membrane characteristics and returns them in an array: area, integral_intensity_background, mean_intensity_background, SD, CV
			// the measure_ROI(window, ROI, buff) function above also calls the measure_area_selection() function, but first makes a selection of a specified ROI and makes it bigger/smaller
			// the measure_area_selection() function measures whatever selection is currently active
			plasma_membrane = measure_area_selection();

			// as descrived above, high-intensity foci in the plasma membrane (ROI circumference) are analyzed in multiple ways, or rather the images are processed by multiple ways before analysis
			// here, each of the image is loaded and analyzed using the foci_from_intensity_profile(window_title,relative_outlier_intensity_threshold) function
			// foci quantified from intensity profiles
			foci_from_intensity_profile_Gauss = foci_from_intensity_profile("DUP_Gauss","Infinity");
			// calculate the base of the plasma membrane, i.e., the mean intensity of the valleys between fluorescence peaks in the intensity profile
			base_of_plasma_membrane = plasma_membrane_base_background;
			// when read from an intensity profile, the distribution of maxima along the plasma membrane (ROI circumference) can be analyzed to get various parameters:
			// patch_distance_min, patch_distance_max, patch_distance_mean, patch_distance_stdDev, patch_distance_CV
//			patch_distribution = charaterize_patch_distribution(patch_numbers[0]);
			foci_from_intensity_profile_CLAHE = foci_from_intensity_profile("DUP_CLAHE","Infinity");
			foci_from_intensity_profile_dotfind = foci_from_intensity_profile("DUP_dotfind","Infinity");
		
			// foci quantified from thresholding - the pre-processed images are thresholded to make a binary image
			// the foci (high-intensity foci) are then counted
			foci_from_thresholding_Gauss = foci_from_thresholding("DUP_Gauss");
			foci_from_thresholding_CLAHE = foci_from_thresholding("DUP_CLAHE");
			foci_from_thresholding_dotfind = foci_from_thresholding("DUP_dotfind");
			// separate analysis using the "WS_foci" image created by the "Watershed segmentation" plugin
			watershed_foci = count_watershed_foci();
			// calculation of additional interesting parameters to be reported
			protein_fraction_in_foci = (1-base_of_plasma_membrane/plasma_membrane[2])*100; // calculates how much of the fluorescence signal is in the high-intensity foci (microdomains)
			plasma_membrane_DIV_cytosol = plasma_membrane[2]/cytosol[2]; // ratio of MEAN fluorescence intensities in the plasma mebrane and in the cytosol
			cytosol_DIV_cell = cytosol[2]/cell[2]; // ratio of MEAN fluorescence intensities in the cytosol and the whole cell (ROI)
			plasma_membrane_DIV_cell = plasma_membrane[2]/cell[2]; // ratio of MEAN fluorescence intensities in the plasma membrane and the whole cell (ROI)
			cytosol_DIV_cell_integral = cytosol[1]/cell[1]; // ratio of INTEGRAL fluorescence intensities in the cytosol and the whole cell (ROI)
			plasma_membrane_DIV_cell_integral = plasma_membrane[1]/cell[1]; // ratio of INTEGRAL fluorescence intensities in the plasma membrane and the whole cell (ROI)
			
			// get the experimental code (grandparent) and biological replicate date (parent)
			parents = find_parents();
			// write analysis results for the current ROI into the temporary text file - this is converted into the final Results table at the end of the analysis run
			print("["+temp_file+"]",parents[0] +","+ parents[1] // experiment code, biological replicate date
				+","+ replace(title," ","_") +","+ background +","+ (j+1) // image title, background intensity and current ROI number
//				+","+ patch_numbers[0] +","+ patch_numbers[1] +","+ patch_numbers[2] +","+ plasma_membrane_base_background +","+ patch_numbers[3] // foci, patch_density, patch_intensity, patch_prominence
				+","+ foci_from_intensity_profile_Gauss[0] +","+ foci_from_intensity_profile_Gauss[1] +","+ foci_from_intensity_profile_Gauss[2] +","+ base_of_plasma_membrane +","+ foci_from_intensity_profile_Gauss[3] // foci, patch_density, patch_intensity, plasma membrane base, patch_prominence
				+","+ cell[0] +","+ cell[1] +","+ cell[2] +","+ cell[3] +","+ cell[4] // cell parameters: area, integral_intensity, mean_intensity, SD, CV
				+","+ cytosol[0] +","+ cytosol[1] +","+ cytosol[2] +","+ cytosol[3] +","+ cytosol[4] // cytosol parameters: area, integral_intensity, mean_intensity, SD, CV
				+","+ plasma_membrane[0] +","+ plasma_membrane[1] +","+ plasma_membrane[2] +","+ plasma_membrane[3] +","+ plasma_membrane[4] // plasma membrane parameters: area, integral_intensity, mean_intensity, SD, CV
				+","+ plasma_membrane_DIV_cytosol
//				+","+ protein_fraction_in_foci +","+ patch_distribution[0] +","+ patch_distribution[1] +","+ patch_distribution[2] +","+ patch_distribution[3] +","+ patch_distribution[4] //patch_distance_min, patch_distance_max, patch_distance_mean, patch_distance_stdDev, patch_distance_CV
				+","+ plasma_membrane_DIV_cell +","+ cytosol_DIV_cell +","+ plasma_membrane_DIV_cell_integral +","+ cytosol_DIV_cell_integral +","+ major_axis +","+ minor_axis +","+ eccentricity +","+ foci_from_intensity_profile_Gauss[4] //foci_outliers at the end
				// in the following: [0] - foci; [1] - patch_density
				+","+ foci_from_intensity_profile_CLAHE[0] +","+ foci_from_intensity_profile_CLAHE[1]
				+","+ foci_from_intensity_profile_dotfind[0] +","+ foci_from_intensity_profile_dotfind[1]
				+","+ foci_from_thresholding_Gauss[0] +","+ foci_from_thresholding_Gauss[1]
				+","+ foci_from_thresholding_CLAHE[0] +","+ foci_from_thresholding_CLAHE[1]
				+","+ foci_from_thresholding_dotfind[0] +","+ foci_from_thresholding_dotfind[1]
				+","+ watershed_foci[0] +","+ watershed_foci[1]
			+"\n");
			// close all mask images created for segmentation of various cell (ROI) parts
			close("Mask-cell");
			close("Mask-cytosol");
			close("Mask-cyt-outer");
			close("Mask-cyt-inner");
			// close intermediary results
			close("Result of Mask-cell");
			close("Result of Mask-cyt-outer");
		}
	}
	// close all images and save results for the current image
	// results are saved after each image is done being analyzed, which allows the analysis to be resumed
	close("*");
	save_temp();
}

function analyze_tangential(){
	prep();
	background = measure_background(list[i]);
	numROIs = roiManager("count");
//count eisosomes using the "Find Maxima" plugin
	for(j = 0; j < numROIs; j++){
//	for(j = numROIs-3; j < numROIs; j++){
		
	select_window(list[i]);
		select_ROI(j);
		run("Duplicate...", "title=DUP_cell duplicate channels="+ch);
	//measure cell parameters from raw image (size, fluorescence intensity, major axis of the ellipse used for fitting the ROI
		run("Clear Results");
		run("Measure");
		Area = getResult("Area", 0);
		cell_I_mean = getResult("Mean", 0);
		cell_I_mean_background = cell_I_mean-background; //background correction
		cell_I_SD = getResult("StdDev", 0); //standard deviation of the mean intensity (does not change with background)
		cell_CV = cell_I_SD/cell_I_mean_background;
		major_axis = getResult("Major", 0);
		if (Area > cell_size_min && Area < cell_size_max){ //continue if the cell size falls between the lower and upper limit
//			if (cell_CV > 0.3){ //a cell (tangential section) is only considered to have microdomains if the CV (i.e,. SD/mean) is greater than 0.3 (empirical)
		//analyze patch density from the image with local contrast adjustment
			select_window("DUP_CLAHE");
			select_ROI(j);
//			Delta = major_axis/3*(1-sqrt(2/3)); // the ROI is made smaller by this amount in the following step to exclude background areas from the analysis
			Delta = major_axis/2*(1-sqrt(2/3)); // the ROI is made smaller by this amount in the following step to exclude background areas from the analysis
			run("Enlarge...", "enlarge=-"+Delta);
			run("Clear Results");
			run("Measure");
			ROI_area = getResult("Area", 0); //used below to calculate patch density
//	CV_ROI = getResult("StdDev", 0)/getResult("Mean", 0);
//waitForUser(CV_ROI);
			cell_background_CLAHE = measure_cell_background(); //measures mean and SD of the intensity of area among foci; serves as baseline for maxima identification and thresholding
			patch_prom = cell_background_CLAHE[0]*0.1;//mean
//			patch_prom = cell_background[1]*2; //SD
			no_of_foci = 0;
			run("Clear Results");
//			run("Find Maxima...", "prominence=patch_prom strict exclude output=Count");
			run("Find Maxima...", "prominence=patch_prom exclude output=Count");
			if (cell_CV > CV_threshold) //if the CV is not greater than CV_threshold (set to 0.3 by def.), the cells are deemed to have no microdomains
				no_of_foci = getResult("Count", 0);
			patch_density_find_maxima = no_of_foci/ROI_area;
		//patch quantification via thresholding and "Analyze particles..." plugin
		//setting initial values that are witten into the Results table if no foci are detected
			area_fraction = 0;
			size = NaN;
			size_SD = NaN;
			length = NaN;
			length_SD = NaN;
			width = NaN;
			width_SD = NaN;
			density = 0;
			MEAN2 = NaN;
			patch_I_mean_background = NaN;
			patch_I_SD = NaN;
		//make mask from current ROI, setting the Threshold based on the intensity of signal in between foci
			if (no_of_foci > 0){
				select_window("DUP_CLAHE");
				select_ROI(j);
				run("Enlarge...", "enlarge=-"+Delta);
				run("Duplicate...", "title=DUP duplicate channels="+ch);
				run("Select None");
//				setThreshold(cell_background_CLAHE[0]+cell_background_CLAHE[1], pow(2,bit_depth)-1);
				setThreshold(cell_background_CLAHE[0]+3*cell_background_CLAHE[1], pow(2,bit_depth)-1);
				run("Create Mask");
				rename("MASK");
				run("Adjustable Watershed", "tolerance=0.01");
				run("Clear Results");
				run("Measure");
				mask_mean = getResult("Mean", 0);
				if (mask_mean > 0){ //proceed only if there is any signal
					run("Restore Selection");
					setBackgroundColor(0, 0, 0);
					run("Clear Outside");
					setBackgroundColor(255, 255, 255);
					run("Enlarge...", "enlarge=1 pixel");
					run("Translate...", "x=-1 y=-1 interpolation=None");
					run("Clear Results");
					run("Analyze Particles...", "size="+5*pow(pixelHeight,2)+"-"+120*pow(pixelHeight,2)+" show=Nothing display exclude clear stack"); //only particles that take at least 5 pixels (smallest possible cross) are included
					no_of_foci = nResults;
					if (no_of_foci > 0){ //get info if there is a single patch
						size = getResult("Area", 0);
						length = getResult("Major", 0);
						width = getResult("Minor", 0);
						density = no_of_foci/ROI_area;
						area_fraction = size*density*100;
					}
					if (no_of_foci > 1){ //summarize only if there is more than one patch (it does not work when there is a single result...)
						run("Summarize");
						size = getResult("Area", no_of_foci);
						size_SD = getResult("Area", no_of_foci+1);
						length = getResult("Major", no_of_foci);
						length_SD = getResult("Major", no_of_foci+1);
						width = getResult("Minor", no_of_foci);
						width_SD = getResult("Minor", no_of_foci+1);
						density = no_of_foci/ROI_area;
						area_fraction = size*density*100;
					}
					selectWindow("MASK");
					run("Translate...", "x=1 y=1 interpolation=None");		
					run("Create Selection");
					selectWindow("DUP_cell");
					run("Restore Selection");
					run("Clear Results");
					run("Measure");
					patch_I_mean = getResult("Mean", 0);
					patch_I_mean_background = patch_I_mean-background;
					patch_I_SD = getResult("StdDev", 0);
				}
				close("MASK");
				close("DUP");
				close("DUP2");
				close("DUP_cell");
			}
			parents = find_parents(); //exp_code, BR_date
			print("["+temp_file+"]",parents[0] +","+ parents[1]
				+","+ replace(title," ","_") +","+ background +","+ j+1
				+","+ patch_density_find_maxima +","+ density +","+ area_fraction
				+","+ length +","+ length_SD +","+ width +","+ width_SD +","+ size +","+ size_SD
				+","+ patch_I_mean_background +","+ patch_I_SD
				+","+ "\n");
		}
	}
	close("*");
	save_temp();
}

//prepare Fiji and find out if previous analysis run concluded
function initialize(){
	// close all open image windows, including specific text windows that might be open
	// create new text windows to write temporary results, names of processed files and files without defined ROIs
	close("*");
	if(isOpen("Log"))
		close("Log");
	if(isOpen(temp_file))
		print("["+temp_file+"]","\\Close");		
	if(isOpen(processed_files))
		print("["+processed_files+"]","\\Close");
	if(isOpen(no_ROI_files))
		print("["+no_ROI_files+"]","\\Close");
	run("Text Window...", "name=["+temp_file+"] width=180 height=40");
	setLocation(0,0);
	run("Text Window...", "name=["+processed_files+"] width=180 height=20");
	setLocation(0,screenHeight/2);
	run("Text Window...", "name=["+no_ROI_files+"] width=90 height=20");
	setLocation(screenWidth*2/3,screenHeight/2);
	setBackgroundColor(255, 255, 255); // this is important for proper work with masks
	// define what things are to be measured; has effect on all measurements in the macro
	run("Set Measurements...", "area mean standard modal min integrated centroid fit redirect=None decimal=5");
	// If ana analysis is resumed from a previously interrupted one, load the temporary result file and the files listing processed files and files without defined ROIs
	// if File.exists() - when the analysis is continued and multiple channels are selected, some may not have temporary files
	if (continue_analysis == 1 && File.exists(dirMaster + temp_file)){
		if (File.exists(dirMaster + no_ROI_files)){
			File.delete(dirMaster + no_ROI_files);
			close("Log");
		}
		print("["+temp_file+"]", File.openAsString(dirMaster + temp_file));
		proc_files = File.openAsString(dirMaster + processed_files);
		print("["+processed_files+"]", proc_files);
		proc_files_array = split(proc_files,"\n");
		proc_files_number = proc_files_array.length;
	} else
		print_header();
}

//print the header of the Results output file
function print_header(){
	getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
//	print("["+temp_file+"]",
//print("\\Clear");
	print("["+temp_file+"]","# Basic macro run statistics:"+"\n");
	print("["+temp_file+"]","# Date and time: " + year + "-" + String.pad(month + 1,2) + "-" + String.pad(dayOfMonth,2) + " " + String.pad(hour,2) + ":" + String.pad(minute,2) + ":" + String.pad(second,2)+"\n");
	print("["+temp_file+"]","# Macro version: " + version+"\n");
	print("["+temp_file+"]","# Channel: " + ch+"\n");
	print("["+temp_file+"]","# Cell (ROI) size interval: " + cell_size_min + "-" + cell_size_max +" um^2"+"\n");
	print("["+temp_file+"]","# Coefficient of variance threshold: " + CV+"\n");
	if (matches(image_type, "transversal")){
		print("["+temp_file+"]","# Smoothing factor (Gauss): " + Gauss_Sigma+"\n");
		print("["+temp_file+"]","# Patch prominence: " + foci_prominence+"\n");
	}
	print("["+temp_file+"]","#"+"\n"); //emptyline that is ignored in bash and R
	//the parameters quantified from transversal and tangential focal planes are necessarily different. Hence, the columns in the Results file are also different
	if (matches(image_type, "transversal"))
		print("["+temp_file+"]","exp_code,BR_date,"
			+ naming_scheme + ",mean_background,cell_no"
			+",foci,patch_density,patch_intensity,plasma_membrane_base,patch_prominence"
			+",cell_area,cell_I.integral,cell_I.mean,cell_I.SD,cell_I.CV"
			+",cytosol_area,cytosol_I.integral,cytosol_I.mean,cytosol_I.SD,cytosol_I.CV"
			+",plasma_membrane_area,plasma_membrane_I.integral,plasma_membrane_I.mean,plasma_membrane_I.SD,plasma_membrane_I.CV"
			+",plasma_membrane_I.div.Cyt_I(mean)"
//			+",prot_in_foci,patch_distance_min,patch_distance_max,patch_distance_mean,patch_distance_stdDev,patch_distance_CV"
			+",plasma_membrane_I.div.cell_I(mean),Cyt_I.div.cell_I(mean),plasma_membrane_I.div.cell_I(integral),Cyt_I.div.cell_I(integral)"
			+",major_axis,minor_axis,eccentricity,foci_outliers"
			+",foci_profile_CLAHE,patch_density_profile_CLAHE"
			+",foci_profile_dotfind,patch_density_profile_dotfind"
			+",foci_threshold_Gauss,patch_density_threshold_Gauss"
			+",foci_threshold_CLAHE,patch_density_threshold_CLAHE"
			+",foci_threshold_dotfind,patch_density_threshold_dotfind"
			+",foci_from_watershed,patch_density_from_watershed"
			+"\n"
		);
	else
		print("["+temp_file+"]","exp_code,BR_date," + naming_scheme + ",mean_background,cell_no,patch_density(find_maxima),patch_density(analyze_particles),area_fraction(patch_vs_ROI),length,length_SD,width,width_SD,size,size_SD,mean_patch_intensity,mean_patch_intensity_SD"+"\n");
	setLocation(0,0);
}

function save_temp(){
	selectWindow(temp_file);
	saveAs("Text", dirMaster + temp_file);
	setLocation(0, 0);
	print("["+processed_files+"]", q + "\n");
	selectWindow(processed_files);
	saveAs("Text", dirMaster + processed_files);
}

//saving of the output in csv format and cleaning up the Fiji (ImageJ) space
function channel_wrap_up(){
	getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
	res = "Results of " + image_type + " image analysis, channel " + ch + " (" + year + "-" + String.pad(month + 1,2) + "-" + String.pad(dayOfMonth,2) + "," + String.pad(hour,2) + "-" + String.pad(minute,2) + "-" + String.pad(second,2) + ").csv";
	selectWindow(temp_file);
	saveAs("Text", dirMaster + res);
	close("Results");
	close("ROI manager");
	print("["+processed_files+"]","\\Close");
	print("["+no_ROI_files+"]","\\Close");
	print("["+res+"]","\\Close");
	if (File.length(dirMaster + no_ROI_files) == 0){
		File.delete(dirMaster + temp_file);
//		close("Log");
	}
	close("Log");
}

//saving of the output in csv format and cleaning up the Fiji (ImageJ) space
function final_wrap_up(){
	setBackgroundColor(0, 0, 0); //reverts the backgroudn to default ImageJ settings
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
		waitForUser("This is curious...", "No images were analysed. Check if you had prepared ROIs before you ran the analysis.");
	else
		if (File.length(dirMaster + no_ROI_files) > 0)
			waitForUser("Finito!", "Analysis finished successfully, but one or more images were not processed due to missing ROIs.\nThese are listed in the \"files_without_ROIs\" file.");
		else
			waitForUser("Finito!", "Analysis finished successfully."); //informs the user that the analysis has finished successfully
}

//following code analyses distribution of fl. maxima along the plasma membrane: shortest, longest, average distance, and coeffcient of variance of their distribution (a measure of uniformity)
//for this purpose, plasma_membrane_add variable is introduced to allow for the measurement of distance between the last and first fl. maxima along the plasma membrane
function charaterize_patch_distribution(foci){
	patch_distance_min = NaN;
	patch_distance_max = NaN;
	patch_distance_mean = NaN;
	patch_distance_stdDev = NaN;
	patch_distance_CV = NaN;
	if (foci > 1){
		MAXIMA = newArray(foci);
		for (p = 0; p < foci; p++){
//						for (p=foci_outliers; p<foci; p++){ //at this point, maxima are ordered by intensity; starting at "foci_outliers" makes the algorithm discart P-bodies
			MAXIMA[p] = getResult("X1",p);
		}
		Array.sort(MAXIMA);//sorts positions of the intensity maxima in ascending manner
		plasma_membrane_add = plasma_membrane_length+MAXIMA[0];
		if (plasma_membrane_add > MAXIMA[MAXIMA.length-1]) MAXIMA = Array.concat(MAXIMA, plasma_membrane_add);
			else foci = foci-1;
		patch_distance = newArray(MAXIMA.length-1);
		for (p = 0; p < MAXIMA.length-1; p++){
		 	patch_distance[p] = MAXIMA[p+1]-MAXIMA[p];
		}
		Array.getStatistics(patch_distance, patch_distance_min, patch_distance_max, patch_distance_mean, patch_distance_stdDev);
		patch_distance_CV = patch_distance_stdDev / patch_distance_mean;
	}
	return newArray(patch_distance_min, patch_distance_max,	patch_distance_mean, patch_distance_stdDev, patch_distance_CV);
}

function get_plasma_membrane_base(ROI_no){
	select_ROI(ROI_no);
	run("Area to Line");
	profile = getProfile();
	Array.getStatistics(profile, profile_min, profile_max, profile_mean, profile_stdDev);
	minIndices = Array.findMinima(profile, 1.5*profile_stdDev, 1);
	minima = newArray(0);
	M = 0;
	for (jj = 0; jj < minIndices.length; jj++){
		x = minIndices[jj];
		minima[jj] = profile[x];
	}
	Array.getStatistics(minima, minima_min, minima_max, minima_mean, minima_stdDev);
	if (minima.length == 0)
		minima_mean = (profile_mean+profile_min)/2;
	return newArray(minima_mean, minima_stdDev);
//	return minima_mean;
}

function measure_ROI(window_title, j, buff){
	select_window(window_title);
	select_ROI(j);
	run("Enlarge...", "enlarge="+buff);
	measurements = measure_area_selection();
	return measurements;
}

// measure parameters of the selected area
function measure_area_selection(){
	run("Clear Results");
	run("Measure");
	area = getResult("Area", 0); // area of the selection
	integral_intensity = getResult("IntDen", 0); // integral fluorescence intensity
	integral_intensity_background = integral_intensity - area * background; // backgorund correction
	mean_intensity = getResult("Mean", 0); // mean fluorescence intensity
	mean_intensity_background = mean_intensity - background; // background correction
	SD = getResult("StdDev", 0); // standard deviation of the mean intensity
	CV = SD/mean_intensity_background; 
	return newArray(area, integral_intensity_background, mean_intensity_background, SD, CV);
}

// Measure fluorescence intensity just below the plasma membrane.
// Used to discriminate foci in the intensity profile approach.
// Especially important for microdomain proteins that are cytosolic and can be bound to the plasma membrane under specific conditions, sometimes to only a few microdomains
// Examples of such proteins in yeast are the exoribonuclease Xrn1 and the flavodoxin-like proteins
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

// Function to select a specific window; possibly obsolete.
// Function was developed when the macro could not be run in BatchMode and sometimes had a tendency to run ahead of itself, resulting in a crash.
// The specified window is selected, then it is verified that the active window is the one that was expected. If not, it is selected again after a 1 ms delay.
function select_window(window_title){
	selectWindow(window_title);
	while(!(getTitle == window_title)){
		wait(1);
		selectWindow(window_title);
	}
}

// Function to select a specific ROI; possibly obsolete.
// Function was developed when the macro could not be run in BatchMode and sometimes had a tendency to run ahead of itself, resulting in a crash.
// ROI is selected, then it is verified that the active ROI is the one that was expected. If not, it is selected again after a 1 ms delay.
function select_ROI(j){
	roiManager("Select", j);
	while(selectionType() == -1){
		wait(1);
		roiManager("Select", j);
	}
}

function foci_from_intensity_profile(window_title,relative_outlier_intensity_threshold){
	plasma_membrane_from_line = measure_plasma_membrane(window_title, j);
	select_ROI(j);
	plasma_membrane_from_area = measure_area_selection();
	cortical_cytosol = measure_cort(window_title, j); //array: mean, SD; neither corrected for background; serves for direct comparison of intensities when plasma_membrane microdomains are counted
	background_window_title = measure_background(window_title);
	plasma_membrane_base = get_plasma_membrane_base(j);
	plasma_membrane_base_background = plasma_membrane_base[0] - background_window_title;
	if ((cortical_cytosol[0] - background_window_title) > plasma_membrane_from_area[2]){ //if the mean intensity of cortical cytosol is greater than the mean intensity in the plasma membrane (happens in the case that the protein is (mostly) cytosolic, due to how the ROIs are drawn)
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
	patch_outliers = 0;
	for (jj = 0; jj < maxIndices.length; jj++){
		x = maxIndices[jj];
		if ((profile[x]-background_window_title)/plasma_membrane_base_background > relative_outlier_intensity_threshold){
			patch_outliers++;
		} else
			if (profile[x] > Peak_MIN){
				maxima[M] = profile[x];
				x = maxIndices[jj];
			M++;
			}
	}
	Array.getStatistics(maxima, maxima_min, maxima_max, maxima_mean, maxima_stdDev);
    foci = maxima.length;
	patch_intensity_background = maxima_mean-background_window_title;
	patch_density = foci/plasma_membrane_from_line[0];
	mean_patch_prominence = patch_intensity_background/plasma_membrane_base_background;
	return newArray(foci, patch_density, patch_intensity_background, mean_patch_prominence, patch_outliers);
}

// watershed segmentation gives much better results - MYR treated cells need to be checked. Other than that, WS segm appears to be the best option so far
function foci_from_thresholding(window_title){
	select_window(window_title);
	run("Select None");
	run("Duplicate...", "duplicate channels="+ch);
//	rename("DUP");
	plasma_membrane = measure_plasma_membrane(window_title, j); //plasma_membrane[0] - length, plasma_membrane[1] - mean intensity
//	setThreshold(plasma_membrane[1], pow(2,bit_depth)-1);
//	plasma_membrane_base = get_plasma_membrane_base(j);
	background_window_title = measure_background(window_title+"-1");
//	plasma_membrane_base_background = get_plasma_membrane_base(j) - background_window_title;
	plasma_membrane_base = get_plasma_membrane_base(j);
	plasma_membrane_base_background = plasma_membrane_base[0] - background_window_title;
	setThreshold(foci_prominence*plasma_membrane_base_background + plasma_membrane_base[1] + background_window_title, pow(2,bit_depth)-1);
//	setThreshold(foci_prominence*plasma_membrane_base_background + background_window_title, pow(2,bit_depth)-1);
	run("Convert to Mask");
	imageCalculator("Multiply", window_title+"-1", "plasma_membrane_mask-WS");
	run("Despeckle");
	run("Adjustable Watershed", "tolerance=0.1");
	run("Convert to Mask");
	select_ROI(j);
	delta = 0.166;
	run("Enlarge...", "enlarge=" + delta);
	run("Analyze Particles...", "size=0.01-0.03 circularity=0.50-1.00 show=Overlay display clear overlay");
//	run("Analyze Particles...", "size=0.02-" + size_MAX +" circularity=0.50-1.00 show=Overlay display clear overlay");
//	run("Analyze Particles...", "size=0.03-0.20 circularity=0.75-1.00 show=Overlay display clear overlay");
//	run("Analyze Particles...", "size=0-0.36 circularity=0.50-1.00 show=Overlay display clear overlay");
	foci = nResults;
	patch_density = foci/plasma_membrane[0];
	close(window_title+"-1");
	return newArray(foci, patch_density);
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
function watershed_segmentation(){
	watershedDir = File.getParent(dir)+"/"+replace(File.getName(dir), "data", "watershed_segmentation-ch")+ch+"/";
	if (!File.exists(watershedDir))
		File.makeDirectory(watershedDir);
	if (File.exists(watershedDir+title+"-WS.png")){
		open(watershedDir+title+"-WS.png");
		rename("Watershed-Segmented");
	} else {
		selectWindow(list[i]);
			run("Duplicate...", "title=DUP_watershed channels="+ch);
			run("Select None");
			run("8-bit");
			run("Watershed Segmentation", "blurring='0.0'   watershed='1 1 0 255 1 0'   display='2 0' ");
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
			saveAs("PNG", watershedDir+title+"-WS");
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
	delta = 5*pow(0.166,2)/pixelWidth;
	roiManager("reset");
	roiManager("Open", roiDir+title+"-RoiSet.zip");
	roiManager("Remove Channel Info");
	numROIs = roiManager("count");
	for (k = 0; k <= 1; k++){
		for (j = 0; j < numROIs; j++){
			roiManager("select", j);
			run("Enlarge...", "enlarge=" + bounds[k]*delta+" pixel");
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
//	run("Invert");
	saveAs("PNG", watershedDir+title+"-WS_foci");
	rename("WS_foci");
}

// count foci in the image prepared by the "Watershed segmentation" plugin and a bit of subsequent processing
function count_watershed_foci(){
	selectWindow("WS_foci");
//	run("Invert");
	delta = 5*pow(0.166,2)/pixelWidth;
	size_MAX = 0.16/pow(pixelWidth, 2);
	select_ROI(j);
	run("Enlarge...", "enlarge=" + delta);
	run("Analyze Particles...", "size=4-" + size_MAX + " circularity=0.50-1.00 show=Overlay display clear");
	return newArray(nResults, nResults/plasma_membrane_length);
}

// exit the batch mode to return ImageJ back to normal
setBatchMode(false);