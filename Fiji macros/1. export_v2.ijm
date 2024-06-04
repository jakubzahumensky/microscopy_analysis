// macro exports microscopy image files to tiff format. This is required for segmentation in CellPose.

setBatchMode(true); // starts batch mode, i.e. no images are shown on the screen during the macro run; works faster
var extension_list = newArray("czi", "oif", "lif", "vsi"); // only files with these extensions will be processed
var count = 0; // variable used to store how many images were processed
output_format = "TIFF";
version = 2;

// Creates dialog window with the name "Batch export"; includes a help message
help = "<html>"
	+"<b>Directory</b><br>"
	+"Specify the directory where you want <i>Fiji</i> to start looking for folders with images. "
	+"The macro works <u>recursively</u>, i.e., it looks into all subfolders. All folders with names <u>ending</u> with the word \"<i>data</i>\" "
	+"(for <i>transversal</i> image type) or \"<i>data-caps</i>\" (for <i>tangential</i> image type) are processed. "
	+"All other folders are ignored. Both types of images are exported in a single macro run.<br>"
	+"<br>"
	+"<b>Channel(s)</b><br>"
	+"Specify the channels (range or comma separated) to be exported. <br>"
	+"<br>"
	+"<b>Adjust contrast</b><br>"
	+"Input Min and Max values for contrast adjustment. If no contrast changes are desired before export, use default values. These work for images with bit-depth up to 16.<br>"
	+"</html>";
Dialog.create("Batch export");
	Dialog.addDirectory("Directory:", "");
	Dialog.addString("Channel(s) range:", "1-2");
	Dialog.addCheckbox("Adjust contrast (optional):", false);
	Dialog.addNumber("Min:","0");
	Dialog.addToSameRow();
	Dialog.addNumber("Max:","65535");
	Dialog.addHelp(help);
	Dialog.show();
	dir = Dialog.getString();
	ch = Dialog.getString();
	adjust_contrast = Dialog.getCheckbox();
	Min = Dialog.getNumber();
	Max = Dialog.getNumber();

// calling function called “processFolder”
processFolder(dir);

// definition of "processFolder" function
// makes a list of contents of specified folder and goes through it one by one.
// If list item is a folder, it goes inside and does the same. If list item is an image of type specified in the extension_list, it runs processFile() on that image.
function processFolder(dir) {
	list = getFileList(dir);
	for (i = 0; i < list.length; i++) {
		showProgress(i+1, list.length);
		// if the list item is a folder, go in and get a list of items
		if (endsWith(list[i], "/"))
			processFolder(""+dir+list[i]);
		else {
			q = dir+list[i];
			// store file extension of file "q" into the "ext" variable
			extIndex = lastIndexOf(q, ".");
			ext = substring(q, extIndex+1);
			// process file if its extension corresponds to any of those stored in the "extension_list" variable
			// exlcude files that are in a folder whose name contains "exclude"
			if (contains(extension_list, ext) && indexOf(dir, "exclude") < 0)
				processFile(q);
		}
	}
}

// definition of "processFile" function
// following operations are performed with each image that is opened
function processFile(q) {
	// check if the required directory exists. If not, create it. The exported images will be stored there.
	expDir = File.getParent(dir)+"/"+replace(File.getName(dir), "data", "export")+"/";
	if (!File.exists(expDir))
		File.makeDirectory(expDir);
	// open the image to be processed (q=dir+list[i]; see above)
	open(q);
	getDimensions(width, height, channels, slices, frames);
	if (channels > 1)
		run("Make Substack...", "channels=" + ch);
	// if "Adjust contrast (optional):" is ticked in the initial dialog window, adjust contrast according to the specified values
	if (adjust_contrast && bitDepth() <= 16){
		setMinAndMax(Min, Max);
		run("Apply LUT");
	}
	saveAs(output_format,expDir+list[i]); // save duplicate as TIFF
	close("*"); // close all open images
	count++;
}

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
