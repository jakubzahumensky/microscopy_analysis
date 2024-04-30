//////////////////////////////////////////////////////////////////////////////////
// SUMMARY:
//
// this macro does tho things:
// 1. convert masks from CellPose to ROIs with the "Convert Masks to ROIs" option
// 2. check and adjust these ROIs using the "Check and adjust ROIs"
// while these are two considerably different tasks, they use the same structure and work with the same files. For this reason they are included in a single macro
//
// additional plugins required:
// LabelMap to ROI Manager (2D) - add SCF-MPI-CBG update site
//////////////////////////////////////////////////////////////////////////////////

//maskSuffix = newArray("_cp_masks.png", "_cp_masks.tif");
maskSuffix = "_cp_masks.png";

var border = 0.3; // Used to automatically remove ROIs of incomplete objects. Value needs to be adjusted based on actual microscopy images
// initialization of variables used in functions below; values of all these change below
var title = "";
var width = 0;
var height = 0;
var channels = 0;
var pixelWidth = 0;
var pixelHeight = 0;
var roiDir = ""; // directory where ROIs are stored
var excludeDir = ""; // during checking and adjusting of ROIs, an image can be marked to be excluded from the analysis. It is then moved to a directory as defined in the "excludeDir" variable
//var masksDir = ""; // directory where (CellPose) segmentation Masks are stored
var dirType = ""; // tangential / transversal - code requires a bit of an overhaul for wider audience
var count = 0; // number if images to be processed
var counter = 1; // variable used to store how many images have been processed

var RoiSet_suffix = "-RoiSet.zip";
var files_with_ROIs = ""; // list of files that do not have defined ROIs
var overwrite = 1; // overwrite = yes
var exclude = false; // variable used to mark an image to be excluded from the analysis
var jump = 0;

var extension_list = newArray("czi", "oif", "lif", "tif", "vsi"); // only files with these extensions will be processed
var processes = newArray("Convert Masks to ROIs", "Check and adjust ROIs"); // possible operations to choose from in the dialog window below
var image_types = newArray("transversal", "tangential"); // two image types can be selected
var dummy_name = "Image name hidden"; // used to mask the name of the displayed image when the "blind experimenter" option is selected
boolean = newArray("yes","no");

// create a dialog window called "Select experiment directory, process and image type", including a help message that explains all parameters
help = "<html>"
	+"<b>Directory</b><br>"
	+"Specify the directory where you want <i>Fiji</i> to start looking for folders with images. "
	+"The macro works <u>recursively</u>, i.e., it looks into all subfolders. All folders with names <u>ending</u> with the word \"<i>data</i>\" "
	+"(for <i>transversal</i> image type) or \"<i>data-caps</i>\" (for <i>tangential</i> image type) are processed. "
	+"All other folders are ignored.<br>"
	+"<br>"
	+"<b>Subset</b> <i>(optional)</i><br>"
	+"If used, only images with filenames containing specified <i>string</i> (i.e., group of characters and/or numbers) will be processed. "
	+"This option can be used to selectively process images of a specific strain, condition, etc. "
	+"Leave empty to process all images in specified directory (and its subdirectories).<br>"
	+"<br>"
	+"<b>Channel</b><br>"
	+"Specify channel to be used for displaying of images to check ROIs. Same ROIs are used for all channels during analysis. "
	+"Drift correction is recommended before performing ROI checking (best practice is to perform drift correction before segmentation). <br>"
	+"<br>"
	+"<b>Image type</b><br>"
	+"Select if your images represent <i>transversal</i> (also called <i>equatorial</i>) or <i>tangential</i> sections of the cells.<br>"
	+"<br>"
	+"<b>Process</b><br>"
	+"&#8226; <i>Convert Masks to ROIs</i> - select if you want to create ROIs from <i>Masks</i> created by <i>Cellpose</i> (or another software).<br>"
	+"&#8226; <i>Check ROIs</i> - select if you want to check the accuracy of ROIs created by <i>Convert Masks to ROIs</i>.<br>"
	+"<br>"
	+"<b>Convert ROIs to ellipses</b><br>"
	+"The transversal sections of budding yeast cells can be approximated with ellipses, which makes it easier to change their size and shape by the user during ROI checking. "
	+"This option is not recommended for cell types with complex morphology.<br>"
	+"<br>"
	+"<b>Blind experimenter</b><br>"
	+"Randomizes the order in which images are shown to the experimenter and hides their names (metadata are not changed). "
	+"Also hides information about the parent folder in the <i>ROI adjust</i> dialog window.<br>"
	+"<br>"
	+"<b>Save preview ROIs (tangential only)</b><br>"
	+"The ROIs defined here for tangential images are made slightly smaller for the actual analysis. This helps prevent the inclusion of background in the ROIs, "
	+"which would have detrimental effects on the estimation of the number, shape and size of the microdomains. It also eliminates the microdomains at the cell equator "
	+"(when z-projections are used), which are orientated at a right angle to the focal plane. The preview images are stored in the <i>ROIs_preview</i> folder.<br>"
	+"</html>";
Dialog.create("Select experiment directory, process and image type");
	Dialog.addDirectory("Directory:", "");
	Dialog.addString("Subset (optional):", "");
	Dialog.addNumber("Channel:", 1);
	Dialog.addChoice("Image type:", image_types);
	Dialog.addChoice("Process:", processes);
	Dialog.addChoice("Convert ROIs to ellipses (e.g., for budding yeast)", boolean, "yes");
	Dialog.addChoice("Blind experimenter", boolean, "no");
	Dialog.addChoice("Save preview ROIs (tangential only)", boolean, "no");
	Dialog.addMessage("Click \"Help\" for more information on the parameters.");
	Dialog.addHelp(help);
	Dialog.show();
	dir = replace(Dialog.getString(), "\\", "/");
	subset = Dialog.getString();
	ch = Dialog.getNumber();
	image_type = Dialog.getChoice();
	process = Dialog.getChoice();
	ellipses = Dialog.getChoice();
	blind = Dialog.getChoice();
	save_preview = Dialog.getChoice();

// prepare the work environment
// define what parameters are to be measured with all the run("Measure") commands below
run("Set Measurements...", "area mean min standard modal bounding centroid fit shape redirect=None decimal=5");
// count how many files are to be processed - this is then displayed in the dialog window then ROIs are checked and adjusted - just to inform the user how far there is still to go
// if count = 0, macro is stopped and the user informed that there is some issue
countFiles(dir); // count = countFiles(dir)??? - I think this cannot be used here for some reason I don't remember
if (count == 0)
	exit("There are no images to process. Check that the appropriate 'Image type' was selected and that the used file structure is correct.");
if (isOpen("Status"))
	print("[Status]","\\Close");
if (isOpen("Log"))
	close("Log");
close("*");

// preparation for the selected process
// if conversion of masks to ROIs is selected, macro looks inside the structure and checks if ROIs already exists. User is then prompted to chose how they want to proceed - overwrite them or not
// if ROI check is selected, an information window comes up with guidelines on how to prepare the ROIs; the user is informed if there are images without defined ROIs. These images are listed in a log window
// the macro can be continued, whereupon only images with existing ROIs will be showed for inspection. The missing ROIs can be converted from segmentation masks later and checked by running the ROI check option again
// in this case, all images will be shown again, including those already checked
if (matches(process, "Convert Masks to ROIs")){
	setBatchMode(true);
	RoiSet_count = countRoiSetFiles(dir, true); // count files that HAVE defines ROIs (i.e., option TRUE is used)
	if (isOpen("Log") && RoiSet_count > 0){
		files_with_ROIs = getInfo("Log");
		if (getBoolean("WARNING!\n"+RoiSet_count+ " of "+ count +" images already have defined sets of ROIs (listed in the Log window).\nDo you wish to overwrite the existing ROI sets?") == 0){
			overwrite = 0; // i.e., do not overwrite if user selects "no" in response to the warning message above
			count = count - RoiSet_count;
		}
	}
	run("Text Window...", "name=[Status] width=40 height=2");
	close("Log");
} else {
	missing_RoiSet_count = countRoiSetFiles(dir, false); // count files that DON NOT HAVE defines ROIs (i.e., option FALSE is used)
	if (missing_RoiSet_count > 0)
		if (getBoolean("WARNING!\n" + missing_RoiSet_count + " images do not have defined sets of ROIs (listed in the Log window).\nDo you wish to continue?") == 0)
			exit("Macro terminated by the user.");
	count = count - missing_RoiSet_count;
	html_ROIs = "<html>"
	+"The lines defining the edges of ROIs need to be placed:<br>"
	+"<i>in transversal images</i>:<br>"
	+"&#8226; in the <b>middle</b> of the plasma membrane for <b>plasma membrane proteins</b> (Fig. 1)<br>"
	+"&#8226; on the <b>edge</b> of the visible cell for <b>cytoplasmic proteins</b> (Fig. 2)<br>"
	+"<i>in tangential images</i>:<br>"
	+"&#8226; on the <b>edge</b> of the visible cell (Fig. 3)<br>"
	+"<br>"
	+"<img src=\"https://raw.githubusercontent.com/jakubzahumensky/testing/main/Fig.1.png?raw=true\" alt=\"Fig 1\" width=256 height=256> <b>Fig. 1</b> "
	+"<img src=\"https://raw.githubusercontent.com/jakubzahumensky/testing/main/Fig.2.png?raw=true\" alt=\"Fig 2\" width=256 height=256> <b>Fig. 2</b> "
	+"<br>"
	+"<img src=\"https://raw.githubusercontent.com/jakubzahumensky/testing/main/Fig.3.png?raw=true\" alt=\"Fig 3\" width=256 height=256> <b>Fig. 3</b> "
	+"<br>"
	+"<i>ROIs deviating from these guidelines will result in incorrect quantification.</i><br>"
	+"</html>";
	showMessage("Important note on ROI placement", html_ROIs);
}

processFolder(dir);

// Definition of "processFolder" function: starts in selected directory, makes a list of what is inside then goes through it one by one
// If it finds another directory, it enters it and makes a new list and does the same.
// In this way, it enters all subdirectories and looks for data.
function processFolder(dir){
	list = getFileList(dir);
	// if "blind experimenter" is checked, the the images are displayed in randomized order for checking of ROIs (directories are randomized; then files within individual directories)
	// this only has an effect for the "Check and adjust ROIs" option
	if (blind == "yes")
		list = randomize(list);
	for (i = 0; i < list.length; i++){
		showProgress(i+1, list.length);
		// if the list item is a folder, go in and get a list of items
      	if (endsWith(list[i], "/"))
      		processFolder("" + dir + list[i]);
      	else {
			file = dir + list[i];
			if (File.exists(file)){ // HOW COULD IT NOT EXIST??? I don't understand this, but I must have put it here for a reason
				// check if the selected file is in the selected folder (for transversal/tangential images) and belongs to the selected subset
				if (endsWith(dir, image_type + "/data/") && indexOf(file, subset) >= 0){
					extIndex = lastIndexOf(file, ".");
					ext = substring(file, extIndex+1);
					// process file if its extension corresponds to any of those stored in the "extension_list" variable
					if (contains(extension_list, ext)){
						title = File.getNameWithoutExtension(file);
						// if conversion of masks to ROIs is selected, perform it
						// this runs in batch mode, i.e., no images are shown to the user; to enable progress monitoring, a status window is shown with a file counter
						if (matches(process, "Convert Masks to ROIs")){
							if ((overwrite == 1) || ((overwrite == 0) && indexOf(files_with_ROIs, dir + title) < 0)){
								print("[Status]", "\\Update:" + "Processing: " + counter + "/" + count);
								Map_to_ROIs();
							}
						}
						else
						// run ROI_check function and return the counter i - under normal circumstances it is the same as the input value of i;
						// however, there is an option to jump foward/backward by a selected number of images, which needs to be reflected in the counter
						i = ROI_check(i);
					}
				}
			}
		}
	}
}

// count how many files there are to be processed (according to the selected image type and subset)
function countFiles(dir){
	list = getFileList(dir);
	for (i = 0; i < list.length; i++){
		if (endsWith(list[i], "/"))
			countFiles("" + dir + list[i]);
		else {
			file = dir + list[i];
			if (endsWith(dir, image_type + "/data/") && indexOf(file, subset) >= 0){
				extIndex = lastIndexOf(file, ".");
				ext = substring(file, extIndex+1);
				if (contains(extension_list, ext))
					count++;
			}
		}
	}
}

// count how many images have defined ROIs. This is used for 2 things:
// 1. to find out if some images already have ROIs when the Convert masks to ROIs option is selected, and give a warning if yes
// 2. to notify the user while checking the ROIs if there are any images without defined ROIs
function countRoiSetFiles(dir, boo){
	RS_count = 0;
	list = getFileList(dir);
	for (i = 0; i < list.length; i++){
		if (endsWith(list[i], "/"))
			countRoiSetFiles("" + dir + list[i], boo);
		else {
			file = dir + list[i];
			if (endsWith(dir, image_type + "/data/") && indexOf(file, subset) >= 0){
				extIndex = lastIndexOf(file, ".");
				ext = substring(file, extIndex+1);
				if (contains(extension_list, ext)){
					roiDir = File.getParent(dir)+"/"+replace(File.getName(dir), "data", "ROIs")+"/";
					title = File.getNameWithoutExtension(file);
					if (File.exists(roiDir + title + RoiSet_suffix) == boo){
						RS_count++;
						print(file);
					}
				}
			}
		}
	}
	return RS_count;
}

// check if an array contains a specified string (value)
function contains(array, value){
    for (i = 0; i < array.length; i++)
        if (array[i] == value)
        	return true;
    return false;
}

// randomize the items in an array
// this allows the macro to display the images for ROI checking in a random order when "blind experimenter" is checked in the initial Dialog window
function randomize(array){
	new_array = newArray(array.length);
	control_array = newArray(array.length);
	for (i = 0; i < array.length; i++){
	  	n = floor((array.length+1)*random);
	  	// if the selected item number is already in the control array, chose another one; Do this until an item not already in the control array is selected
	    while (contains(control_array, n))
	    	n = floor((array.length+1)*random);
	    control_array[i] = n; // this array stores the positions in the input array that have already been put at a new position in the new_array
	    new_array[i] = array[n-1]; // new, randomized array
	}
	return new_array;
}

// preparatory step where image suffix (extension) is removed from filename. This makes the steps below simpler and more universal.
// user-specified channel is selected in "color" display mode
function prep(){
	open(file);
	getDimensions(width, height, channels, slices, frames);
	getPixelSize(unit, pixelWidth, pixelHeight);
   	if (channels >= ch)
		Stack.setChannel(ch);
	if (channels > 1)
		Stack.setDisplayMode("color");
   	rename(list[i]);
	dummy_name = i; // when experimenter blinding is used, the current number is displayed instead of the image title
}

//conversion of the LabelMap masks made in Cellpose to ROIs; macro calls the "LabelMap to ROI Manager (2D)" that is part of the SCF plugin package (available at: https://sites.imagej.net/SCF-MPI-CBG/plugins/)
function Map_to_ROIs(){
	// the segmentation masks may be stored in a dir called "Masks" or "masks"; the macro can find either
	tempDir = File.getParent(dir)+"/"+replace(File.getName(dir), "data", "Masks")+"/";
	masksDir = File.getParent(dir)+"/"+replace(File.getName(dir), "data", "masks")+"/";
	if (File.exists(tempDir))
		File.rename(tempDir, masksDir);
	if (File.exists(masksDir + title + maskSuffix)){
		prep(); //Map_to_ROIs calls the prep() function
		roiDir = File.getParent(dir)+"/"+replace(File.getName(dir), "data", "ROIs")+"/";
		if (!File.exists(roiDir))
			File.makeDirectory(roiDir);
		run("Clear Results");
		run("Measure");
		open(masksDir + title + maskSuffix);
		roiManager("reset"); // clear ROI manager of anything that might be there from previous work
		run("LabelMap to ROI Manager (2D)");  // for each object in the masks map a ROI is made and put into ROI manager
		selectWindow(list[i]);
		numROIs = roiManager("count"); // find out how many ROIs there are in the ROI manager
	// Automatic cleaning of ROIs:
	// go through all ROIs in the manager one by one, analyze their position, size and CV of fluorescence
	// if ROIs are too close to edges of image (incomplete cells), if they are too small or dead (based on CV measurement), remove the respective ROI from the ROI manager
	// the loop goes backwards because deleting/adding of ROIs changes the ID number of those with higher ID numbers.
	// When counting backwards, these have already been processed when changes are made.
		if (numROIs > 0){
			for (j = numROIs-1; j >= 0 ; j--){
				run("Clear Results");
				roiManager("Select", j);
				run("Measure");
				Mean = getResult("Mean", 0); // mean intensity value
				Min = getResult("Min", 0); // minimum intensity value
				SD = getResult("StdDev", 0); // standard deviation of the mean intensity value
				ROI_width = getResult("Width", 0);
				ROI_height = getResult("Height", 0);
				ROI_origin_x = getResult("BX", 0); // x coordinate of the upper left corner
				ROI_origin_y = getResult("BY", 0);
				ROI_circularity = getResultString("Circ.", 0);
				too_left = ROI_origin_x < border; // equals 1 for a ROI too close to the left image edge
				too_high = ROI_origin_y < border; // equals 1 for a ROI too close to the upper image edge
				too_right = ((ROI_origin_x + ROI_width) > (width*pixelWidth - border)); // equals 1 for a ROI too close to the right image edge
				too_low = ((ROI_origin_y + ROI_height) > (height*pixelHeight - border)); // equals 1 for a ROI too close to the lower image edge
				too_irregular = (ROI_circularity < 0.8);
				// if the ROI is too close to any of the edges, or is too irregular (only if it is to be fitted with an ellipse), remove
				if ((too_right + too_left + too_high + too_low > 0) || (too_irregular && ellipses == "yes"))
					roiManager("Delete"); //if at least one of the listed conditions is TRUE (has value 1), the respective ROI is deleted
				else {
					if (ellipses == "yes")
						run("Fit Ellipse");
					else {
						run("Enlarge...", "enlarge=" + pixelWidth);
						run("Enlarge...", "enlarge=-" + pixelWidth); //this enables the circumference of the selection to be converted to a line
					}
				//create a new selection that is added to the ROI manager and remove the original one
					roiManager("add");
					roiManager("Select", j);
					roiManager("Delete");
				}
			}
			// remove information about the ROIs that would tie them to a specific channel/slice/time frame. This way, same ROIs can be used in all channels
			roiManager("Remove Channel Info");
	        roiManager("Remove Slice Info");
			roiManager("Remove Frame Info");
			numROIs = roiManager("count");
		}
		// if there are no ROIs in the ROI manager, create one of the whole image. If no ROIs are there, macro crashes, as there would be nothing to save in the subsequent step
		if (numROIs == 0){
			makeRectangle(0, 0, 100, 100);
			roiManager("Add");
		}
			roiManager("Save", roiDir + title + RoiSet_suffix); //save the updated list of ROIs
			close("*");
	counter++;
	} else
		print(file); // if the image does not have segmentation masks to be converted to ROIs, do not do anything, just write the image file name in the log window
}

//function ROI_check() opens each raw file in the analysis folder and loads the ROIs made by the Map_to_ROIs() function.
//It then allows the user to check the exiting ROIs, adjust/remove them, or add additional ones.
//Option to enlarge/shrink size of all ROIs is implemented. For shrinking input negative values.
function ROI_check(k){
	// open image, zoom in and select LUT, open existing ROIs that belong to that image and display them all with labels
	// get the name of the image parent directory so it can be displayed in the status window
	roiDir = File.getParent(dir)+"/"+replace(File.getName(dir), "data", "ROIs")+"/";
	if (File.exists(roiDir + title + RoiSet_suffix)){
		prep();
		excludeDir = File.getParent(dir)+"/"+replace(File.getName(dir), "data", "data-exclude")+"/";
		if (blind == "yes")
			rename(dummy_name);
		window = getTitle();
		parent = File.getParent(dir);
		dir_name = File.getName(dir);
		parent_name = File.getName(parent);
		roiManager("reset");
		roiManager("Open", roiDir + title + RoiSet_suffix);
		numROIs = roiManager("count");
		selectWindow(window);
		run("Grays");
		run("Invert LUT");
		run("Set... ", "zoom=200 x=0 y=0");
		setLocation(0, 0, screenWidth*3/4, screenHeight);
		roiManager("Show All with labels");
		roiManager("Set Color", "yellow");
		run("Enhance Contrast", "saturated=0.05");
		if (ellipses == "yes")
			setTool("ellipse");

		// create a non-blocking dialog window that allows the user to move the ROIs (all at the same time) in all directions, make them bigger/smaller,
		// jump forward/backwards and exclude image from analysis
		// while the window is open, the user can remove, add and change the size and shape of induvidual ROIs
		// once "OK" is pressed, the changes are automatically saved
		html = "<html>"
			+"The user can move, delete, add ROIs (regions of interest) and change their size and shape. "
			+"To add new ROIs first make a selection (the elliptical tool is preselected) and then press the \"<i>Add</i>\" button in the ROI manager window or the \"<i>t</i>\" key on the keyboard.<br>"
			+"<b>Note: All changes are automatically saved when <i>\"OK\"</i> is pressed.</b><br>"
			+"<br>"
			+"<b>Stats:</b><br>"
			+"&#8226; <i>folder</i> - current working directory in which images are being processed (hidden when <i>Blind experimenter</i> option is used)<br>"
			+"&#8226; <i>image counter</i> - current image/number of images in <i>folder</i> (current image/all images in all subfolders)<br>"
			+"<br>"
			+"<b>Adjustment options</b><br>"
			+"Entering a non-zero value in any of the following fields changes the ROIs and displays them for assessment.<br>"
			+"&#8226; <i>Enlarge all ROIs</i> - make all ROIs larger by a specified number of pixels in each direction (values as low as 0.5 have an effect). "
			+"(negative values make the ROIs smaller).<br>"
			+"&#8226; <i>Move right</i> - move all ROIs right by a specified number of pixels (negative values move the ROIs left).<br>"
			+"&#8226; <i>Move down</i> - move all ROIs down by a specified number of pixels (negative values move the ROIs up).<br>"
			+"<br>"
			+"<b>Jump forward by</b><br>"
			+"Skip forward by a defined number of images within the current folder (e.g., when resuming a crashed macro run; "
			+"use negative values to return to one of the previous images).<br>"
			+"<br>"
			+"<b>Exclude current image from analysis</b><br>"
			+"If selected, the current image is moved to the <i>data-exclude</i> or <i>data-caps-exclude</i>folder and is excluded from the analysis when run. Can be used e.g. for images with incorrect focus.<br>"
			+"<br>"
			+"<b>Note on ROI placement</b><br>"
			+html_ROIs;
		size_change = 1; // the initial size change is set to a non-zero value so that the dialog window below is shown
		shift_x = 0;
		shift_y = 0;
		size_threshold = 0;
		// as long as at least one of the resize and shift parameters are non-zero, show the dialog window
		while ((size_change != 0) || (shift_x != 0) || (shift_y != 0) || (size_threshold != 0)){
			Dialog.createNonBlocking("Check and adjust ROIs");
			if (blind == "yes"){
				dir_name = "hidden";
				parent_name = dir_name;
			}
			Dialog.addMessage("Stats:\nfolder: \"" + parent_name + "/" + dir_name + "\"" + "\nimage counter: " + i+1 + "/" + list.length + " (" + counter + "/" + count +" total)", 14);
			Dialog.addMessage("Adjust all " + numROIs + " ROIs", 12);
			Dialog.addNumber("Enlarge (neg. values shrink):", 0, 0, 2, "px");
			Dialog.addNumber("Move right (neg. values move left)", 0, 0, 2, "px");
			Dialog.addNumber("Move down (neg. values move up)", 0, 0, 2, "px");
			Dialog.addNumber("Remove all ROIs with area smaller than", 0, 0, 2, "um^2");
		   	Dialog.addNumber("Jump forward by (neg. values jump back)", 0, 0, 2, "images");
		   	Dialog.addCheckbox("Exclude current image from analysis", false);
		   	Dialog.addMessage("Click \"Help\" for more information on the parameters.");
		   	Dialog.setLocation(screenWidth*3.3/4,screenHeight/7);
		    Dialog.addHelp(html);
		    Dialog.show();
			size_change = Dialog.getNumber();
			shift_x = Dialog.getNumber();
			shift_y = Dialog.getNumber();
			size_threshold = Dialog.getNumber();
			jump = Dialog.getNumber();
			exclude = Dialog.getCheckbox();

			// if "exclude" is ticked, move the current file to a "data-exclude" folder; it will be ignored when the analysis is run
			if (exclude == true){
				if (!File.exists(excludeDir))
					File.makeDirectory(excludeDir);
				File.rename(dir + list[k], excludeDir + list[k]);
				close("Log");
			}
			// deselect all ROIs to translate/resize all of them together
			roiManager("deselect");
			roiManager("translate", shift_x, shift_y);
			if (size_change != 0){
				numROIs = roiManager("count");
				for(j = numROIs-1; j >= 0 ; j--){
					roiManager("Select", j);
					if (size_change == -0.5){
						run("Enlarge...", "enlarge=-" + pixelWidth);
						run("Enlarge...", "enlarge=" + 0.5*pixelWidth);
					} else
						run("Enlarge...", "enlarge=" + size_change*pixelWidth);
					if (ellipses == "yes")
						run("Fit Ellipse");
					roiManager("add");
					roiManager("Select", j);
					roiManager("Delete");
				}
			}
			// remove all ROIs smaller than the value specified by the user (stored in the size_threshold variable)
			if (size_threshold != 0){
				numROIs = roiManager("count");
				for(j = numROIs-1; j >= 0 ; j--){
					roiManager("Select", j);
					run("Clear Results");
					run("Measure");
					if (getResult("Area", 0) < size_threshold){
						roiManager("Select", j);
						roiManager("Delete");
					}
				}
			}
		}
		// remove information about the ROIs that would tie them to a specific channel/slice/time frame. This way, same ROIs can be used in all channels
		roiManager("Remove Channel Info");
	    roiManager("Remove Slice Info");
		roiManager("Remove Frame Info");
		roiManager("Save", roiDir + title + RoiSet_suffix);
		if (save_preview == "yes" && matches(image_type, "tangential"))
			ROI_preview();
		close("*");
		counter++;
		k = jump_around(jump);
	}
	return k;
}

// for the analysis of tangential images, the ROIs are made slightly smaller to make sure that background is not included in the analysis
// this also ensures that for z-stask projections the very edges of yeast cells (which are perpendicular to the focal plane) )are exluded
// the shrinking of the ROIs will likely cause issues if used for non-yeast cells
function ROI_preview(){
	roi_previewDir = File.getParent(dir)+"/"+replace(File.getName(dir), "data", "ROIs_preview")+"/";
	if (!File.exists(roi_previewDir))
		File.makeDirectory(roi_previewDir);
	roiManager("Show All without labels");
	numROIs = roiManager("count");
	for(j = numROIs-1; j >= 0 ; j--){
		roiManager("Select", j);
		run("Clear Results");
		run("Measure");
		major_axis = getResult("Major", 0);
		size_change = major_axis/2*(1-sqrt(2/3));
		run("Enlarge...", "enlarge=-" + size_change);
		run("Fit Ellipse");
		roiManager("add");
	}
	saveAs("TIFF", roi_previewDir + title + "-ROIs_preview");
}

// function that allows the user to jump forward/backward by a desired number of images while checking the ROIs
// the counter sometimes gets out of control if the user jumps around too much and too far, but I am unable to fix this at the moment
function jump_around(jump_by){
	if (jump_by > 0){
		if (k + jump_by < list.length){
			counter = counter - 1 + jump_by;
			k = k - 1 + jump_by;
		} else {
			// if the user wants to jump further than the end of current directory, last image in the current directory is displayed
			counter = counter + list.length - k - 2;
			k = list.length - 2;
		}
	}
	if (jump_by < 0){
		if (k + jump_by < 0){
			counter = counter-k-1;
			k = - 1;
		}
		if (k > 0)
			if (File.exists(dir + list[k + jump_by])){
				k = k - 1 + jump_by;
				counter = counter - 1 + jump_by;
			} else {
				k = k - 3 + jump_by;
				counter = counter - 1 + jump_by;
			}
	}
	return k;
}

// close Results table and ROI manager
// inform user if all went well, and give some guidance if there were issues
close("Results");
close("ROI manager");
if (matches(process, "Convert Masks to ROIs")){
	print("[Status]", "\\Close");
	if (counter-1 < count)
		waitForUser("This is curios...", "ROI sets have not been made for " + count-counter+1 + " out of "+ count + " images (listed in the Log window).\n"
		+"Check if you have made segmentation masks for all images and if the data structure is correct before running the macro again.");
	else
		waitForUser("Finito!", "ROI sets for all images were made successfully.");
} else
	waitForUser("Finito!", "All existing ROIs checked and adjusted.");
setBatchMode(false); // exits batch mode (only activated for conversion of Maps to ROIs)
//close("Log");