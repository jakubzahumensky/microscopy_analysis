var border = 0.3; //value needs to be adjusted based on actual microscopy images
var title = "";
var roiDir = "";
var MasksDir = "";
var DirType = "";
var count = 0;
var counter = 1;
var px = 0;
var BC_T = 0;
var go_back = false;
var extension_list = newArray("czi", "oif", "lif", "tif", "vsi");
var processes = newArray("Convert Masks to ROIs", "Check ROIs");
var image_types = newArray("Transversal", "Tangential");
var dummy_name = "Image name hidden";
boolean = newArray("yes","no");

help = "<html>"
	+"<b>Directory</b><br>"
	+"Specify the directory where you want <i>Fiji</i> to start looking for folders with images. "
	+"The macro works <u>recursively</u>, i.e., it looks into all subfolders. All folders with names <u>ending</u> with the word \"<i>data</i>\" "
	+"(for <i>transversal</i> image type) or \"<i>data-caps</i>\" (for <i>tangential</i> image type) are processed. "
	+"All other folders are ignored.<br>"
	+"<br>"
	+"<b>Subset</b> <i>(optional)</i><br>"
	+"If used, only images with filenames containing specified <i>string</i> will be processes. This option can be used to selectively process images of a specific strain, condition, etc. "
	+"Leave empty to process all images in specified directory.<br>"
	+"<br>"
	+"<b>Channel(s)</b><br>"
	+"Specify channel to be used for processing. The macro needs to be run separately for individual channels. "
	+"Selection of multiple channels (comma separated, no space) and range (with the use of dash) are supported. <br>"
	+"<br>"
	+"<b>Image type</b><br>"
	+"Select if your images represent <i>transversal</i> (also called <i>equatorial</i>) or <i>tangential</i> sections of the cells.<br>"
	+"<br>"
	+"<b>Process</b><br>"
	+"&#8226; <i>Convert Masks to ROIs</i> - select if you want to create ROIs from <i>Masks</i> created by <i>Cellpose</i> (or another software).<br>"
	+"&#8226; <i>Check ROIs</i> - select if you want to check the accuracy of ROIs created by <i>Convert Masks to ROIs</i>.<br>"
	+"<br>"
	+"<b>Convert ROIs to ellipses</b><br>"
	+"The transversal sections of budding yeast cells can be approximates with ellipses, which makes it easier to change their size and shape. "
	+"This option is not recommended for other cell types.<br>"
	+"<br>"
	+"<b>Blind experimenter</b><br>"
	+"Randomizes the order in which images are shown to the experimenter and hides their names (metadata are not changed). "
	+"Also hides information about the parent folder in the <i>ROI adjust</i> dialog window.<br>"
	+"<br>"
	+"</html>";

Dialog.create("Select experiment directory, process and image type");
	Dialog.addDirectory("Directory:", "");
	Dialog.addString("Subset (optional):", "");
	Dialog.addNumber("Channel:", 1);
	Dialog.addChoice("Image type:", image_types);
	Dialog.addChoice("Process:", processes);
	Dialog.addChoice("Convert ROIs to ellipses (e.g., for budding yeast)", boolean, "yes");
	Dialog.addChoice("Blind experimenter", boolean, "no");
	Dialog.addHelp(help);
	Dialog.show();
	dir = Dialog.getString();
	subset = Dialog.getString();
	ch = Dialog.getNumber();
	image_type = Dialog.getChoice();
	process = Dialog.getChoice();
	ellipses = Dialog.getChoice();
	blind = Dialog.getChoice();

if (matches(image_type, "Tangential"))
	DirType = "data-caps/";
else 
	DirType = "data/";

if (matches(process, "Convert Masks to ROIs"))
	if (getBoolean("WARNING! If ROIs have been made before, they will be overwritten! Continue?") == 0)
		exit("Macro aborted by user.");
	else {
		setBatchMode(true);
		run("Text Window...", "name=[Status] width=20 height=1");
	}	

html_ROIs = "<html>"
	+"The lines defining the edges of ROIs need to be placed:<br>"
	+"&#8226; in the <b>middle</b> of the plasma membrane for <b>plasma membrane proteins</b> (Fig. 1)<br>"
	+"&#8226; on the <b>edge</b> of visible cell for <b>cytoplasmic proteins</b> (Fig. 2)<br>"
	+"<br>"
	+"<img src=\"https://raw.githubusercontent.com/jakubzahumensky/testing/main/Fig.1.png?raw=true\" alt=\"Fig 1\" width=256 height=256> <b>Fig. 1</b> "
	+"<img src=\"https://raw.githubusercontent.com/jakubzahumensky/testing/main/Fig.2.png?raw=true\" alt=\"Fig 2\" width=256 height=256> <b>Fig. 2</b> "
	+"<br>"
	+"<i>ROIs deviating from these guidelines will result in incorrect quantification.</i><br>"
	+"</html>";															
if (matches(process, "Check ROIs")) showMessage("Important note on ROI placement", html_ROIs);

run("Set Measurements...", "area mean min standard modal bounding centroid fit redirect=None decimal=5");
countFiles(dir);
processFolder(dir);

//Definition of "processFolder" function: starts in selected directory, makes a list of what is inside then goes through it one by one
//If it finds another directory, it enters it and makes a new list and does the same.
//In this way, it enters all subdirectories and looks for data.
function processFolder(dir) {
	list = getFileList(dir);
	if (blind == "yes")
		list = randomize(list);
	for (i = 0; i < list.length; i++) {
		showProgress(i+1, list.length);
      	if (endsWith(list[i], "/"))
      		processFolder("" + dir + list[i]);
      	else {
			file = dir + list[i];
			if (indexOf(file, subset) >= 0 && endsWith(dir, DirType)) {
				extIndex = lastIndexOf(file, ".");
				ext = substring(file, extIndex+1);
				if (contains(extension_list, ext)) {
					if (matches(process, "Convert Masks to ROIs")) {
						print("[Status]", "\\Update:" + "Processing: " + counter + "/" + count);
						Map_to_ROIs();
					}
					else
					ROI_check();
					if (go_back == true && i > 0) {
						i = i-2;
						if (ext == "oif") i--;
						go_back = false;
					}
				}
			}	
		}
	}
}

function countFiles(dir) {
	list = getFileList(dir);
	for (i = 0; i < list.length; i++) {
		if (endsWith(list[i], "/"))
			countFiles("" + dir + list[i]);
		else
			if (endsWith(dir, DirType))
				count++;
	}
}

function contains(array, value) {
    for (i = 0; i < array.length; i++) 
        if (array[i] == value) return true;
    return false;
}

function randomize(array) {
	new_array = newArray(array.length);
	control_array = newArray(array.length);
	for (i = 0; i < array.length; i++) {
	  	n = array.length;
	    while (contains(control_array, n))
	    	n = floor(array.length*random);
	    control_array[i] = n;
	    new_array[i] = array[n-1];
	}
   return new_array;
}

//Preparatory step where image suffix (extension) is removed from filename. This makes the steps below simpler and more universal.
function prep() {
	roiDir = replace(dir, "data", "ROIs");
	MasksDir = replace(dir, "data", "Masks");
   	run("Bio-Formats Windowless Importer", "open=[file]");
   	getDimensions(width, height, channels, slices, frames);
	if (channels > 1) Stack.setChannel(ch);
	rename(list[i]);
	title = File.nameWithoutExtension;
	getDimensions(width, height, channels, slices, frames);
//	run("Set Measurements...", "area mean standard modal min redirect=None decimal=5");
	run("Clear Results");
	run("Measure");
	px = sqrt(getResult("Area", 0)/width/height);
}

//conversion of the LabelMap masks made in Cellpose to ROIs; macro calls the "LabelMap to ROI Manager (2D)" that is part of the SCF plugin package (available at: https://sites.imagej.net/SCF-MPI-CBG/plugins/)
function Map_to_ROIs() {
//	if (endsWith(dir, DirType)) {
		prep(); //Map_to_ROIs calls the prep() function
		if (File.exists(roiDir) == 0) 
			File.makeDirectory(roiDir);
	//get image size - used for removing ROIs too close to the edges (incomplete cells)
//		run("Set Measurements...", "area bounding redirect=None decimal=3");
		run("Clear Results");
		run("Measure");
		image_W = getResult("Width", 0);
		image_H = getResult("Height", 0);
		open(MasksDir + title + "_cp_masks.png");
		roiManager("reset"); // clear ROI manager of anything that might be there from previous work
		run("LabelMap to ROI Manager (2D)");  // for each cell in the Cellpose map a ROI is made and put into ROI manager
		selectWindow(list[i]);
		numROIs = roiManager("count"); // find out how many ROIs (i.e., cells we have in the ROI manager)
//		if (endsWith(file, ".tif"))
//			border = 10;
	//CLEANING:
	//go through all ROIs in the manager one by one, analyze their position, size and CV of fluorescence
	//if ROIs are too close to edges of image (incomplete cells), if they are too small or dead (based on CV measurement), remove the respective ROI from the ROI manager
	//the loop goes backwards because deleting/adding of ROIs changes the ID number of those with higher ID numbers. When counting backwards, these have already been processed when changes are made.
		if (numROIs > 0) {
			for(j = numROIs-1; j >= 0 ; j--) {
				run("Clear Results");
				roiManager("Select", j);
//				run("Set Measurements...", "area mean min standard bounding redirect=None decimal=3");
				run("Measure");
				Mean = getResult("Mean", 0);
				Min = getResult("Min", 0);
				SD = getResult("StdDev", 0);
				w = getResult("Width", 0);
				h = getResult("Height", 0);
				BX = getResult("BX", 0);
				BY = getResult("BY", 0);
		//a,b,c,d,e are all Boolean type variables, i.e., they can have value either 1 (TRUE) or 0 (FALSE)
		//a-d return 1 when respective ROI is touching the edge of the frame (i.e., cell is incomplete)
				a = BX < border;
				b = BY < border;
				c = (BX+w) > (image_W-border);
				d = (BY+h) > (image_H-border);
	//			if ((a+b+c+d+e>0)||(SD/Mean<CV)) roiManager("Delete"); 
				if (a+b+c+d > 0) roiManager("Delete"); //if at least one of the listed conditions is TRUE (has value 1), the respective ROI is deleted
					else {
						if (ellipses == "yes")
							run("Fit Ellipse");
						else {
							run("Enlarge...", "enlarge=1 pixel");
							run("Enlarge...", "enlarge=-1 pixel"); //this enables the circumference of the selection to be converted to a line
						}
					roiManager("add");
					roiManager("Select", j);
					roiManager("Delete");
					//the above code creates a new selection that is added to the ROI manager. The original one is then deleted.
				}												
			}
			roiManager("Remove Channel Info");
	        roiManager("Remove Slice Info");
			roiManager("Remove Frame Info");
			numROIs = roiManager("count");
		}
		if (numROIs == 0) {
			makeRectangle(0, 0, 100, 100);
			roiManager("Add");
		}
			roiManager("Save", roiDir + title + "-RoiSet.zip"); //save the updated list of ROIs 
			close("*");
//	}
	counter++;
}

//function ROI_check() opens each raw file in the analysis folder and loads the ROIs made by the Map_to_ROIs() function.
//It then allows the user to check the exiting ROIs, adjust/remove them, or add additional ones.
//Option to enlarge/shrink size of all ROIs is implemented. For shrinking input negative values.
function ROI_check() {
//	if (endsWith(dir, DirType)) {
		prep();
		if (blind == "yes")
   			rename(dummy_name);
		window = getTitle();
		parent = File.getParent(dir);
		dir_name = File.getName(dir);
		parent_name = File.getName(parent);
		roiManager("reset");
		roiManager("Open", roiDir + title + "-RoiSet.zip");
		numROIs = roiManager("count");
		selectWindow(window);
		run("gem");
		run("Invert LUT");
		roiManager("Show All with labels");
		roiManager("Set Color", "cyan");
		run("Enhance Contrast", "saturated=0.05");
		run("Maximize");
		setTool("ellipse");

		html = "<html>"
			+"The user can move, delete, add ROIs (regions of interest) and change their size and shape. All ROIs need to be elliptical (the elliptical tool is preselected). "
			+"To add new ROIs first make an ellipse and then press the \"<i>Add</i>\" button in the ROI manager window or the \"<i>t</i>\" key on the keyboard.<br>"
			+"<b>Note: All changes are automatically saved when \"OK\" is pressed.</b><br>"
			+"<br>"
			+"<b>Stats:</b><br>"
			+"&#8226; <i>folder</i> - current working directory in which images are being processed (hidden when <i>Blind experimenter</i> option is used)<br>"
			+"&#8226; <i>image counter</i> - current image/number of images in <i>folder</i><br>"
			+"<br>"
			+"<b>Enlarge all ROIs</b><br>"
			+"This option allows the user to make all ROIs larger by a specified number of pixels in each direction (values as low as 0.5 have an effect). "
			+"Use negative values to make the ROIs smaller. Leave at 0 if you desire no change to be made. "
			+"When a nonzero value is inserted the ROI size is adjusted and can be checked and changed again. The processing does not continue to the next image until 0 is used.<br>"
			+"<br>"
			+"<b>Return to previous image</b><br>"
			+"Select if you desire to go back to the previous image. This option only works within the current folder displayed in the stats window.<br>"
			+"<br>"
			+"<b>Note on ROI placement</b><br>"
			+html_ROIs;
		
		E = 1;
		X = 0;
		Y = 0;										
		while ((E != 0) || (X != 0) || (Y != 0)) {
			Dialog.createNonBlocking("Check and adjust ROIs");
			if (blind == "yes") {
				dir_name = "hidden";
				parent_name = dir_name;
			}
			Dialog.addMessage("Stats:\nfolder: \"" + parent_name + "/" + dir_name + "\"" + "\nimage counter: " + i+1 + "/" + list.length + " (" + counter + "/" + count +" total)", 14);
			Dialog.addMessage("Adjust all " + numROIs + " ROIs", 12);
			Dialog.addNumber("Enlarge (neg. values shrink):", 0, 0, 2, "px");
			Dialog.addNumber("Move right (neg. values move left)", 0, 0, 2, "px");
			Dialog.addNumber("Move down (neg. values move up)", 0, 0, 2, "px");
			Dialog.addCheckbox("Return to previous image (within current folder)", false); // the C. albicans images I quantified were obtained from decolvolution of z-stacks from a wide-field microscope. Different setting are therefore needed in this case
		    Dialog.setLocation(screenWidth*3.1/4,screenHeight/6);
		    Dialog.addHelp(html);
		    Dialog.show();
			E = Dialog.getNumber();
			X = Dialog.getNumber();
			Y = Dialog.getNumber();
			go_back = Dialog.getCheckbox();
			roiManager("deselect");
			roiManager ("translate", X, Y);		
			if (E != 0) {
				numROIs = roiManager("count");
				for(j = numROIs-1; j >= 0 ; j--) {
					roiManager("Select", j);
					if (E == -0.5){
						run("Enlarge...", "enlarge=-1 pixel");
						run("Enlarge...", "enlarge=0.5 pixel");
					} else 
						run("Enlarge...", "enlarge=E pixel");
					if (ellipses == "yes")
						run("Fit Ellipse");
					roiManager("add");
					roiManager("Select", j);
					roiManager("Delete");
				}
			}
		}
		roiManager("Remove Channel Info");
        roiManager("Remove Slice Info");
		roiManager("Remove Frame Info");
		roiManager("Save", roiDir + title + "-RoiSet.zip");
		close("*");
		if (go_back == false) 
			counter++;
		else
			counter--;
//	}
}

function Clean_ROIs() {
	Measure_BC();
	numROIs = roiManager("count");
	for(j = numROIs-1; j >= 0 ; j--) {
		roiManager("Select", j);
//		run("Set Measurements...", "mean standard modal min redirect=None decimal=5");
		run("Clear Results");
		run("Measure");
		MODE_ROI=getResult("Mode", 0);
		if (MODE_ROI < BC_T) {
			roiManager("Select", j);
			roiManager("Delete");
		}	
	}
}

//measure background
function Measure_BC() {
	selectWindow(list[i]);
	run("Select None");
//	run("Set Measurements...", "mean standard modal min redirect=None decimal=3");
	run("Clear Results");
	run("Duplicate...", "title=DUP-CROP duplicate channels="+ch);
	run("Measure");
	MIN = getResult("Min", 0);
		if (MIN == 0) run("Auto Crop (guess background color)");
	run("Duplicate...", "title=DUP-CROP-BC");
	run("Subtract Background...", "rolling=512 stack");
	imageCalculator("Difference create stack", "DUP-CROP", "DUP-CROP-BC");
	run("Clear Results");
	run("Measure");
	MEAN = getResult("Mean", 0);
	selectWindow("DUP-CROP");
	setThreshold(0, MEAN);
	run("Create Selection");
	run("Measure");
	BC = getResult("Mean", 1);
	BC_SD = getResult("StdDev", 1);
	BC_T = BC+2*BC_SD;
	run("Select None");
	close("DUP-CROP-BC");
	close("DUP-CROP");
	close("Result of DUP-CROP");
}

//close Results table and ROI manager
close("Results");
close("ROI manager");
if (matches(process, "Convert Masks to ROIs"))
	print("[Status]", "\\Close");
waitForUser("Finito!", "Macro finished successfully."); //tells the user that everything is done
setBatchMode(false); //exits batch mode (only activated for conversion of Maps to ROIs)
