var border=0.3; //value needs to be adjusted based on actual microscopy images
var cell_cutoff=5; //cells (buds) with area smaller than this will be removed from analysis
var CV = 0.0; //cells with coefficient of variance (CV) smaller than this will be removed from analysis

//declaring variables (calling them into existence and assigning initial value):
var title="";
var roiDir="";
var MasksDir="";
var x = "";
var px=0;
var R=1.4;
var BC_T=0;
var go_back = false;

//ask user for directory with data to be processed (works recursively):
Dialog.create("Select experiment directory");
	Dialog.addDirectory("Directory:", "");
	Dialog.addString("Extension:", "czi");
	Dialog.addString("Subset (optional):", ""); // if left empy, all images are analyzed
	Dialog.addNumber("Channel:", 1); // Asks which channel should be exported. 1 is set as default.
    Dialog.show();
	dir = Dialog.getString();
	ext = Dialog.getString();
	subset = Dialog.getString();
	ch = Dialog.getNumber();
	
	
//select operation to be performed. Always run "Convert Masks to ROIs" first, then run macro again and choose "Check ROIs"
processes = newArray("Convert Masks to ROIs", "Check ROIs");
image_types = newArray("Transversal", "Tangential");
Dialog.create("Choose operation and image type");
	Dialog.addRadioButtonGroup("Process:", processes, 2, 1, "Convert Masks to ROIs");
	Dialog.addRadioButtonGroup("Image type:", image_types, 2, 1, "Transversal");
	Dialog.show();
	process = Dialog.getRadioButton();
	image_type = Dialog.getRadioButton();
	
	if (matches(image_type, "Tangential"))
		x="data-caps/";
		else x="data/";

// https://forum.image.sc/t/create-specific-dialog/36884
// https://forum.image.sc/t/pushbuttons-in-imagej-macro-dialog/36885

if (matches(process, "Convert Masks to ROIs"))
	if (getBoolean("WARNING! Any existing ROIs will be overwritten! Continue?") == 0)
		exit("Macro aborted by user.");

//calling the "processFolder function, defined below
processFolder(dir);

//Definition of "processFolder" function: starts in selected directory, makes a list of what is inside then goes through it one by one
//If it finds another directory, it enters it and makes a new list and does the same.
//In this way, it enters all subdirectories and looks for data.
function processFolder(dir) {
   list = getFileList(dir);
   for (i=0; i<list.length; i++) {
      showProgress(i+1, list.length);
      if (endsWith(list[i], "/"))
        processFolder(""+dir+list[i]);
      else {
		q = dir+list[i];
		if (indexOf(q, subset) >= 0) {
			if (matches(process, "Convert Masks to ROIs")) //if you selected "Convert Masks to ROIs", it calls Map_to_ROIs function (defined below)
				Map_to_ROIs();
				else ROI_check();
				if (go_back == true && i>0) {
					i=i-2;
					go_back = false;
				}
		}
      }
	}
}


//Preparatory step where image suffix (extension) is removed from filename. This makes the steps below simpler and more universal. The extension (ext1, ext2, ext3) are defined in the beginning of the macro
function prep() {
	roiDir = replace(dir, "data", "ROIs");
	MasksDir = replace(dir, "data", "Masks");
	if (endsWith(q, "." + ext)) {
	   	run("Bio-Formats Windowless Importer", "open=[q]");
		getDimensions(width, height, channels, slices, frames);
		if (channels > 1) Stack.setChannel(ch);
		rename(list[i]);
		title = File.nameWithoutExtension;
		getDimensions(width, height, channels, slices, frames);
		run("Set Measurements...", "area mean standard modal min redirect=None decimal=5");
		run("Clear Results");
		run("Measure");
		px=sqrt(getResult("Area", 0)/width/height);
	}
}

//conversion of the LabelMap masks made in Cellpose to ROIs; macro calls the "LabelMap to ROI Manager (2D)" that is part of the SCF plugin package (available at: https://sites.imagej.net/SCF-MPI-CBG/plugins/)
function Map_to_ROIs() {
	if (endsWith(dir, x)) {
		prep(); //Map_to_ROIs calls the prep() function

		if (File.exists(roiDir) == 0) 
		File.makeDirectory(roiDir);
		run("Set Measurements...", "area bounding redirect=None decimal=3");
		run("Clear Results");
		run("Measure");
	//get image size - used for removing ROIs too close to the edges (incomplete cells)
		image_W=getResult("Width", 0);
		image_H=getResult("Height", 0);
//		open(MasksDir+"MASK_"+title+".tif");
		open(MasksDir+title+"_cp_masks.png");
		roiManager("reset"); // clear ROI manager of anything that might be there from previous work
		run("LabelMap to ROI Manager (2D)");  // for each cell in the Cellpose map a ROI is made and put into ROI manager
		selectWindow(list[i]);
		numROIs = roiManager("count"); // find out how many ROIs (i.e., cells we have in the ROI manager)
	//CLEANING:
	//go through all ROIs in the manager one by one, analyze their position, size and CV of fluorescence
	//if ROIs are too close to edges of image (incomplete cells), if they are too small or dead (based on CV measurement), remove the respective ROI from the ROI manager
	if (numROIs > 0) {
		for(j=numROIs-1; j>=0 ; j--) {
			run("Clear Results");
			roiManager("Select", j);
			run("Set Measurements...", "area mean min standard bounding redirect=None decimal=3");
			run("Measure");
			A=getResult("Area", 0);
			Mean=getResult("Mean", 0);
			Min=getResult("Min", 0);
			SD=getResult("StdDev", 0);
			w=getResult("Width", 0);
			h=getResult("Height", 0);
			BX=getResult("BX", 0);
			BY=getResult("BY", 0);
			//a,b,c,d,e are all Boolean type variables, i.e., they can have value either 1 (TRUE) or 0 (FALSE)
			a=BX<border;
			b=BY<border;
			c=(BX+w)>(image_W-border);
			d=(BY+h)>(image_H-border);
			e=A<cell_cutoff;
			if ((a+b+c+d+e>0)||(SD/Mean<CV)) roiManager("Delete"); //if at least one of the listed conditions is TRUE (has value 1), the respective ROI is deleted
				else {
					run("Fit Ellipse");
					if (matches(image_type, "Tangential")) {
						run("Set Measurements...", "centroid redirect=None decimal=5");
						run("Clear Results");
						run("Measure");
						X=(getResult("X", 0)-R)/px;
						Y=(getResult("Y", 0)-R)/px;
						makeOval(X, Y, 2*R/px, 2*R/px);
					}	
					roiManager("add");
					roiManager("Select", j);
					roiManager("Delete");
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
		roiManager("Save", roiDir+title+"-RoiSet.zip"); //save the updated list of ROIs 
		close("*");
	}
}

//function ROI_check() opens each raw file in the analysis folder and loads the ROIs made by the Map_to_ROIs() function.
//It then allows the user to check if everything is fine and remove specific ROIs, if the segmentation failed or the cell is dead, for example.
//It opens all available raw images and prompts user to remove ROIs and press "OK" when done. If you are happy with all ROIs, press "OK". Next image will be loaded.
function ROI_check() {
	if (endsWith(dir, x)) {
		prep();
		window = getTitle();
		parent = File.getParent(dir);
		dir_name = File.getName(dir);
		parent_name = File.getName(parent);
		roiManager("reset");
		roiManager("Open", roiDir+title+"-RoiSet.zip");
		selectWindow(window);
		run("gem");
		run("Invert LUT");
		roiManager("Show All with labels");
		roiManager("Set Color", "cyan");
		run("Maximize");
		setTool("ellipse");
//		waitForUser("Remove/adjust bad ROIs and/or add missing ROIs" + "\n \nfolder: \"" + parent_name + "/" + dir_name + "\"" + "\nimage: " + i+1 + "/" + list.length);
//		showMessage("Remove/adjust bad ROIs!" + "\nAdd missing ROIs!" + "\n \nfolder: \"" + parent_name + "/" + dir_name + "\"" + "\nimage: " + i+1 + "/" + list.length);
		
		Dialog.create("ROI check");
			Dialog.addMessage("Remove/adjust bad ROIs and/or add missing ROIs", 14);
			//Dialog.addMessage("-------------------------");
			Dialog.addMessage("folder: \"" + parent_name + "/" + dir_name + "\"" + "\nimage: " + i+1 + "/" + list.length, 13);
			Dialog.addCheckbox("Return to previous image (only works within a single folder)", false); // the C. albicans images I quantified were obtained from decolvolution of z-stacks from a wide-field microscope. Different setting are therefore needed in this case
		    Dialog.setLocation(screenWidth*3/4,screenHeight/6)
		    Dialog.show();
			go_back = Dialog.getCheckbox();

		if (matches(image_type, "Tangential")) {
			ROIs_to_circles();
			Clean_ROIs();	
		}
		roiManager("Remove Channel Info");
        roiManager("Remove Slice Info");
		roiManager("Remove Frame Info");
		roiManager("Save", roiDir+title+"-RoiSet.zip");
		close("*");
	}
}

function ROIs_to_circles() {
	numROIs = roiManager("count");
		for(k=numROIs-1; k>=0 ; k--) {
			roiManager("Select", k);
			run("Fit Ellipse");
			run("Set Measurements...", "centroid redirect=None decimal=5");
			run("Clear Results");
			run("Measure");
			X=(getResult("X", 0)-R)/px;
			Y=(getResult("Y", 0)-R)/px;
			makeOval(X, Y, 2*R/px, 2*R/px);
			roiManager("Add");
			roiManager("Select", k);
			roiManager("Delete");
		}
	roiManager("Remove Channel Info");
    roiManager("Remove Slice Info");
    roiManager("Remove Frame Info");	
	waitForUser(parent_name + "\n \n (Re)move bad ROIs!");	
}

function Clean_ROIs() {
	Measure_BC();
	numROIs = roiManager("count");
	for(j=numROIs-1; j>=0 ; j--) {
		roiManager("Select", j);
		run("Set Measurements...", "mean standard modal min redirect=None decimal=5");
		run("Clear Results");
		run("Measure");
//		MIN_ROI=getResult("Min", 0);
		MODE_ROI=getResult("Mode", 0);
//waitForUser;
		if (MODE_ROI < BC_T) {
			roiManager("Select", j);
			roiManager("Delete");
		}	
	}
}

function Measure_BC() {
	selectWindow(list[i]);
	run("Select None");
	run("Set Measurements...", "mean standard modal min redirect=None decimal=3");
	run("Clear Results");
	run("Duplicate...", "duplicate channels="+ch);
	run("Measure");
	MIN=getResult("Min", 0);
		if (MIN == 0) run("Auto Crop (guess background color)");
	rename("DUP-CROP");
	run("Duplicate...", "duplicate");
	rename("DUP-CROP-BC");
	run("Subtract Background...", "rolling=512 stack");
	imageCalculator("Difference create stack", "DUP-CROP", "DUP-CROP-BC");
	run("Clear Results");
	run("Measure");
	MEAN=getResult("Mean", 0);
	selectWindow("DUP-CROP");
	setThreshold(0, MEAN);
	run("Create Selection");
	run("Measure");
	BC=getResult("Mean", 1);
	BC_SD=getResult("StdDev", 1);
	BC_T=BC+2*BC_SD;
//	print(BC);
//	print(BC_SD);
	run("Select None");
	close("DUP-CROP-BC");
	close("DUP-CROP");
	close("Result of DUP-CROP");
}

//close Results table and ROI manager
close("Results");
close("ROI manager");

//tell the user that everything is done
waitForUser("Finito!", "Macro finished successfully.");