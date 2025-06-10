// Declaration of variables and assignment of initial values
var title="";
var roiDir="";
var pixelHeight = 0;
var ext1 = "czi";
var ext2 = "oif";
var ext3 = "tif";
var W = 75; // wait period - debug
var n=0; // total cell counter
NAME = "3. Quant_of_section4.ijm"

// ask user for directory with data to be processed:
/*
// 1. option:
dir = getDirectory("Choose a Directory");
// 2. option:
*/
Dialog.create("Quantify!");
	Dialog.addString("Directory:", "");
	Dialog.addString("Subset (leave empty to process all images):", "");
	Dialog.addNumber("Channel:", 1); // Asks which channel should be exported. 1 as default.
	Dialog.addNumber("Smoothing factor (Gauss):", 0.5);
    Dialog.show();
	dir = Dialog.getString();
	subset = Dialog.getString();
	ch = Dialog.getNumber();
	SF = Dialog.getNumber();

	dirM = dir;
	
// clear LOG window and print header for analysis report (column names)
	getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec)
	print("\\Clear");
	print("# Basic macro run statistics:")
	print("# Macro: "+NAME);
	print("# Channel: "+ch);
	print("# Smoothing factor (Gauss): "+SF);
	print("# Date and time: "+year+"-"+month+1+"-"+dayOfMonth+" "+hour+":"+minute+":"+second);
	print("exp_code,BR_date,strain,cult_medium,condition,frame#,mean_background,cell#,patches,patch_density,patch_intensity,PM_base,patch_prominence,cell_area,cell_I-integral,cell_I-mean,cell_I-SD,cytosol_area,cytosol_I-integral,cytosol_I-mean,cytosol_I-SD,cytosol_I-CV,PM_area,PM_I-integral,PM_I-mean,PM_I-SD,PM_I-CV,PM_I-mean/Cyt_I-mean,prot_in_patches,patch_distance_min,patch_distance_max,patch_distance_mean,patch_distance_stdDev,patch_distance_CV");	

processFolder(dir); // calling the "processFolder" function, defined below

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
		if (endsWith(dir, "data/")) {
			if (indexOf(q, subset) >= 0) {
				measure();
			}			
		}
		}
	}
}
// Preparatory step where image suffix (extension) is removed from filename. This makes the steps below simpler and more universal.
// The extension (ext1, ext2, ext3) are defined in the beginning of the macro
function prep() { 
	roiDir = replace(dir, "data", "ROIs");
	if (endsWith(q, "." + ext1)||endsWith(q, "." + ext2)||endsWith(q, "." + ext3)) {
	   	run("Bio-Formats Windowless Importer", "open=[q]");
	  	rename(list[i]);
		title = replace(list[i], "."+ext1, "");
		title = replace(title, "."+ext2, "");
		title = replace(title, "."+ext3, "");
	getDimensions(width, height, channels, slices, frames);
	getPixelSize(unit, pixelWidth, pixelHeight);
	if (channels > 1) Stack.setChannel(ch);
	run("Duplicate...", "duplicate channels="+ch);
	run("Gaussian Blur...", "sigma=SF");
	rename("DUP");
	
	}
}

// Measure all sorts of interesting parameters, separately for each cell, write results into the LOG window
function measure() {
	prep();
        	
	// background measurement - all intensity measurements and ratio calculations need to be first corrected for background
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
		run("Select None");
		BC=getResult("Mean", 1);
		close("DUP-CROP-BC");
//		close("DUP-CROP");
		close("Result of DUP-CROP");
//	run("Tile");

	// quantification - open ROIs prepared with ROI_prep.ijm macro and cycling through them one by one
		roiManager("reset");
		roiManager("Open", roiDir+title+"-RoiSet.zip");
		roiManager("Remove Channel Info");
		numROIs = roiManager("count");
		for(j=0; j<numROIs;j++) {
			n=n+1;
//		for(j=7; j<=8;j++) {
			run("Set Measurements...", "area mean standard integrated redirect=None decimal=3");
			run("Clear Results");
			selectWindow(list[i]);
//		wait(500);
		wait(W);	
			roiManager("Select", j);
		wait(W);
//		wait(500);
			run("Enlarge...", "enlarge=0.166");
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
			selectWindow(list[i]); // selects raw microscopy image again
		wait(W);
			roiManager("Select", j);
			run("Enlarge...", "enlarge=-0.166");
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
			selectWindow("DUP");
		wait(W);
			roiManager("Select", j);
				run("Fit Ellipse");
				run("Area to Line"); // convert the ellipse (area object) to a line that has a beginning and end
				D=0.332/pixelHeight;
				run("Line Width...", "line=D");
				run("Set Measurements...", "mean standard min redirect=None decimal=3");
				run("Clear Results");
				run("Measure");
					PM_length = getResult("Length", 0); // length measured along the plasma membrane
					PM_StdDev = getResult("StdDev", 0);
					Peak_MIN = 1.5*cyt_mean_BC+BC;
			//	selectWindow("DUP");
			
				run("Plot Profile");
//				run("Find Peaks", "min._peak_amplitude="+1.25*PM_StdDev+" min._peak_distance=0 min._value=Peak_MIN max._value=[] list"); // "Find Peaks" is part of the BAR plugin package,available here: https://imagej.net/plugins/bar#installation 
				run("Find Peaks", "min._peak_amplitude=PM_StdDev min._peak_distance=0 min._value=Peak_MIN max._value=[] list");
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
					patch_distance_min=NaN;
					patch_distance_max=NaN;
					patch_distance_mean=NaN;
					patch_distance_stdDev=NaN;
					patch_distance_CV=NaN;
					if (patches > 1) {
						MAXIMA = newArray(patches);
						for (p=0; p<patches; p++){
						  MAXIMA[p] = getResult("X1",p);
						}
						Array.sort(MAXIMA);
						X=PM_length+MAXIMA[0];
						if (X>MAXIMA[patches-1]) MAXIMA = Array.concat(MAXIMA, X);
							else patches = patches-1;
						patch_distance = newArray(MAXIMA.length-1);
						for (p=0; p<MAXIMA.length-1; p++){
						 	patch_distance[p]=MAXIMA[p+1]-MAXIMA[p];
						}
							Array.getStatistics(patch_distance, patch_distance_min, patch_distance_max, patch_distance_mean, patch_distance_stdDev);
							patch_distance_CV=patch_distance_stdDev/patch_distance_mean;
					}		
				
			patch_intensity=patch_intensity_sum/patches;
			patch_intensity_BC=patch_intensity-BC;
			PM_base=PM_base_sum/mins;
			PM_base_BC=PM_base-BC;
			patch_prominence=patch_intensity_BC/PM_base_BC;
			patch_density = patches/PM_length;
			prot_fraction_in_patches = 1 - PM_base_BC/PM_mean_BC;
			parent = File.getParent(dir);
			grandparent = File.getParent(parent);
			parent_name = File.getName(parent);
			grandparent_name = File.getName(grandparent);
			BR_date = substring(parent_name, 0, 6);
			exp_code = substring(grandparent_name, 0, 8);
			
			print(exp_code+","+BR_date+","+title+","+BC+","+(j+1)+","+patches+","+patch_density+","+patch_intensity_BC+","+PM_base_BC+","+patch_prominence+","+cell_area+","+cell_int_BC+","+cell_mean_BC+","+cell_SD+","+cyt_area+","+cyt_int_BC+","+cyt_mean_BC+","+cyt_SD+","+cyt_CV+","+PM_area+","+PM_int_BC+","+PM_mean_BC+","+PM_SD+","+PM_CV+","+PM_div_Cyt+","+prot_fraction_in_patches+","+patch_distance_min+","+patch_distance_max+","+patch_distance_mean+","+patch_distance_stdDev+","+patch_distance_CV);
			close("Mask-outer");
			close("Mask-inner");
			close("Result of Mask-outer");
			close("Plot of "+title);
			close("Peaks in Plot of "+title);
			close("Plot of DUP");
			close("Peaks in Plot of DUP");
			if (n % 100 == 0) {
				selectWindow("Log");
				saveAs("Text", dirM+"Summary-temporary");
			}
		}
		close("*");
		selectWindow("Log");
		saveAs("Text", dirM+"Summary-temporary");
}

getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
selectWindow("Log");
saveAs("Text", dir+"Summary of SECTIONS in channel "+ch+" ("+year+"-"+month+1+"-"+dayOfMonth+", "+hour+"-"+minute+"-"+second+").csv");
close("Summary of SECTIONS in channel " + ch + " (" + year+"-"+month+1+"-"+dayOfMonth+","+hour+"-"+minute+"-"+second + ").csv");
close("Results");
close("Log");
close("ROI manager");

waitForUser("Finito!");
