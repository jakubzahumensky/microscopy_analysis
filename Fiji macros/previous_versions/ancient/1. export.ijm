setBatchMode(true); // starts batch mode
var extension_list = newArray("czi", "oif", "lif", "vsi"); // only files with these extensions will be processed
var counter = 0;

help = "<html>"
	+"<b>Directory</b><br>"
	+"Specify the directory where you want <i>Fiji</i> to start looking for folders with images. "
	+"The macro works <u>recursively</u>, i.e., it looks into all subfolders. All folders with names <u>ending</u> with the word \"<i>data</i>\" "
	+"(for <i>transversal</i> image type) or \"<i>data-caps</i>\" (for <i>tangential</i> image type) are processed. "
	+"All other folders are ignored. Both types of images are exported in a single macro run.<br>"
	+"<br>"
	+"<b>Channel</b><br>"
	+"Specify image channel to be exported. Macro needs to be run separately for individual channels.<br>"
	+"<br>"
	+"<b>Adjust contrast</b><br>"
	+"Input Min and Max values for contrast adjustment. If no contrast changes are desired before export, use default values. These work for images with bit-depth up to 16.<br>"
	+"</html>";

	Dialog.create("Batch export"); // Creates dialog window with the name "Batch export"
	Dialog.addDirectory("Directory:", "");	// Asks for directory to be processed. Copy paste your complete path here
	Dialog.addNumber("Channel:", 1); // Asks which channel should be exported. 1 as default.
	Dialog.addMessage("Adjust contrast (optional):");
	Dialog.addNumber("Min:","0");
	Dialog.addToSameRow();
	Dialog.addNumber("Max:","65535");
	Dialog.addHelp(help);
    Dialog.show();
	dir = Dialog.getString();
	ch = Dialog.getNumber();
	Min = Dialog.getNumber();
	Max = Dialog.getNumber();

// calling function called “processFolder”
processFolder(dir);

// definition of "processFolder" function
// makes a list of contents of specified folder and goes through it one by one.
// If list item is a folder, it goes inside and does the same. If list item is an image in either CZI or OIF format, it runs processFile() on that image.
function processFolder(dir) {
   list = getFileList(dir);
   for (i=0; i<list.length; i++) {
      showProgress(i+1, list.length);
      if (endsWith(list[i], "/"))
         processFolder(""+dir+list[i]);
      else {
		 q = dir+list[i];
         processFile(q);
      }
   }
}

// definition of "processFile" function
function processFile(q) {
//	if (endsWith(q, "."+ext1)||endsWith(q, "."+ext2)||endsWith(q, "."+ext3)) {
	extIndex = lastIndexOf(q, ".");
	ext = substring(q, extIndex+1);
	if (contains(extension_list, ext) && (indexOf(dir, "exclude") < 0)) {
		expDir = File.getParent(dir)+"/"+replace(File.getName(dir), "data", "export")+"/";
		if (!File.exists(expDir))
			File.makeDirectory(expDir); // create "export" directory
        open(q);
        run("Duplicate...", "duplicate channels=" + ch); // duplicate specified channel as new image
		if (bitDepth() <= 16){
			run("Apply LUT");
			setMinAndMax(Min, Max);
		}
		run("Grays");
		saveAs("TIFF",expDir+list[i]); // save duplicate as TIFF
		close("*"); // close all open images
		counter++;
	}
}

function contains(array, value) {
    for (i=0; i<array.length; i++) 
        if (array[i] == value) return true;
    return false;
}

setBatchMode(false); // ends batch mode
if (counter == 0)
	waitForUser("Not good","No images were exported. There may be two reasons:\n(1) images are already in TIFF format\n(2) the data structure is incorrect.");
else
	waitForUser("Finito!", counter + " files were exported."); // tells user that the macro has finished successfully