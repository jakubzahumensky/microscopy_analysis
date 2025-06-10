// Declaration of variables and assignment of initial values
var title="";
var roiDir="";
var pixelHeight = 0;
var W = 10; // wait period - the macro sometimes has a tendency to go to a command before finishing the previous one in several places. W (ms) helps mitigate this. Can be adjusted
var WC = 250;
var SF = 1; // Smoothing factor (Gauss)
var PP = 1.666; // Patch prominence threshold - set semi-empirically
var CV = 0;
var extension_list = newArray("czi", "oif", "lif", "tif");
//var MEAN = 0;
//var MIN = 0;
var BC = 0;
//var Debug = false;
version = "6.1"

close("*");

html = "<html>"
	+"<b>Directory</b><br>"
	+"Specify the directory where you want <i>Fiji</i> to start looking for folders with images. "
	+"The macro works <u>recursively</u>, i.e., it looks into all subfolders. "
	+"All folders with names ending with the word \"<i>data</i>\" are processed. All other folders are ignores.<br>"
	+"<br>"
	+"<b>Subset</b><br>"
	+"If used, only images with filenames containing specified <i>string</i> (i.e., group of characters and/or numbers) will be processes. "
	+"This option can be used to selectively process images of a specific strain, condition, etc. "
	+"Leave empty to process all images in specified directory (and its subdirectories).<br>"
	+"<br>"
	+"<b>Channel</b><br>"
	+"Specify image channel to be used for processing. Macro needs to be run separately for individual channels.<br>"
	+"<br>"
	+"<b>Naming scheme</b><br>"
	+"Specify how your files are named (without extension). Results are reported in a comma-separated table, with the parameters specified here used as column headers. "
	+"The default \"<i>strain,medium,time,condition,frame</i>\" creates 5 columns, with titles \"strains\", \"medium\" etc. "
	+"Using a consistent naming scheme accross your data enables automated downstream data processing of data.<br>"
	+"<br>"
	+"<b>Min and max cell size</b><br>"
	+"Specify lower (<i>min</i>) and upper (<i>max</i>) limit for cell area (in &micro;m<sup>2</sup>; as appears in the microscopy images). "
	+"Only cells within this range will be included in the analysis. The default lower limit is set to 5 &micro;m<sup>2</sup>, which corresponds to a small bud of a haploid yeast. <br>"
	+"The user is advised to measure a handful of cells before adjusting these limits. If in doubt, set limits 0-Infinity and filter the results table.<br>"
	+"<br>"
	+"<b>Coefficient of variance (CV) threshold</b><br>"
	+"Cells whose intensity coefficient of variance (standard deviation/mean) is below the specified value will be excluded from the analysis. Can be used for automatic removal of dead cells, "
	+"but <i>a priori</i> knowledge about the system is required. Filtering by CV can be performed <i>ex post</i> in the results table.<br>"
	+"<br>"
	+"<b>Deconvolved</b><br>"
	+"Select if your images have been deconvolved. If used, no Gaussian smoothing is applied to images before quantification of patches in the plasma membrane. "
	+"In addition, prominence of 1.333 is used instead of 1.666 used for confocal images. The measurements of intensities (cell, cytosol, plasma membrane) are not affected by this. "
	+"Note that the macro has been tested with a limited set of deconvolved images from a wide-field microscope (solely for the purposes of <i>Zahumensky et al., 2022</i>). "
	+"Proceed with caution and verify that the results make sense.<br>"
	+"</html>";

Dialog.create("Quantify transversal images");
	Dialog.addDirectory("Directory:", "");
//	Dialog.addDirectory("Directory:", "D:/Yeast/EXPERIMENTAL/macros/test/AS-M-000/");
	Dialog.addString("Subset (optional):", "");
	Dialog.addNumber("Channel:", 1);
	Dialog.addString("Naming scheme:", "strain,medium,time,condition,frame", 33);
	Dialog.addNumber("Min cell size (" + fromCharCode(181) + "m^2):", 5);
	Dialog.addNumber("Max cell size (" + fromCharCode(181) + "m^2):", "Infinity");
	Dialog.addNumber("Coefficient of variance (CV) threshold", 0);
	Dialog.addCheckbox("Deconvolved", false);
	Dialog.addHelp(html);
    Dialog.show();
	dir = Dialog.getString();
	subset = Dialog.getString();
	ch = Dialog.getNumber();
	naming_scheme = Dialog.getString();
	cell_size_min = Dialog.getNumber();
	cell_size_max = Dialog.getNumber();
	CV = Dialog.getNumber();
	DECON = Dialog.getCheckbox();
	
	dirMaster = dir; //directory into which Result summary is saved
	
	if (DECON == true) {
		SF = 0; 
		PP = 1.333;
	}

// clear LOG window and print header for analysis report (column names)
	getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
	print("\\Clear");
	print("# Basic macro run statistics:");
	print("# Macro version: "+version);
	print("# Channel: "+ch);
	print("# Cell size interval: "+cell_size_min+"-"+cell_size_max +" "+ fromCharCode(181) + "m^2");
	print("# Coefficient of variance threshold: "+CV);
	print("# Smoothing factor (Gauss): "+SF);
	print("# Patch prominence: "+PP);	
	print("# Date and time: "+year+"-"+month+1+"-"+dayOfMonth+" "+hour+":"+minute+":"+second);
	print("#");
//	print("exp_code,BR_date,strain,cult_medium,condition,frame#,mean_background,cell#,patches,patch_density,patch_intensity,PM_base,patch_prominence,cell_area,cell_I-integral,cell_I-mean,cell_I-SD,cytosol_area,cytosol_I-integral,cytosol_I-mean,cytosol_I-SD,cytosol_I-CV,PM_area,PM_I-integral,PM_I-mean,PM_I-SD,PM_I-CV,PM_I-div-Cyt_I(mean),prot_in_patches,patch_distance_min,patch_distance_max,patch_distance_mean,patch_distance_stdDev,patch_distance_CV,PM_I-div-cell_I(mean),Cyt_I-div-cell_I(mean),PM_I-div-cell_I(integral),Cyt_I-div-cell_I(integral)");	
	print("exp_code,BR_date," + naming_scheme + ",mean_background,cell#,patches,patch_density,patch_intensity,PM_base,patch_prominence,cell_area,cell_I-integral,cell_I-mean,cell_I-SD,cell_I-CV,cytosol_area,cytosol_I-integral,cytosol_I-mean,cytosol_I-SD,cytosol_I-CV,PM_area,PM_I-integral,PM_I-mean,PM_I-SD,PM_I-CV,PM_I-div-Cyt_I(mean),prot_in_patches,patch_distance_min,patch_distance_max,patch_distance_mean,patch_distance_stdDev,patch_distance_CV,PM_I-div-cell_I(mean),Cyt_I-div-cell_I(mean),PM_I-div-cell_I(integral),Cyt_I-div-cell_I(integral),major_axis,minor_axis,eccentricity");	

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
						extIndex = lastIndexOf(q, ".");
						ext = substring(q, extIndex+1);
						if (contains(extension_list, ext))
							measure();
					}			
				}
		}
	}
}

function contains(array, value) {
    for (i=0; i<array.length; i++) 
        if (array[i] == value) return true;
    return false;
}

// Preparatory step where image suffix (extension) is removed from filename. This makes the steps below simpler and more universal.
// The extension (ext1, ext2, ext3) are defined in the beginning of the macro
function prep() { 
	roiDir = replace(dir, "data", "ROIs");
   	run("Bio-Formats Windowless Importer", "open=[q]");
  	rename(list[i]);
	title = File.nameWithoutExtension;
	getDimensions(width, height, channels, slices, frames);
	getPixelSize(unit, pixelWidth, pixelHeight);
	Stack.setChannel(ch);
	run("Duplicate...", "duplicate channels="+ch);
	run("Gaussian Blur...", "sigma=SF");
	rename("DUP");
}

function measure_background() {
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
	close("DUP-CROP");
	close("Result of DUP-CROP");
}


function measure() {
	prep();
	measure_background();
	// quantification - open ROIs prepared with ROI_prep.ijm macro and cycle through them one by one
		roiManager("reset");
		roiManager("Open", roiDir+title+"-RoiSet.zip");
		roiManager("Remove Channel Info");
		numROIs = roiManager("count");
//		for(j=0; j<numROIs;j++) {
		for(j = 7; j <= 10; j++) {
// the shortened loop can be used for testing
			run("Set Measurements...", "area mean standard integrated fit redirect=None decimal=3");
			run("Clear Results");
			selectWindow(list[i]);
		if (DECON == true) wait(WC); else wait(W);	
			roiManager("Select", j);
		if (DECON == true) wait(WC); else wait(W);	
			run("Enlarge...", "enlarge=0.166"); //enlarge works with micometers
			run("Measure");
			cell_area = getResult("Area", 0);
			cell_int = getResult("IntDen", 0); // integrated cell intensity
			cell_int_BC = cell_int - cell_area * BC; // background correction
			cell_mean = getResult("Mean", 0);
			cell_mean_BC = cell_mean - BC; // backgorund correction
			cell_SD = getResult("StdDev", 0); // standard deviation of the mean intensity (does not change with background)
			cell_CV = cell_SD/cell_mean_BC;
			major_axis = getResult("Major", 0);
			minor_axis = getResult("Minor", 0);
			eccentricity = sqrt(1-pow(minor_axis/major_axis, 2));
			run("Clear Results"); // clear Results table to make it ready for next measurement
		if ((cell_area > cell_size_min)&&(cell_area < cell_size_max)&&(cell_CV > CV)){
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
		
		// preparation for measurements just below the plasma membrane
			selectWindow(list[i]); // selects raw microscopy image again
		wait(W);
			roiManager("Select", j);
			run("Enlarge...", "enlarge=-0.249");
//			run("Enlarge...", "enlarge=-0.166");
			run("Create Mask");
			rename("Mask-cyt-outer");
			selectWindow(list[i]); // selects raw microscopy image again
		wait(W);
			roiManager("Select", j);
			run("Enlarge...", "enlarge=-0.415");
//			run("Enlarge...", "enlarge=-0.332");
			run("Create Mask");
			rename("Mask-cyt-inner");
						
			imageCalculator("Subtract create", "Mask-cyt-outer","Mask-cyt-inner");
			selectWindow("Result of Mask-cyt-outer");
			run("Create Selection");
			selectWindow(list[i]);
			run("Restore Selection"); // transfer of the selection to the raw microscopy image
			run("Clear Results");
			run("Measure");
			CortCyt_mean = getResult("Mean", 0);
			CortCyt_mean_BC = CortCyt_mean - BC;
			CortCyt_mean_SD = getResult("StdDev", 0);
			
		//plasma membrane segmentation	
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
				D=0.332/pixelHeight; // conversion of plasma membrane thickness from micrometers to pixels
				run("Line Width...", "line=D");
				run("Set Measurements...", "mean standard min redirect=None decimal=3");
				run("Clear Results");
				run("Measure");
					PM_length = getResult("Length", 0); // length measured along the plasma membrane
					PM_StdDev = getResult("StdDev", 0);
//					Peak_MIN = 1.5*cyt_mean_BC+BC;
//					Peak_MIN = CortCyt_mean + CortCyt_mean_SD;
					Peak_MIN = CortCyt_mean;
					PEAK=PM_StdDev;
		selectWindow("DUP");
			wait(W);	
				run("Plot Profile");
				run("Find Peaks", "min._peak_amplitude=PEAK min._peak_distance=0 min._value=Peak_MIN max._value=[] list"); // "Find Peaks" is part of the BAR plugin package,available here: https://imagej.net/plugins/bar#installation 
					Table.rename("Plot Values", "Results");
					mins=0;
					PM_base_sum=0;
					for (k = 0; k < nResults; k++) {
						y=getResult("Y2",k);
						if (y > 0) {
							PM_base_sum=PM_base_sum+y;
							mins+=1;
						}
					}
					PM_base=PM_base_sum/mins;
					PM_base_BC=PM_base-BC;	

					if (PM_base_BC < CortCyt_mean_BC) {
						Peak_MIN = PP*cyt_mean_BC+BC;
					} else {
						Peak_MIN = PP*PM_base_BC+BC;
					}
				
//				PEAK=PM_StdDev*0.5;
				selectWindow("Plot of DUP");
			wait(W);
				run("Find Peaks", "min._peak_amplitude=PEAK min._peak_distance=0 min._value=Peak_MIN max._value=[] list");
					Table.rename("Plot Values", "Results");
					patches=0;
					patch_intensity_sum=0;
					for (k = 0; k < nResults; k++) {
						x=getResult("Y1",k);
						if (x > 0) {
							patch_intensity_sum=patch_intensity_sum+x;
							patches+=1;
						}
					}	
					patch_intensity=patch_intensity_sum/patches;
					patch_intensity_BC=patch_intensity-BC;																																																					
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
				
			patch_prominence=patch_intensity_BC/PM_base_BC;
			patch_density = patches/PM_length;
			prot_fraction_in_patches = (1 - PM_base_BC/PM_mean_BC)*100;
			
			cyt_div_cell = 100*cyt_mean_BC/cell_mean_BC;
			PM_div_cell = 100*PM_mean_BC/cell_mean_BC;
			cyt_div_cell_int = 100*cyt_int_BC/cell_int_BC;
			PM_div_cell_int = 100*PM_int_BC/cell_int_BC;
												
			parent = File.getParent(dir);
			grandparent = File.getParent(parent);
			parent_name = File.getName(parent);
			grandparent_name = File.getName(grandparent);
			BR_date = substring(parent_name, 0, 6);
			exp_code = substring(grandparent_name, 0, 8);
			
			
//			showMessage("report","BC: "+BC+"\ncyt_mean: "+cyt_mean+"\nCortCyt_mean: "+CortCyt_mean+"\nPM_mean: "+PM_mean+"\nPM_base: "+PM_base);
//waitForUser("report","BC: "+BC+"\ncyt_mean: "+cyt_mean+"\nCortCyt_mean: "+CortCyt_mean+"\nPM_mean: "+PM_mean+"\nPM_CV: "+PM_CV+"\nPM_base: "+PM_base);	
		
			print(exp_code+","+BR_date+","+title+","+BC+","+(j+1)+","+patches+","+patch_density+","+patch_intensity_BC+","+PM_base_BC+","+patch_prominence+","+cell_area+","+cell_int_BC+","+cell_mean_BC+","+cell_SD+","+cell_CV+","+cyt_area+","+cyt_int_BC+","+cyt_mean_BC+","+cyt_SD+","+cyt_CV+","+PM_area+","+PM_int_BC+","+PM_mean_BC+","+PM_SD+","+PM_CV+","+PM_div_Cyt+","+prot_fraction_in_patches+","+patch_distance_min+","+patch_distance_max+","+patch_distance_mean+","+patch_distance_stdDev+","+patch_distance_CV+","+PM_div_cell+","+cyt_div_cell+","+PM_div_cell_int+","+cyt_div_cell_int+","+major_axis+","+minor_axis+","+eccentricity);
			close("Mask-outer");
			close("Mask-inner");
			close("Mask-cyt-outer");
			close("Mask-cyt-inner");
			close("Result of Mask-outer");
			close("Result of Mask-cyt-outer");
			close("Plot of "+title);
			close("Peaks in Plot of "+title);
			close("Plot of DUP");
			close("Peaks in Plot of DUP");
		}
	}
		close("*");
		selectWindow("Log");
		saveAs("Text", dirMaster+"Summary-temporary");
}

getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
selectWindow("Log");
saveAs("Text", dir+"Summary of SECTIONS in channel "+ch+" ("+year+"-"+month+1+"-"+dayOfMonth+", "+hour+"-"+minute+"-"+second+").csv");
close("Summary of SECTIONS in channel " + ch + " (" + year+"-"+month+1+"-"+dayOfMonth+","+hour+"-"+minute+"-"+second + ").csv");
close("Results");
close("Log");
close("ROI manager");

waitForUser("Finito!", "Macro finished successfully.");