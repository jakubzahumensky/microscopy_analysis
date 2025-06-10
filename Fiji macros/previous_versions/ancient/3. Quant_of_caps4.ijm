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
NAME = "3. Quant_of_caps4.ijm"
setBackgroundColor(255, 255, 255);

Dialog.create("Quantify caps!");
	Dialog.addString("Directory:", "");
	Dialog.addString("Extension:", "czi");
	Dialog.addNumber("Channel:", 1); // Asks which channel should be exported. 1 as default.
//	Dialog.addNumber("Smoothing factor (Gauss):", 0.5);
    Dialog.show();
	dir = Dialog.getString();
	ext = Dialog.getString();
	ch = Dialog.getNumber();
//	SF = Dialog.getNumber();

	getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec)
	print("\\Clear");
	print("# Basic macro run statistics:")
	print("# Macro: "+NAME);
	print("# ROI radius: "+R+" um");
	print("# Channel: "+ch);
//	print("# Smoothing factor (Gauss): "+SF);
	print("# Date and time: "+year+"-"+month+"-"+dayOfMonth+" "+hour+":"+minute+":"+second);
	print("exp_code,BR_date,strain,medium,condition,frame#,cell#,area_fraction(patch_vs_ROI),density(analyze_particles),density(find_maxima),size,size_SD,length,length_SD,mean_patch_intensity,width,width_SD");

processFolder(dir);

function processFolder(dir) {
   list = getFileList(dir);
   for (i=0; i<list.length; i++) {
      showProgress(i+1, list.length);
      if (endsWith(list[i], "/"))
        processFolder(""+dir+list[i]);
      else {
		q = dir+list[i];
		measure_caps();
		}
	}
}

function prep() {
	roiDir = replace(dir, "data", "ROIs");
	MasksDir = replace(dir, "data", "Masks");
//	PatchesDir = replace(dir, "data", "patches");
//	File.makeDirectory(PatchesDir);
	if (endsWith(q, "." + ext)) {
	   	run("Bio-Formats Windowless Importer", "open=[q]");
		rename(list[i]);
		title = replace(list[i], "."+ext, "");
		run("Select None");
		getDimensions(width, height, channels, slices, frames);
		if (channels > 1) Stack.setChannel(ch);
		run("Set Measurements...", "mean area modal min redirect=None decimal=5");
		run("Clear Results");
		run("Measure");
		px=sqrt(getResult("Area", 0)/width/height);
	}
}

//make circular ROIs from segmentation ROIs
function ROIs_to_ellipses() {
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
}

function measure_caps() {
	if (endsWith(dir, "data-caps/")) {
	//if (endsWith(dir, "data/")) {
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
		
		ROIs_to_ellipses();
		run("Set Measurements...", "mean area modal fit min redirect=None decimal=5");
		numROIs = roiManager("count");
		for(j=0; j<numROIs; j++) { // count eisosomes from RAW data using the "Find Maxima" plugin
			selectWindow(list[i]);
			roiManager("Select", j);
			run("Clear Results");
			run("Measure");
			MODE=getResult("Mode", 0);
			run("Clear Results");
			run("Find Maxima...", "prominence=MODE strict exclude output=Count");
			N_eis=getResult("Count", 0);
			density2=N_eis/(R*R*4);
			area_fraction=NaN;
			size=NaN;
			size_SD=NaN;
			length=NaN;
			length_SD=NaN;
			width=NaN;
			width_SD=NaN;
			density=NaN;
			MEAN2=NaN;
		//make mask from current ROI
			if (N_eis > 0) {
				run("Duplicate...", "duplicate channels="+ch);
				rename("DUP");
				run("Despeckle");
				run("Select None");
				run("Clear Results");
				run("Measure");
				MAX2=getResult("Max", 0);
				MODE2=getResult("Mode", 0);
				if (MAX2 > MODE2*2) setThreshold(MAX2/2+MODE2, 65535); else	{setThreshold(MODE2*2, 65535);}
			//	setThreshold(MODE*2, 65535);
					run("Create Selection");
					run("Measure");
					MEAN2=getResult("Mean", 0);
					run("Select None");
					//setThreshold((MEAN2+MAX2)/4+MODE2, 65535);
					setThreshold((2*MEAN2+MAX2)/6+MODE2, 65535);
					run("Create Mask");
					run("Despeckle");
					rename("MASK");
					makeOval(0, 0, 2*R/px, 2*R/px);
					run("Clear Results");
					run("Measure");	
					M=getResult("Mean", 0);
					if (M > 128) run("Invert"); // if patches are white, invert
					run("Adjustable Watershed", "tolerance=0.01");
//					saveAs("PNG", PatchesDir+list[i]+"-"+j);
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
			}
			parent = File.getParent(dir);
			grandparent = File.getParent(parent);
			parent_name = File.getName(parent);
			grandparent_name = File.getName(grandparent);
			BR_date = substring(parent_name, 0, 6);
			exp_code = substring(grandparent_name, 0, 8);
			MEAN2_BC=MEAN2-BC;
			print(exp_code+","+BR_date+","+title+","+j+1+","+area_fraction+","+density+","+density2+","+size+","+size_SD+","+length+","+length_SD+","+MEAN2_BC+","+width+","+width_SD);	
		}
		close("*");
	}
}

selectWindow("Log");
saveAs("Text", dir+"Summary.csv");
date = File.dateLastModified(dir+"Summary.csv");
date2 = replace(date, ":", "-");
saveAs("Text", dir+"Summary for channel " + ch + " (" + date2 + ").csv");
File.delete(dir+"Summary.csv");
close("Summary for channel " + ch + " (" + date2 + ").csv");

close("Results");
close("Log");
close("ROI manager");

waitForUser("Finito!");
