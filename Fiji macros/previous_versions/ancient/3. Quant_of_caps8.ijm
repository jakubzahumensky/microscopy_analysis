var title="";
var roiDir="";
var PatchesDir="";
var pixelHeight=0;
var N_eis=0;
var N=0;
var CV=0;
//var CV_T=0.7; //CV for discrimination of cells without patches
var CV_T=0; //CV for discrimination of cells without patches
var BC = 0;
var SF = 2/3; //scaling factor for circular ROI creation inside segmentation masks of tangential cell sections
var extension_list = newArray("czi", "oif", "lif", "tif");
version = "8"
setBackgroundColor(255, 255, 255);
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
	+"<b>Save segmentation masks</b><br>"
	+"Select if you wish to save segmentation masks of individual cells from which patch densities, sizes and shapes are measured."
	+"</html>";


Dialog.create("Quantify tangential sections");
	Dialog.addDirectory("Directory:", "");
	Dialog.addString("Subset (optional):", ""); // if left empy, all images are analyzed
	Dialog.addNumber("Channel:", 1); // Asks which channel should be exported. 1 as default.
	Dialog.addString("Naming scheme:", "strain,medium,time,condition,frame", 33);
	Dialog.addCheckbox("Save segmentation masks", false);
	Dialog.addHelp(html);
    Dialog.show();
	dir = Dialog.getString();
	subset = Dialog.getString();
	ch = Dialog.getNumber();
	naming_scheme = Dialog.getString();
	SaveMasks = Dialog.getCheckbox();

	dirMaster = dir;
	
	getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec)
	print("\\Clear");
	print("# Basic macro run statistics:")
	print("# Macro version: "+version);
	print("# Channel: "+ch);
	print("# Date and time: "+year+"-"+month+1+"-"+dayOfMonth+" "+hour+":"+minute+":"+second);
	print("#");
//	print("exp_code,BR_date,strain,medium,condition,frame#,cell#,density(find_maxima),density(analyze_particles),area_fraction(patch_vs_ROI),length,length_SD,width,width_SD,size,size_SD,mean_patch_intensity");
	print("exp_code,BR_date,"+naming_scheme+",cell#,density(find_maxima),density(analyze_particles),area_fraction(patch_vs_ROI),length,length_SD,width,width_SD,size,size_SD,mean_patch_intensity");
		
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
						extIndex = lastIndexOf(q, ".");
						ext = substring(q, extIndex+1);
						if (contains(extension_list, ext))
							measure_caps();
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

function prep() {
	roiDir = replace(dir, "data", "ROIs");
	if (SaveMasks == true) {
		PatchesDir = replace(dir, "data", "patches");
		File.makeDirectory(PatchesDir);
	}
	run("Bio-Formats Windowless Importer", "open=[q]");
	rename(list[i]);
	title = File.nameWithoutExtension;
	run("Select None");
	getDimensions(width, height, channels, slices, frames);
	getPixelSize(unit, pixelWidth, pixelHeight);
	Stack.setChannel(ch);
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

function measure_caps() {
	prep();
	measure_background();
	roiManager("reset");
	roiManager("Open", roiDir+title+"-RoiSet.zip");
	roiManager("Show All with labels");
	roiManager("Remove Channel Info");
	run("Set Measurements...", "area centroid mean standard modal min redirect=None decimal=5");
	numROIs = roiManager("count");
	for(j=0; j<numROIs; j++) { // count eisosomes from RAW data using the "Find Maxima" plugin
//	for(j=3; j<8; j++) {
		selectWindow(list[i]);
		roiManager("Select", j);
		run("Clear Results");
		run("Measure");
		Area = getResult("Area", 0);
//		R=sqrt(2*Area/3/PI);
		R=sqrt(SF*Area/PI);
		x=(getResult("X", 0)-R)/pixelHeight+1;
		y=(getResult("Y", 0)-R)/pixelHeight+1;
		makeOval(x, y, 2*R/pixelHeight, 2*R/pixelHeight);
waitForUser;		
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
		run("Find Maxima...", "prominence=MODE_ROI strict exclude output=Count");
//		run("Find Maxima...", "prominence=MODE_ROI strict exclude output=[Point Selection]");
//		if ((CV_ROI > CV_T) && (STN > 10)) N_eis=getResult("Count", 0);
		if (CV_ROI > CV_T)
			N_eis=getResult("Count", 0);
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
//				makeOval(0, 0, 2*R/pixelHeight, 2*R/pixelHeight);
				run("Clear Results");
				run("Measure");	
				M=getResult("Mean", 0);
				if (M > 128)
					run("Invert"); // if patches are white, invert
				run("Adjustable Watershed", "tolerance=0.01");
				if (SaveMasks == true) {
					saveAs("PNG", PatchesDir+list[i]+"-"+j);
					rename("MASK");
				}
				run("Clear Results");
				run("Measure");
				M=getResult("Mean", 0);
				if (M > 0) { // if there is any signal, continue
					run("Make Inverse");

//					run("Translate...", "x=-1 y=-1 interpolation=None");
					run("Select None");
					makeOval(0, 0, 2*R/pixelHeight, 2*R/pixelHeight);
					run("Clear Results");
					run("Set Measurements...", "area mean standard modal min centroid fit redirect=None decimal=5");
					run("Analyze Particles...", "size=0-5 show=Nothing display exclude clear stack");
					N=nResults;
					if (N > 0) {
						size=getResult("Area", 0);
						length=getResult("Major", 0);
						width=getResult("Minor", 0);
						density=N/(R*R*PI);
						area_fraction=size*density*100;
					}
					if (N > 1) { // summarize only if there is more than one patch
						run("Set Measurements...", "area mean standard modal min centroid fit redirect=None decimal=5");
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
	saveAs("Text", dirMaster+"Summary-temporary");		
}


getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
selectWindow("Log");
saveAs("Text", dir+"Summary of CAPS in channel "+ch+" ("+year+"-"+month+1+"-"+dayOfMonth+", "+hour+"-"+minute+"-"+second+").csv");
close("Summary of CAPS in channel " + ch + " (" + year+"-"+month+1+"-"+dayOfMonth+","+hour+"-"+minute+"-"+second + ").csv");
close("Results");
close("Log");
close("ROI manager");

waitForUser("Finito!", "Macro finished successfully.");