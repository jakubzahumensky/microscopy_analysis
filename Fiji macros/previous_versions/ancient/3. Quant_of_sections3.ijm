// Declaration of variables and assignment of initial values
var title="";
var roiDir="";

var ext1 = "czi";
var ext2 = "oif";
var ext3 = "tif";

// ask user for directory with data to be processed:
/*
// 1. option:
dir = getDirectory("Choose a Directory");
// 2. option:
*/
Dialog.create("Quantify!");
	Dialog.addString("Directory:", "");
	Dialog.addNumber("Channel:", 1); // Asks which channel should be exported. 1 as default.
    Dialog.show();
	dir = Dialog.getString();
	ch = Dialog.getNumber();

// clear LOG window and print header for analysis report (column names)
print("\\Clear");
print("exp_code,BR_date,strain,cult_medium,condition,frame#,mean_background,cell#,patches,patch_density,patch_intensity,PM_base,patch_prominence,cell_area,cell_I-integral,cell_I-mean,cell_I-SD,cytosol_area,cytosol_I-integral,cytosol_I-mean,cytosol_I-SD,cytosol_I-CV,PM_area,PM_I-integral,PM_I-mean,PM_I-SD,PM_I-CV,PM_I-mean/Cyt_I-mean");	

// calling the "processFolder function, defined below
processFolder(dir);

// Definition of "processFolder" function: starts in selected directory, makes a list of what is inside then goes through it one by one
// If it finds another directory, it enters it and makes a new list and does the same.
// In this way, it enters all subdirectories and looks for data.
function processFolder(dir) {
   list = getFileList(dir);
   for (i=0; i<list.length; i++) {
      showProgress(i+1, list.length);
      if (endsWith(list[i], "/"))
        processFolder(""+dir+list[i]);
      else {
		q = dir+list[i];
		measure();		
		}
	}
}

// Preparatory step where image suffix (extension) is removed from filename. This makes the steps below simpler and more universal. The extension (ext1, ext2, ext3) are defined in the beginning of the macro
function prep() {
	roiDir = replace(dir, "data", "ROIs");
	if (endsWith(q, "." + ext1)||endsWith(q, "." + ext2)||endsWith(q, "." + ext3)) {
	   	run("Bio-Formats Windowless Importer", "open=[q]");
		getDimensions(width, height, channels, slices, frames);
	if (channels > 1) Stack.setChannel(ch);
		rename(list[i]);
		title = replace(list[i], "."+ext1, "");
		title = replace(title, "."+ext2, "");
		title = replace(title, "."+ext3, "");

		getDimensions(width, height, channels, slices, frames);
// If you have a multichannel image, here you can define which channel you are analysing
	//  if (channels>2) Stack.setChannel(2);
	}
}

// Measure all sorts of interesting parameters, separately for each cell, write results into the LOG window
function measure() {
	if (endsWith(dir, "data/")) {
		prep();
        	
	// background measurement - all intensity measurements and ratio calculations need to be first corrected for background
		run("Set Measurements...", "mean min redirect=None decimal=3");
		run("Clear Results");
		run("Measure");
		MIN=getResult("Min", 0); // value of darkest pixel
	// everything will intensity below MIN*1.5 is selected and mean intensity of this area is used as background
	// not ideal, but good enough estimate and relatively quick
		if (MIN == 0) {
//			run("Duplicate...", "duplicate");
			run("Duplicate...", "duplicate channels="+ch);
			run("Auto Crop (guess background color)");
			run("Clear Results");
			run("Measure");
			MIN=getResult("Min", 0);
			setThreshold(0, MIN*1.5); 
			run("Create Selection");
			run("Measure");
			BC=getResult("Mean", 1);
			close();
		} else {
			setThreshold(0, MIN*1.5); 
			run("Create Selection");
			run("Measure");
			BC=getResult("Mean", 1);
		}
		
	// quantification - open ROIs prepared with ROI_prep.ijm macro and cycling through them one by one
		roiManager("reset");
		roiManager("Open", roiDir+title+"-RoiSet.zip"); // load ROIs into ROI manager
		numROIs = roiManager("count");
		for(j=0; j<numROIs;j++) {
		// for(j=0; j<2;j++) {
			run("Set Measurements...", "area mean standard integrated redirect=None decimal=3");
			run("Clear Results");
			roiManager("Select", j);
//				run("Fit Ellipse"); // approximate each cell with an ellipse; since we set the segmentation masks to fit middle of the plasma membrane, the ellipse now is also in the middle of the plasma membrane
				// whole cell measurements - size (area), integral intensity, mean intensity, 
				run("Enlarge...", "enlarge=2 pixel"); // upscale ellipse so that we measure only inside the cell
				run("Measure");
				cell_area = getResult("Area", 0);
				cell_int = getResult("IntDen", 0);
				cell_int_BC = cell_int - cell_area * BC; // background correction
				cell_mean = getResult("Mean", 0);
				cell_mean_BC = cell_mean - BC; // backgorund correction
				cell_SD = getResult("StdDev", 0); // standard deviation of the mean intensity (does not change with background)
				run("Clear Results"); // clear Results table to make it ready for next measurement
			// preparation for plasma membrane segmentation - definition of outer bounds
				run("Create Mask");
				rename("Mask-outer");
			// Quantification of the intracellular space
			// select raw microscopy image again
			selectWindow(list[i]);
			roiManager("Select", j);
				run("Fit Ellipse"); // ellipse was lost, we need to make it again
				run("Enlarge...", "enlarge=-2 pixel"); // downscale ellipse so that we measure only inside the cell
				run("Measure");
				cyt_area = getResult("Area", 0); // area of cell interior
				cyt_int = getResult("IntDen", 0); // integrated fluorescence intensity
				cyt_int_BC = cyt_int - cyt_area * BC; // backgorund correction
				cyt_mean = getResult("Mean", 0); // mean fluorescence intensity
				cyt_mean_BC = cyt_mean - BC; // background correction
				cyt_SD = getResult("StdDev", 0); // standard deviation of the mean intracellular intensity
				cyt_CV = cyt_SD/cyt_mean_BC; // coefficient of variance of fluorescence signal inside the cell - can be used as a measure of complexity of intracellular structures
				PM_area = cell_area-cyt_area; // area of the plasma membrane
				PM_int_BC = cell_int_BC-cyt_int_BC; // integral intensity of the plasma membrane, corrected for background
				// preparation for plasma membrane segmentation - definition of inner bounds
				run("Create Mask");
				rename("Mask-inner");
				imageCalculator("Subtract create", "Mask-outer","Mask-inner");
				selectWindow("Result of Mask-outer");
				run("Create Selection"); // selection of the plasma membrane only
			selectWindow(list[i]);
			run("Restore Selection"); // transfer of the selection to the raw microscopy image
			run("Clear Results");
			run("Measure");
				PM_mean = getResult("Mean", 0);
				PM_mean_BC = PM_mean - BC;
				PM_SD = getResult("StdDev", 0);
				PM_CV = PM_SD/PM_mean_BC;
				PM_div_Cyt = PM_mean_BC/cyt_mean_BC;
			//measurement along the plasma membrane - counting the patches, YAY!
			selectWindow(list[i]);
			roiManager("Select", j);
				run("Fit Ellipse");
				run("Area to Line"); // convert the ellipse (area object) to a line that has a beginning and end
				run("Line Width...", "line=6"); // line thickness set so that it covers whole plasma membrane (we up/downscaled the ellipses above by 3 pixels, that's 6 together)
				run("Set Measurements...", "standard redirect=None decimal=3");
				run("Clear Results");
				run("Measure");
					PM_length = getResult("Length", 0); // length measured along the plasma membrane
					PM_StdDev = getResult("StdDev", 0);
				run("Plot Profile");
				run("Find Peaks", "min._peak_amplitude="+1.25*PM_StdDev+" min._peak_distance=0 min._value=[] max._value=[] exclude list"); // "Find Peaks" is part of the BAR plugin package,available here: https://imagej.net/plugins/bar#installation 
					Table.rename("Plot Values", "Results");
					patches=0;
					mins=0;
					patch_intensity_sum=0;
					PM_base_sum=0;
					for (k = 0; k < nResults; k++) {
						x=getResult("Y1",k);
						y=getResult("Y2",k);
						if (x > 0) {
							patch_intensity_sum=patch_intensity_sum+x;
							patches+=1;
						}
						if (y > 0) {
						PM_base_sum=PM_base_sum+y;
						mins+=1;
						}
					}
			patch_intensity=patch_intensity_sum/patches;
			patch_intensity_BC=patch_intensity-BC;
			PM_base=PM_base_sum/mins;
			PM_base_BC=PM_base-BC;
			patch_prominence=patch_intensity_BC/PM_base_BC;
			patch_density = patches/PM_length;
			parent = File.getParent(dir);
			grandparent = File.getParent(parent);
			parent_name = File.getName(parent);
			grandparent_name = File.getName(grandparent);
			BR_date = substring(parent_name, 0, 6);
			exp_code = substring(grandparent_name, 0, 8);
			print(exp_code+","+BR_date+","+title+","+BC+","+(j+1)+","+patches+","+patch_density+","+patch_intensity_BC+","+PM_base_BC+","+patch_prominence+","+cell_area+","+cell_int_BC+","+cell_mean_BC+","+cell_SD+","+cyt_area+","+cyt_int_BC+","+cyt_mean_BC+","+cyt_SD+","+cyt_CV+","+PM_area+","+PM_int_BC+","+PM_mean_BC+","+PM_SD+","+PM_CV+","+PM_div_Cyt);
			close("Mask-outer");
			close("Mask-inner");
			close("Result of Mask-outer");
			close("Plot of "+title);
			close("Peaks in Plot of "+title);
		}
		close("*");
	}
}

selectWindow("Log");
saveAs("Text", dir+"Summary.csv");
date = File.dateLastModified(dir+"Summary.csv");
date2 = replace(date, ":", "-");
saveAs("Text", dir+"Summary ("+date2+").csv");
File.delete(dir+"Summary.csv");
close("Summary for channel " + ch + " (" + date2 + ").csv");

close("Results");
close("Log");
close("ROI manager");

waitForUser("Finito!");