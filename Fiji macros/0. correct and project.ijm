// macro takes time-/z-series of images, corrects their drift and saves the corrected image
// it can also perform bleach correction and compute a z-projection - can be selected in the initial dialog window
// The macro uses the StackReg plugin. Enable the BIG-EPFL update site to gain access to it.

setBatchMode(true); // starts batch mode, i.e. no images are shown on the screen during the macro run; works faster
var extension_list = newArray("czi", "oif", "lif", "vsi", "tif"); // only files with these extensions will be processed
var bleach_correction_method = newArray("none", "Histogram Matching", "Simple Ratio"); // there is another bleach correction in ImageJ called "Exponential Fit", but has been omitted here, since it has a tendency to stop the macro
var projection_type = newArray("none", "AVERAGE", "MAX", "SUM", "all"); // options for z-projection after drift (and bleach) correction
var boolean = newArray("no", "yes");
image_name = "image";
n = 0; // initial counter value (used to report the runnin number of the current image)
dir_type = "-raw/"; // only images stored in directories whose names end with "-raw" are processed

// initial environment preparation - close all open images, text windows, results tables etc.
close("*");
close("Log");
close("Results");
if(isOpen("Status"))
	print("[Status]","\\Close");

//create dialog window with the name "Correct drift and bleach, calculate projection"; includes a Help message
help = "<html>"
	+"<b>Directory</b><br>"
	+"Specify the directory where you want <i>Fiji</i> to start looking for folders with images. "
	+"The macro works <u>recursively</u>, i.e., it looks into all subfolders. "
	+"All folders with names <u>ending</u> with \"<i>-raw</i>\" (and only these) are processed. "
	+"All other folders are ignored.<br>"
	+"<br>"
	+"<b>Correct bleaching</b><br>"
	+"Select what algorithm (if any) you wish to use to correct bleaching of your image sequences. "
	+"There is another bleach correction option in ImageJ called \"<i>Exponential Fit</i>\", "
	+"but has been omitted from the selection here, since it has a tendency to stop the macro.<br>"
	+"<br>"
	+"<b>Projection</b><br>"
	+"Select what kind of projection (if any) you wish to compute from your image sequences. "
	+"Only the most common \"<i>MAX</i>\" and \"<i>SUM</i>\" are included here. "
	+"Addition of other options is not straightforward.<br>"
	+"<br>"
	+"<b>Overwrite previously processed images</b><br>"
	+"Choose if you want to overwrite previolsy processed (i.e., drift- and/or bleach- corrected) images). "
	+"These are kept by default, as they are computationaly demanding. "
	+"Note that the filename of the processed image does not include information about bleach corrections.<br>"
	+"</html>";
Dialog.create("Correct drift and bleach, calculate projection");
	Dialog.addDirectory("Directory:", "");
	Dialog.addChoice("Correct bleaching:", bleach_correction_method);
	Dialog.addChoice("Projection:", projection_type);
	Dialog.addChoice("Overwrite previously processed images:", boolean);
	Dialog.addHelp(help);
	Dialog.show();
	// get variable values from the dialog window
	dir = Dialog.getString();
	bleach_correct = Dialog.getChoice;
	projection = Dialog.getChoice();
	overwrite = Dialog.getChoice;

// count the number of images to be processed - those that are stored in the have an extension listed in the extension_list variable
count = countFiles(dir);
if (count == 0)
	exit("Nothing to process. Check that images to be processed are stored in directories whose names end with \"-raw\".");

// create a status text window where the progress of the macro is reported
run("Text Window...", "name=[Status] width=100 height=3");
processFolder(dir);

// definition of "processFolder" function
// makes a list of contents of specified folder and goes through it one by one.
// If list item is a folder, it goes inside and does the same. If list item is an image of type specified in the extension_list, it runs processFile() on that image.
function processFolder(dir) {
	list = getFileList(dir);
	for (i = 0; i < list.length; i++) {
		// if the list item is a folder, go in and get a list of items
		if (endsWith(list[i], "/"))
			processFolder(""+dir+list[i]);
		else {
			if (endsWith(dir, dir_type)){
				showProgress(n++, count);
				q = dir+list[i];
				// store file extension of file "q" into the "ext" variable
				extIndex = lastIndexOf(q, ".");
				ext = substring(q, extIndex+1);
				// process file if its extension corresponds to any of those stored in the "extension_list" variable
				// exlcude files that are in a folder whose name contains "exclude"
				if (contains(extension_list, ext) && indexOf(dir, "exclude") < 0){
					getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
					// inform user about progress
					print("[Status]", "Processing: " + n + "/" + count +" - " + list[i] + " (" + String.pad(hour,2) + ":" + String.pad(minute,2) + ":" + String.pad(second,2) + ")\n");
					processFile(q);
				}
			}
		}
	}
}

// following operations are performed with each image that is opened
function processFile(q) {
	// check if the required directories exist. If not, create them. The corrected images will be stored in these.
	projectionsDir = File.getParent(dir) + "/" + replace(File.getName(dir), "-raw", "-projections")+"/";
	dataDir = File.getParent(dir) + "/" + replace(File.getName(dir), "-raw", "-processed")+"/";
	if (!File.exists(dataDir))
		File.makeDirectory(dataDir);
	if (!File.exists(projectionsDir) && (projection != "none"))
		File.makeDirectory(projectionsDir);
	// open an image (series) to be processed (q=dir+list[i]; see above). Rename it for easier access
	open(q);
	rename(image_name);
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
	// perform drift and bleach correction separately for each channel, then put the channels back together
	if (!File.exists(dataDir + list[i] + "-processed.tif") || overwrite == "yes"){
		run("Split Channels");
		for (j = 1; j <= channels; j++) {
			selectImage("C"+j+"-"+image_name);
			run("StackReg", "transformation=Translation"); // Enable the BIG-EPFL update site to gain access to the StackReg plugin.
			autocrop(j); // function defined below that crops the image to olny keep the parts that were imaged in each frame of the series
			// perform bleach correction using selected algorithm, if desired
			if (bleach_correct != "none"){
				selectWindow("C"+j+"-"+image_name);
				if (slices*channels > 1) run("Bleach Correction", "correction=["+bleach_correct+"]"); //creates a duplicate image with "DUP_" prefix
				close("C"+j+"-"+image_name);
				selectWindow("DUP_C"+j+"-"+image_name);
				rename("C"+j+"-"+image_name);
			}
		}
		// put the processed channels back together, save the result and rename the image for further work
		run("Merge Channels...", "c1=[C1-image] c2=[C2-image] create"); //this merges the channel in a way that red is ch1 and green is ch2
		saveAs("TIFF", dataDir + list[i] + "-processed");
	}
	rename("merged");
	
	// calculate selected projections
	if (projection == "AVERAGE" || projection == "all"){ // calculate MAX projection if "MAX" or "all" was selected in the initial dialog window
		selectWindow("merged");
		run("Duplicate...", "duplicate");
		run("Z Project...", "projection=[Average Intensity]");
		saveAs("TIFF", projectionsDir + list[i] + "-AVG");
		close();
	}
	if (projection == "MAX" || projection == "all"){ // calculate MAX projection if "MAX" or "all" was selected in the initial dialog window
		selectWindow("merged");
		run("Duplicate...", "duplicate");
		run("Z Project...", "projection=[Max Intensity]");
		saveAs("TIFF", projectionsDir + list[i] + "-MAX");
		close();
	}
	if (projection == "SUM" || projection == "all"){ // calculate SUM projection if "SUM" or "all" was selected in the initial dialog window
		selectWindow("merged");
		run("Duplicate...", "duplicate");
		run("Z Project...", "projection=[Sum Slices]");
		saveAs("TIFF", projectionsDir + list[i] + "-SUM");
		close();
	}
	run("Z Project...", "projection=[Average Intensity]");
	close("*");
}

// function to crop the image to only keep the parts that were imaged in each frame of the series
function autocrop(j) {
	selectImage("C"+j+"-"+image_name);
	// flatten channel j using the Minimum intensity projection
	run("Z Project...", "projection=[Min Intensity]");
	rename("MIN_project");
	// check intensity in bottom-right and top-left corner. If it equals 0 (i.e., there is no signal), use the magic wand to select the area with zero intensity (typically L shapes),
	// then create a selection, revert it and crop the original image series to this selection
	for (k = 1; k >= 0; k--) {
		selectWindow("MIN_project");
		doWand(k*(width-1), k*(height-1));
		run("Clear Results");
		run("Measure");
		MIN = getResult("Min", 0);
		if (MIN == 0) {
			selectImage("C"+j+"-"+image_name);
			run("Restore Selection");
			run("Make Inverse");
			run("Crop");
		}
	}
}

// check if an array contains a specified string
function contains(array, value) {
    for (i = 0; i < array.length; i++)
        if (array[i] == value) return true;
    return false;
}

// count all files that satisfy the given conditions of placement (in a dir ending with "-raw") and extension
function countFiles(dir) {
	list = getFileList(dir);
	// same basic concept and structure as the proccessFolder(dir) function above
	for (i = 0; i < list.length; i++) {
		if (endsWith(list[i], "/"))
			countFiles(""+dir+list[i]);
		else {
			q = dir+list[i];
			extIndex = lastIndexOf(q, ".");
			ext = substring(q, extIndex+1);
			if (contains(extension_list, ext) && endsWith(dir, dir_type)) count++;
		}
	}
	return count;
}

// clean up and exit batch mode
close("Log");
close("Results");
print("[Status]","\\Close");
setBatchMode(false);
// inform the user that all images have been processed
waitForUser("Finito! All images were processed sucessfully.");
