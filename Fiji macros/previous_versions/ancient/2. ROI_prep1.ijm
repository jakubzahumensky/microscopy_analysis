var border=0.3; //value needs to be adjusted based on actual microscopy images
var cell_cutoff=5; //cells (buds) with area smaller than this will be removed from analysis
//var CV = 0.5; //cells with coefficient of variance (CV) smaller than this will be removed from analysis
var CV = 0.0;

//declaring variables (calling them into existence and assigning initial value):
var title="";
var roiDir="";
var MasksDir="";
var ext1 = "czi";
var ext2 = "oif";
var ext3 = "tif";
/*
//ask user for directory with data to be processed:
//1. option:
dir = getDirectory("Choose a Directory");
//2. option:
*/
Dialog.create("ROI prep");
	Dialog.addString("Directory:", "");
	Dialog.addNumber("Channel:", 1); // Asks which channel should be exported. 1 as default.
    Dialog.show();
	dir = Dialog.getString();
	ch = Dialog.getNumber();

//select operation to be performed. Always run "Convert Masks to ROIs" firts, then run macro again and choose "Check ROIs"
types = newArray("Convert Masks to ROIs", "Check ROIs");
Dialog.create("Choose operation");
	Dialog.addChoice("Type:", types);
	Dialog.show();
	type = Dialog.getChoice();

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
		if (matches(type, "Convert Masks to ROIs")) //if you selected "Convert Masks to ROIs", it calls Map_to_ROIs function (defined below)
			Map_to_ROIs();
			else ROI_check(); // if you selected "Check ROIs", the condition "matches(type, "Convert Masks to ROIs")" gives FALSE as result and macro continues to run function ROI_check()
		}
	}
}

//Preparatory step where image suffix (extension) is removed from filename. This makes the steps below simpler and more universal. The extension (ext1, ext2, ext3) are defined in the beginning of the macro
function prep() {
	roiDir = replace(dir, "data", "ROIs");
	MasksDir = replace(dir, "data", "Masks");
	if (endsWith(q, "." + ext1)||endsWith(q, "." + ext2)||endsWith(q, "." + ext3)) {
	   	run("Bio-Formats Windowless Importer", "open=[q]");
	   	Stack.setChannel(ch);
		rename(list[i]);
		title = list[i];
		title = replace(list[i], "."+ext1, "");
		title = replace(title, "."+ext2, "");
		title = replace(title, "."+ext3, "");

		getDimensions(width, height, channels, slices, frames);
//If you have a multichannel image, here you can define which channel you are analysing
	//  if (channels>2) Stack.setChannel(2);
	}
}

//conversion of the LabelMap from Cellpose to ROIs; macro calls the "LabelMap to ROI Manager (2D)" that is part of the SCF plugin package (available at: https://sites.imagej.net/SCF-MPI-CBG/plugins/)
function Map_to_ROIs() {
	if (endsWith(dir, "data/")) {
		prep(); //Map_to_ROIs calls the prep() function

		File.makeDirectory(roiDir);
		run("Set Measurements...", "area bounding redirect=None decimal=3");
		run("Clear Results");
		run("Measure");
	//get image size - used for removing ROIs too close to the edges (incomplete cells)
		image_W=getResult("Width", 0);
		image_H=getResult("Height", 0);
	//	open(MasksDir+"MASK_"+title+".tif");
		open(MasksDir+title+"_cp_masks.png");
		roiManager("reset"); // clear ROI manager of anything that might be there from previous work
		run("LabelMap to ROI Manager (2D)");  // for each cell in the Cellpose map a ROI is made and put into ROI manager
		selectWindow(list[i]);
		numROIs = roiManager("count"); // find out how many ROIs (i.e., cells we have in the ROI manager)
	//CLEANING:
	//go through all ROIs in the manager one by one, analyze their position, size and CV of fluorescence
	//if ROIs are too close to edges of image (incomplete cells), if they are too small or dead (based on CV measurement), remove the respective ROI from the ROI manager
		for(j=numROIs-1; j>=0 ; j--) {
			run("Clear Results");
			roiManager("Select", j);
			run("Set Measurements...", "area mean standard bounding redirect=None decimal=3");
			run("Measure");
			A=getResult("Area", 0);
			Mean=getResult("Mean", 0);
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
					roiManager("add");
					roiManager("Select", j);
					roiManager("Delete");
				}			
		}
		
		roiManager("Save", roiDir+title+"-RoiSet.zip"); //save the updated list of ROIs 
		close("*");
	}
}

//function ROI_check() opens each raw file in the analysis folder and loads the ROIs made by the Map_to_ROIs() function.
//It then allows the user to check if everything is fine and remove specific ROIs, if the segmentation failed or the cell is dead, for example.
//It opens all available raw images and prompts used to remove ROIs and press "OK" when done. If yuo are happy with all ROIs, press "OK". Next image will be loaded.
function ROI_check() {
	if (endsWith(dir, "data/")) {
		prep();
	
		window = getTitle();
		roiManager("reset");
		roiManager("Open", roiDir+title+"-RoiSet.zip");
		selectWindow(window);
		run("gem");
		run("Invert LUT");
		roiManager("Show All with labels");
		roiManager("Set Color", "cyan");
		run("Maximize");
		waitForUser("Remove bad ROIs!");
		roiManager("Save", roiDir+title+"-RoiSet.zip");
		close("*"); // close all images
	}
}

//close Results table and ROI manager
close("Results");
close("ROI manager");

//tell the user that everything is done
waitForUser("Finito!");