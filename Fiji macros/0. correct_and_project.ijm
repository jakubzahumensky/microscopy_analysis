/**************************************************************************************************************
 * BASIC MACRO INFORMATION
 *
 * title: "Correction and projection of multidimensional images" 
 * author: Jakub Zahumensky
 * - e-mail: jakub.zahumensky@iem.cas.cz
 * - e-mail: jakub.zahumensky@gmail.com
 * - GitHub: https://github.com/jakubzahumensky
 * - Department of Functional Organisation of Biomembranes
 * - Institute of Experimental Medicine CAS
 * - citation: https://doi.org/10.1093/biomethods/bpae075
 *
 * Summary:
 * This macro takes time- or z-series of images, corrects their drift and saves the corrected image.
 * It can also perform bleach correction and compute a z-projection, which can be selected in the initial dialog window.
 * The macro uses the StackReg plugin for drift correction. Enable the BIG-EPFL update site to gain access to it.
 * For the macro to work properly, the data to be processed need to be in a folder called "data-raw". The directory chosen 
 **************************************************************************************************************/

setBatchMode(true); // starts batch mode, i.e. no images are shown on the screen during the macro run; works faster

/* definitions of constants used in the macro below */
image_name = "image";
n = 0; // initial counter value (used to report the running number of the current image)
dir_type = "-raw/"; // only images stored in directories whose names end with "-raw" are processed
// definition of options that will be given to the user for the correction and projection
bleach_correction_method = newArray("none", "Histogram Matching", "Simple Ratio"); // there is another bleach correction in ImageJ called "Exponential Fit", but has been omitted here, since it has a tendency to stop the macro
projection_type = newArray("none", "AVERAGE", "MAX", "SUM", "all"); // options for z-projection after drift (and bleach) correction
boolean = newArray("no", "yes");

var extension_list = newArray("czi", "oif", "lif", "vsi", "tif"); // only files with these extensions will be processed; if your microscopy images are in a different format, add the extension to the list
var dir = "";
var bleach_correct = "";
var projection = "";
var overwrite = "";
var dir_projections = "";
var	dir_data = "";
var channels = 0;
var slices = 0;
var width = 0;
var height = 0;
var count = 0;

/****************************************************************************************************************************************************/
/* CORE PROGRAM */
closeAllWindows();
initialDialogWindow();
initialize();
processFolder(dir);
closeAllWindows();
wrapUp();

/****************************************************************************************************************************************************/
/* INITIAL DIALOG WINDOW TO TAKE USER INPUT
 * Display the initial dialog window that prompts the user to specify the folder to be processed/analyzed,
 * and to select processes: drift and/or bleach correction and various z-projection
 * includes a Help message
 */
 function initialDialogWindow(){
	help = "<html>"
		 + "<b>Directory</b><br>"
		 + "Specify the directory where you want <i>Fiji</i> to start looking for folders with images. "
		 + "The macro works <u>recursively</u>, i.e., it looks into all <i>sub</i>folders. "
		 + "All folders with names <u>ending</u> with \"<i>-raw</i>\" (and only these) are processed. "
		 + "All other folders are ignored. <br><br>"
		
		 + "<b>Correct bleaching</b><br>"
		 + "Select what algorithm (if any) you wish to use to correct bleaching of your image sequences. "
		 + "There is another bleach correction option in ImageJ called \"<i>Exponential Fit</i>\", "
		 + "but has been omitted from the selection here, since it has a tendency to stop the macro. <br><br>"
		
		 + "<b>Projection</b><br>"
		 + "Select what kind of projection (if any) you wish to compute from your image sequences. "
		 + "Only the most common \"<i>MAX</i>\", \"<i>AVERAGE</i>\" and \"<i>SUM</i>\" are included here. "
		 + "Addition of other options is not straightforward. <br><br>"
		
		 + "<b>Overwrite previously processed images</b><br>"
		 + "Choose if you want to overwrite previously processed (i.e., drift- and/or bleach- corrected) images. "
		 + "These are kept by default, as they are computationaly demanding. "
		 + "Note that the filename of the processed image does not include information about bleach corrections. <br>"
		
		 + "</html>";
	Dialog.create("Correct drift and bleach, calculate projection");
		Dialog.addMessage("Note: Images with following extensions are processed: " + String.join(extension_list) + ". \nIf your files have another extension, please add it to the 'extension_list' array in line 23.");
		Dialog.addDirectory("Directory:", "");
		Dialog.addChoice("Correct bleaching:", bleach_correction_method);
		Dialog.addChoice("Projection:", projection_type);
		Dialog.addChoice("Overwrite previously processed images:", boolean);
		Dialog.addMessage("Click \"Help\" for more information on the parameters.");
		Dialog.addHelp(help);
		Dialog.show();
		dir = fixFolderInput(Dialog.getString());
		bleach_correct = Dialog.getChoice;
		projection = Dialog.getChoice();
		overwrite = Dialog.getChoice;
		
}

/* Convert backslash to slash in the folder path, append a slash at the end.
 * If analysis is run from within the data folder, move one level up.
 * These fixes are requird for the macro to work properly.
 */
function fixFolderInput(folder_input){
	folder_fixed = replace(folder_input, "\\", "/");
	if (!endsWith(folder_fixed, "/"))
		folder_fixed = folder_fixed + "/";
	if (indexOf(File.getName(folder_input), "data") == 0)
		folder_fixed = File.getParent(folder_fixed) + "/";
	return folder_fixed;
}


function initialize(){
	// count the number of images to be processed (used for the status window) - those that have an extension listed in the 'extension_list' array variable (line 18)
	if (countFiles(dir) == 0)
		exit("Nothing to process. Check that images to be processed are stored in directories whose names end with \"-raw\", and that the extension of your files in included in the 'extension_list' variable on line 18 of the code.");

	// create a status text window where the progress of the macro is reported
	run("Text Window...", "name=[Status] width=100 height=3");
}

/****************************************************************************************************************************************************/
/* BASIC STRUCTURE FOR RECURSIVE DATA PROCESSING
 *
 * Makes a list of contents of specified folder (folders and files) and goes through it one by one.
 * If it finds another directory, it enters it and makes a new list and does the same. In this way, it enters all subdirectories and looks for files.
 * If a list item is an image of type specified in the 'extension_list', it runs processFile() with selected process on that image file.
 */
function processFolder(dir){
	list = getFileList(dir);
	for (i = 0; i < list.length; i++){
		if (endsWith(list[i], "/")) // if the list item is a folder, go in and get a list of items
			processFolder("" + dir + list[i]);
		else {	// if an item is not a folder, it is a file - get its name with the whole path
			if (endsWith(dir, dir_type)){ // if the folder name ends with a string assigned to the dir_type variable
				showProgress(n + + , count);
				q = dir + list[i];
				extIndex = lastIndexOf(q, ".");
				ext = substring(q, extIndex + 1); // store file extension of file "q" into the "ext" variable
				// process file if its extension corresponds to any of those stored in the 'extension_list' variable
				// exclude files that are in a folder whose name contains "exclude"
				if (contains(extension_list, ext) && indexOf(dir, "exclude") < 0){
					getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
					// inform user about progress
					print("[Status]", "Processing: " + n + "/" + count + " - " + list[i] + " (" + String.pad(hour,2) + ":" + String.pad(minute,2) + ":" + String.pad(second,2) + ")\n");
					processFile(q); // run the procesFile(q) function with the image pointed to by the variable 'q'
				}
			}
		}
	}
}

// the following operations are performed with each image
function processFile(q){
	prepareFolders();
	open(q);
	rename(image_name);
	removeBlackSlices();
	correctDriftAndBleaching();
	rename("merged");
	calculateProjections();
	close("*");
}

function prepareFolders(){
	// Check if the required directories exist. If not, create them. The corrected images will be stored in these.
	dir_projections = File.getParent(dir) + "/" + replace(File.getName(dir), "-raw", "-projections") + "/";
	dir_data = File.getParent(dir) + "/" + replace(File.getName(dir), "-raw", "-processed") + "/";
	if (!File.exists(dir_data))
		File.makeDirectory(dir_data);
	if (!File.exists(dir_projections) && (projection != "none"))
		File.makeDirectory(dir_projections);
}

function removeBlackSlices(){
	getDimensions(width, height, channels, slices, frames);
	// check the image series (starting at the end). If a slice is blank (can result from aborted z-stacks or time series), delete it.
	for (s = channels*slices; s >= 1; s--){
		setSlice(s);
		run("Clear Results");
		run("Measure");
		MAX = getResult("Max", 0);
			if (MAX == 0){
				run("Delete Slice", "delete=slice");
				for (c = 1; c < channels; c++)
					s--;
			// stop checking when a non-blank slice is encountered
			} else
				break;
	}
}	

function correctDriftAndBleaching(){
// perform 1. drift and 2. bleach correction separately for each channel, then put the channels back together
	if (!File.exists(dir_data + list[i] + "-processed.tif") || overwrite == "yes"){
		if (channels > 1)
			run("Split Channels");
		for (j = 1; j <= channels; j++){
			temp_image_name = image_name;
			if (channels > 1)
				temp_image_name = "C" + j + "-" + image_name;
			selectImage(temp_image_name);

			if (bleach_correct != "none"){
				selectWindow(temp_image_name);
				if (slices*channels > 1)
					run("Bleach Correction", "correction=[" + bleach_correct + "]");
			}
			
//			run("StackReg", "transformation=[Translation]"); // Enable the BIG-EPFL update site to gain access to the StackReg plugin.
			run("StackReg ", "transformation=Translation");
			if (selectionType >= 0)
				autocrop(temp_image_name); // function defined below that crops the image to olny keep the parts that were imaged in each frame of the series; required for the bleach correction to work properly
			// perform bleach correction using selected algorithm, if desired

			if (bleach_correct != "none"){
				selectWindow(temp_image_name);
				if (slices*channels > 1)
					run("Bleach Correction", "correction=[" + bleach_correct + "]"); //creates a duplicate image with "DUP_" prefix
				close(temp_image_name);
				selectWindow("DUP_" + temp_image_name);
				rename(temp_image_name);
			}
		}
		// put the processed channels back together, save the result and rename the image for further work
		if (channels > 1)
			run("Merge Channels...", "c1=[C1-image] c2=[C2-image] create"); //this merges the channel in a way that red is ch1 and green is ch2
		saveAs("TIFF", dir_data + list[i] + "-processed");
	}
}

function calculateProjections(){
	// calculate selected projections
	if (projection == "AVERAGE" || projection == "all"){ // calculate AVG projection if "AVG" or "all" was selected in the initial dialog window
		selectWindow("merged");
		run("Duplicate...", "duplicate");
		run("Z Project...", "projection=[Average Intensity]");
		saveAs("TIFF", dir_projections + list[i] + "-AVG");
		close();
	}
	if (projection == "MAX" || projection == "all"){ // calculate MAX projection if "MAX" or "all" was selected in the initial dialog window
		selectWindow("merged");
		run("Duplicate...", "duplicate");
		run("Z Project...", "projection=[Max Intensity]");
		saveAs("TIFF", dir_projections + list[i] + "-MAX");
		close();
	}
	if (projection == "SUM" || projection == "all"){ // calculate SUM projection if "SUM" or "all" was selected in the initial dialog window
		selectWindow("merged");
		run("Duplicate...", "duplicate");
		run("Z Project...", "projection=[Sum Slices]");
		saveAs("TIFF", dir_projections + list[i] + "-SUM");
		close();
	}
}
// function to crop the image to only keep the parts that were imaged in each frame of the series
function autocrop(j_img){
	selectImage(j_img);
	// flatten channel j using the Minimum intensity projection to uncover if there are any areas with no signal at the borders of any of the slices in the series
	run("Z Project...", "projection=[Min Intensity]");
	rename("MIN_project");
	// check intensity in bottom-right and top-left corner. If it equals 0 (i.e., there is no signal), use the magic wand to select the area with zero intensity (typically L shapes),
	// then create a selection, revert it and crop the original image series to this selection
	for (k = 1; k >= 0; k--){
		selectWindow("MIN_project");
		doWand(k*(width-1), k*(height-1));
		run("Clear Results");
		run("Measure");
		MIN = getResult("Min", 0);
		if (MIN == 0){
			selectImage(j_img);
			run("Restore Selection");
			run("Make Inverse");
			run("Crop");
		}
	}
}

// helper function
// check if an array contains a specified string; can be used for subsetting
function contains(array, value){
	for (i = 0; i < array.length; i++)
		if (array[i] == value) return true;
 	return false;
}

// count all files that satisfy the given conditions of placement (in a dir ending with "-raw") and extension (in the 'extension_list' variable)
function countFiles(dir){
	list = getFileList(dir);
	// same basic concept and structure as the proccessFolder(dir) function above
	for (i = 0; i < list.length; i++){
		if (endsWith(list[i], "/"))
			countFiles("" + dir + list[i]);
		else {
			q = dir + list[i];
			extIndex = lastIndexOf(q, ".");
			ext = substring(q, extIndex + 1);
			if (contains(extension_list, ext) && endsWith(dir, dir_type))
				count++;
		}
	}
	return count;
}

/* Close all open image windows and specific text windows that might be open. */
function closeAllWindows(){
	close("*");
	windows_list = newArray("ROI Manager", "Log", "Results", "Debug");
	for (i = 0; i < windows_list.length; i++){
		if (isOpen(windows_list[i]))
			close(windows_list[i]);
	}
	if(isOpen("Status"))
		print("[Status]","\\Close");
}

function wrapUp(){
	setBatchMode(false);
	waitForUser("Finito! All images were processed sucessfully.");
}