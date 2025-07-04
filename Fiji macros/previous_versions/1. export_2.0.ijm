// *****************************************************************
// * title: "Export raw images to TIFF" 						   *
// * author: Jakub Zahumensky; e-mail: jakub.zahumensky@iem.cas.cz *
// * - Department of Functional Organisation of Biomembranes       *
// * - Institute of Experimental Medicine CAS                      *
// * - citation: doi: https://doi.org/10.1101/2024.03.28.587214)   *
// *****************************************************************
//
// SUMMARY:
//
// This macro exports microscopy image files to tiff format. This is required for segmentation in CellPose.
// Contrast can be adjusted before the export, which may aid the segmentation. Such images cannot be used for analysis.
// Images (with the file extension listed in the extension_list variable below) in any folder with "data" in the folder name will be processed.

setBatchMode(true); // starts batch mode, i.e. no images are shown on the screen during the macro run; works faster
var extension_list = newArray("czi", "oif", "lif", "vsi"); // only files with these extensions will be processed; if your microscopy images are in a different format, add the extension to the list
var count = 0; // variable used to store how many images were processed, used for the status message
output_format = "TIFF";
version = 2;

// Creates dialog window with the name "Batch export"; includes a help message
help = "<html>"
	+"<b>Directory</b><br>"
	+"Specify the directory where you want <i>Fiji</i> to start looking for folders with images. "
	+"The macro works <u>recursively</u>, i.e., it looks into all subfolders. All folders with names <u>containing</u> the word \"<i>data</i>\" are processed. "
	+"The exception to this are flders containing the word \"<i>exclude</i>\"."
	+"All other folders are ignored. Both types of images are exported in a single macro run.<br>"
	+"<br>"
	+"<b>Channel(s)</b><br>"
	+"Specify the channels (range or comma separated) to be exported. <br>"
	+"<br>"
	+"<b>Adjust contrast</b><br>"
	+"Tick the box and input Min and Max values for the contrast adjustment to take effect. Works for images with bit-depth up to 16.<br>"
	+"</html>";
Dialog.create("Batch export");
	Dialog.addDirectory("Directory:", "");
	Dialog.addString("Channel(s) range:", "1-2");
	Dialog.addCheckbox("Adjust contrast (optional):", false);
	Dialog.addNumber("Min:","0");
	Dialog.addToSameRow();
	Dialog.addNumber("Max:","65535");
	Dialog.addMessage("Click \"Help\" for more information on the parameters.");
	Dialog.addHelp(help);
	Dialog.show();
	dir = replace(Dialog.getString(), "\\", "/");
	ch = Dialog.getString();
	adjust_contrast = Dialog.getCheckbox();
	Min = Dialog.getNumber();
	Max = Dialog.getNumber();

// calling function called “processFolder”
processFolder(dir);

// Definition of "processFolder" function:
// Makes a list of contents of specified folder (folders and files) and goes through it one by one.
// If it finds another directory, it enters it and makes a new list and does the same. In this way, it enters all subdirectories and looks for files.
// If a list item is an image of type specified in the 'extension_list', it runs processFile() on that image file.
function processFolder(dir) {
	list = getFileList(dir);
	for (i = 0; i < list.length; i++) {
		showProgress(i + 1, list.length);
		// if the list item is a folder, go in and get a list of items
		if (endsWith(list[i], "/"))
			processFolder("" + dir + list[i]);
		else {
			if (endsWith(dir, "data/")){
				q = dir+list[i];
				// store file extension of file "q" into the "ext" variable
				extIndex = lastIndexOf(q, ".");
				ext = substring(q, extIndex+1);
				// process file if its extension corresponds to any of those stored in the "extension_list" variable
				// exclude files that are in a folder whose name contains "exclude"
				if (contains(extension_list, ext) && indexOf(dir, "exclude") < 0)
					processFile(q);
			}
		}
	}
}

// definition of "processFile" function:
// following operations are performed with each image that is opened
function processFile(q) {
	// check if the required directory exists. If not, create it. The exported images will be stored there.
	expDir = File.getParent(dir) + "/" + replace(File.getName(dir), "data", "export") + "/";
	if (!File.exists(expDir))
		File.makeDirectory(expDir);
	// open the image to be processed (q=dir+list[i]; see above)
	open(q);
	getDimensions(width, height, channels, slices, frames);
	if (channels > 1)
		run("Make Substack...", "channels=" + ch);
	// if "Adjust contrast (optional):" is ticked in the initial dialog window, adjust contrast according to the specified values
	if (adjust_contrast && bitDepth() <= 16){ // I don't remember the reason for the 16 bit depth limit, but I guess there was one
		setMinAndMax(Min, Max);
		run("Apply LUT");
	}
	saveAs(output_format, expDir+list[i]); // export file as TIFF
	close("*"); // close all open images
	count++;
}

// helper function
// check if an array contains a specified string
function contains(array, value) {
	for (i = 0; i < array.length; i++) 
		if (array[i] == value)	
			return true;
	return false;
}

// end batch mode and tell the user if there were any issues
setBatchMode(false);
if (count == 0)
	waitForUser("Not good","No images were exported. There may be two reasons:\n(1) images are already in TIFF format\n(2) the data structure is incorrect.");
else
	waitForUser("Finito!", count + " files were exported."); // tells user that the macro has finished successfully