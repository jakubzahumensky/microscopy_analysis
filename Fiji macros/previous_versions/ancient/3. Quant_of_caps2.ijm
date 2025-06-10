//var cell_R = 2.25 //um, based on Vaskovicova et al., 2020
//var R=sqrt(cell_R/PI);
var R=1.4;
var cell_cutoff=5;
var title="";
var roiDir="";
var MasksDir="";
var px=0;
var N_eis=0;

setBackgroundColor(255, 255, 255);

Dialog.create("Quantify caps!");
	Dialog.addString("Directory:", "");
	Dialog.addString("Extension:", "czi");
	Dialog.addNumber("Channel:", 1); // Asks which channel should be exported. 1 as default.
    Dialog.show();
	dir = Dialog.getString();
	ext = Dialog.getString();
	ch = Dialog.getNumber();

print("\\Clear");
print("exp_code,BR_date,strain,medium,cultivation_time,frame,cell,area_fraction(patch_vs_ROI),density,size,size_SD,length,length_SD");

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
	if (endsWith(q, "." + ext)) {
	   	run("Bio-Formats Windowless Importer", "open=[q]");
		rename(list[i]);
		title = replace(list[i], "."+ext, "");
		//get pixel size in um
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
		prep();
		ROIs_to_ellipses();
		run("Set Measurements...", "mean area modal fit min redirect=None decimal=5");
		numROIs = roiManager("count");
		for(j=0; j<numROIs; j++) { // count eisosomes from RAW data using the "Find Maxima" plugin
			selectWindow(list[i]);
			roiManager("Select", j);
			run("Clear Results");
			run("Measure");
			MODE=getResult("Mode", 0);
			MAX=getResult("Max", 0);
			D=(MAX-MODE)/10;
			run("Clear Results");
			run("Find Maxima...", "prominence=D strict exclude output=Count");
			N_eis=getResult("Count", 0);
			density=N_eis/(R*R*PI);
		//make mask from current ROI
			if (N_eis > 0) {
				run("Duplicate...", " ");
				run("Despeckle");
				rename("MASK");
				run("Convert to Mask");
				run("Despeckle");
				makeOval(0, 0, 2*R/px, 2*R/px);
				run("Clear Results");
				run("Measure");	
				M=getResult("Mean", 0);
				if (M > 128) run("Invert"); // if patches are white, invert
					run("adjustable watershed", "tolerance=0.1");
					run("Clear Results");
					run("Measure");
					M=getResult("Mean", 0);
					area_fraction=M*100/255;
					if (M > 0) { // if there is any signal, continue
						run("Make Inverse");
						run("Clear", "slice");
						run("Translate...", "x=-1 y=-1 interpolation=None");
						run("Select None");
						makeOval(0, 0, 2*R/px, 2*R/px);
						run("Clear Results");
					//	run("Analyze Particles...", "show=Nothing display exclude clear");
						run("Analyze Particles...", "size=0.045-0.1 show=Nothing display exclude clear stack");
						N=nResults;
						//density=N/(R*R*PI);
						if (N > 1) { // summarize only if there is more than one patch
							run("Summarize");
							size=getResult("Area", N);
							size_SD=getResult("Area", N+1);
							length=getResult("Major", N);
							length_SD=getResult("Major", N+1);
						}
					}
						parent = File.getParent(dir);
						grandparent = File.getParent(parent);
						parent_name = File.getName(parent);
						grandparent_name = File.getName(grandparent);
						BR_date = substring(parent_name, 0, 6);
						exp_code = substring(grandparent_name, 0, 8);
							print(exp_code+","+BR_date+","+title+","+j+1+","+area_fraction+","+density+","+size+","+size_SD+","+length+","+length_SD);
							close("MASK");
			}
		}
	}
	close("*");
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