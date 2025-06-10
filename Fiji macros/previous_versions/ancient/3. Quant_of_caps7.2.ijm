//var cell_R = 2.25 //um, based on Vaskovicova et al., 2020
//var R=sqrt(cell_R/PI);
var R=1.4;
var title="";
var roiDir="";
var MasksDir="";
var PatchesDir="";
var px=0;
var N_eis=0;
var N=0;
var CV=0;
var CV_T=0.7; //CV for discrimination of cells without patches
NAME = "3. Quant_of_caps7.ijm"
setBackgroundColor(255, 255, 255);

Dialog.create("Quantify caps!");
	Dialog.addString("Directory:", "");
	Dialog.addString("Subset (optional):", ""); // if left empy, all images are analyzed
	Dialog.addString("Extension:", "czi");
	Dialog.addNumber("Channel:", 1); // Asks which channel should be exported. 1 as default.
	Dialog.addCheckbox("Save segmentation masks", false);
    Dialog.show();
	dir = Dialog.getString();
	subset = Dialog.getString();
	ext = Dialog.getString();
	ch = Dialog.getNumber();
	SaveMasks = Dialog.getCheckbox();

	dirM = dir;
	
	getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec)
	print("\\Clear");
	print("# Basic macro run statistics:")
	print("# Macro: "+NAME);
	print("# ROI radius: "+R+" um");
	print("# Channel: "+ch);
	print("# Date and time: "+year+"-"+month+1+"-"+dayOfMonth+" "+hour+":"+minute+":"+second);
	print("exp_code,BR_date,strain,medium,condition,frame#,cell#,density(find_maxima),density(analyze_particles),area_fraction(patch_vs_ROI),length,length_SD,width,width_SD,size,size_SD,mean_patch_intensity");
//	print("exp_code,BR_date,strain,medium,condition,frame#,cell#,BC,CV,MAX,MEAN,MEAN_BC,SD");
		
processFolder(dir);

function processFolder(dir) {
   list = getFileList(dir);
   for (i=0; i<list.length; i++) {
      showProgress(i+1, list.length);
      if (endsWith(list[i], "/"))
        processFolder(""+dir+list[i]);
      else {
		q = dir+list[i];
		if (endsWith(dir, "data-caps/")) {
			if (indexOf(q, subset) >= 0) {
				measure_caps();
			}			
		}
		}
	}
}

function prep() {
	roiDir = replace(dir, "data", "ROIs");
	MasksDir = replace(dir, "data", "Masks");
	if (SaveMasks == true) {
		PatchesDir = replace(dir, "data", "patches");
		File.makeDirectory(PatchesDir);
	}
	
	if (endsWith(q, "." + ext)) {
	   	run("Bio-Formats Windowless Importer", "open=[q]");
		rename(list[i]);
		title = replace(list[i], "."+ext, "");
		run("Select None");
		getDimensions(width, height, channels, slices, frames);
		if (channels > 1) Stack.setChannel(ch);
		run("Set Measurements...", "area mean standard modal min redirect=None decimal=5");
		run("Clear Results");
		run("Measure");
		px=sqrt(getResult("Area", 0)/width/height);
	}
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



//make circular ROIs from segmentation ROIs
function ROIs_to_circles() {
	roiManager("reset");
	roiManager("Open", roiDir+title+"-RoiSet.zip");
	roiManager("Remove Channel Info");
	numROIs = roiManager("count");
	for(j=numROIs-1; j>=0 ; j--) {
		roiManager("Select", j);
		run("Fit Ellipse");
		run("Set Measurements...", "centroid redirect=None decimal=5");
		run("Clear Results");
		run("Measure");
		x=(getResult("X", 0)-R)/px;
		y=(getResult("Y", 0)-R)/px;
		makeOval(x, y, 2*R/px, 2*R/px);
		roiManager("Add");
		roiManager("Select", j);
		roiManager("Delete");
		}
//	roiManager("Save", roiDir+title+"-RoiSet.zip");
}

function measure_caps() {
	prep();
	measure_background();
		
//	ROIs_to_circles();
	
	run("Set Measurements...", "mean standard area modal fit min centroid redirect=None decimal=5");
	numROIs = roiManager("count");
	for(j=0; j<numROIs; j++) { // count eisosomes from RAW data using the "Find Maxima" plugin
//		for(j=6; j<8; j++) {
		selectWindow(list[i]);
		roiManager("Select", j);
		run("Clear Results");
		run("Measure");

		
		
		
		
		
		MODE_ROI=getResult("Mode", 0);
		MEAN_ROI=getResult("Mean", 0);
		MIN_ROI=getResult("Mean", 0);
		MAX_ROI=getResult("Max", 0);
		MEAN_ROI_BC = MEAN_ROI - BC;
		SD_ROI=getResult("StdDev", 0);
		CV_ROI=SD_ROI/MEAN_ROI_BC;
//		STN = (MAX_ROI-BC)/(MEAN_ROI-BC);
//		STN = (MAX_ROI-BC)/(MIN_ROI-BC);
		N_eis=0;
		run("Clear Results");
//		run("Find Maxima...", "prominence=MODE_ROI strict exclude output=Count");
		run("Find Maxima...", "prominence=MODE_ROI strict exclude output=[Point Selection]");
//		if ((CV_ROI > CV_T) && (STN > 10)) N_eis=getResult("Count", 0);
		if (CV_ROI > CV_T) N_eis=getResult("Count", 0);
		density2=N_eis/(R*R*4);
		area_fraction=0;
		size=NaN;
		size_SD=NaN;
		length=NaN;
		length_SD=NaN;
		width=NaN;
		width_SD=NaN;
		density=0;
		MEAN2=NaN;
		MEAN_P=NaN;
//print(N_eis+", "+CV);
//waitForUser;			
//make mask from current ROI
//		if ((N_eis > 0) && (CV_ROI > CV_T) && (STN > 10)) {
		if (N_eis > 0) {
			run("Duplicate...", "duplicate channels="+ch);
			rename("DUP");
			run("Duplicate...", " ");
			rename("DUP2");
			selectWindow("DUP");
			run("Enhance Contrast", "saturated=0.01"); 
			run("Despeckle");
			run("Subtract Background...", "rolling=3");
			run("Enhance Local Contrast (CLAHE)", "blocksize=64 histogram=64 maximum=3 mask=*None*");				
			run("Select None");
			run("Clear Results");
			run("Measure");
			MAX2=getResult("Max", 0);
			MODE2=getResult("Mode", 0);
			if (MAX2 > MODE2*2) setThreshold(MAX2/2+MODE2, 65535); else	{setThreshold(MODE2*2, 65535);}
				run("Create Selection");
				selectWindow("DUP2");
				run("Restore Selection");
				run("Clear Results");
				run("Measure");
				MEAN_P=getResult("Mean", 0);
				selectWindow("DUP");
				run("Clear Results");
				run("Measure");
				MEAN2=getResult("Mean", 0);
				run("Select None");
				setThreshold((MEAN2+MAX2)/4+MODE2, 65535);
//					setThreshold((2*MEAN2+MAX2)/6+MODE2, 65535);
				run("Create Mask");
				run("Despeckle");
				rename("MASK");
//				makeOval(0, 0, 2*R/px, 2*R/px);
				run("Clear Results");
				run("Measure");	
				M=getResult("Mean", 0);
				if (M > 128) run("Invert"); // if patches are white, invert
				run("Adjustable Watershed", "tolerance=0.01");
				if (SaveMasks == true) saveAs("PNG", PatchesDir+list[i]+"-"+j);
				rename("MASK");
				run("Clear Results");
				run("Measure");
				M=getResult("Mean", 0);
				if (M > 0) { // if there is any signal, continue
					run("Make Inverse");
					run("Clear", "slice");
					run("Translate...", "x=-1 y=-1 interpolation=None");
					run("Select None");
					makeOval(0, 0, 2*R/px, 2*R/px);
					run("Clear Results");
					run("Analyze Particles...", "size=0-0.36 show=Nothing display exclude clear stack");
					N=nResults;
					if (N > 0) {
						size=getResult("Area", 0);
						length=getResult("Major", 0);
						width=getResult("Minor", 0);
						density=N/(R*R*PI);
						area_fraction=size*density*100;
					}
					if (N > 1) { // summarize only if there is more than one patch
						run("Summarize");
						size=getResult("Area", N);
						size_SD=getResult("Area", N+1);
						length=getResult("Major", N);
						length_SD=getResult("Major", N+1);
						width=getResult("Minor", N);
						width_SD=getResult("Minor", N+1);
						density=N/(R*R*PI);
						area_fraction=size*density*100;
					}
				}
	//	saveAs("PNG", PatchesDir+list[i]+"-"+j);
		//close();
		//rename("MASK");
		close("MASK");
		close("DUP");
		close("DUP2");
		}
		parent = File.getParent(dir);
		grandparent = File.getParent(parent);
		parent_name = File.getName(parent);
		grandparent_name = File.getName(grandparent);
		BR_date = substring(parent_name, 0, 6);
		exp_code = substring(grandparent_name, 0, 8);
		MEAN_P_BC=MEAN_P-BC;
		print(exp_code+","+BR_date+","+title+","+j+1+","+density2+","+density+","+area_fraction+","+length+","+length_SD+","+width+","+width_SD+","+size+","+size_SD+","+MEAN_P_BC);
//		print(exp_code+","+BR_date+","+title+","+j+1+","+BC+","+CV_ROI+","+MAX_ROI+","+MEAN_ROI+","+MEAN_ROI_BC+","+SD_ROI);
	}
	close("*");
	selectWindow("Log");
	saveAs("Text", dirM+"Summary-temporary");		
}


getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
selectWindow("Log");
saveAs("Text", dir+"Summary of CAPS in channel "+ch+" ("+year+"-"+month+1+"-"+dayOfMonth+", "+hour+"-"+minute+"-"+second+").csv");
close("Summary of CAPS in channel " + ch + " (" + year+"-"+month+1+"-"+dayOfMonth+","+hour+"-"+minute+"-"+second + ").csv");
close("Results");
close("Log");
close("ROI manager");

showMessage("Finito!", "Macro finished successfully.");