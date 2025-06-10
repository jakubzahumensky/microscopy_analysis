//var cell_R = 2.25 //um, based on Vaskovicova et al., 2020
//var R=sqrt(cell_R/PI);
var R=1.4;
var cell_cutoff=5;
var title="";
var roiDir="";
var MasksDir="";
var px=0;
var N_eis=0;

//ext1 = "czi";
ext1 = "xxxxxx";
ext2 = "oif";
ext3 = "tif";

setBackgroundColor(255, 255, 255);

Dialog.create("Select folder");
	Dialog.addString("Dir:", "");
	Dialog.show();
	dir = Dialog.getString();

//dir="D:/Yeast/EXPERIMENTAL/microscopy/PV-M-2112/isc1BY_Pil1-GFP/analysis/data/"
//dir="D:/Yeast/EXPERIMENTAL/macro_development/JZ-IJ-004 - Cap quantification/test/data/"

print("\\Clear");
print("strain,cultivation_time,medium,frame,cell,area_fraction(patch/ROI),density,density2,size,size_SD,length,length_SD");

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
	if (endsWith(q, "."+ext1)||endsWith(q, "."+ext2)||endsWith(q, "."+ext3)) {
	   	run("Bio-Formats Windowless Importer", "open=[q]");
		rename(list[i]);
		title = replace(list[i], "."+ext1, "");
		title = replace(title, "."+ext2, "");
		title = replace(title, "."+ext3, "");
		//get pixel size in um
		//selectWindow(title+"."+ext);
		run("Select None");
		getDimensions(width, height, channels, slices, frames);
		run("Set Measurements...", "mean area min redirect=None decimal=5");
		run("Clear Results");
		run("Measure");
		px=sqrt(getResult("Area", 0)/width/height);
//       	if (channels>2) Stack.setChannel(2);
  
	}
}

//make circular ROIs from segmentation ROIs
function ROIs_to_ellipses() {
	roiManager("reset");
	roiManager("Open", roiDir+title+"-RoiSet.zip");
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
/*
//count maxima
function count_eis() {
	numROIs = roiManager("count");
	for(j=numROIs-1; j>=0 ; j--) {
			roiManager("Select", j);
			run("Clear Results");
			run("Find Maxima...", "prominence=10 strict exclude output=Count");
			N_eis=getResult("Count", 0);
	}
}
*/

function measure_caps() {
	if (endsWith(dir, "data/")) {
		prep();
		ROIs_to_ellipses();
		
		//make mask
		run("Duplicate...", " ");
		rename("MASK");
		run("Convert to Mask");
		run("Clear Results");
		run("Measure");
		M=getResult("Mean", 0);
		//waitForUser;
		if (M > 128) run("Invert");
		
		run("Adjustable Watershed", "tolerance=0.1");
		
		numROIs = roiManager("count");
		run("Set Measurements...", "mean area fit redirect=None decimal=5");
		for(j=0; j<numROIs; j++) {
			selectWindow("MASK");
			roiManager("Select", j);
			run("Clear Results");
			roiManager("Measure");
			M=getResult("Mean", 0);
			area_fraction=M*100/255;
			if ( M > 0 ) {
				run("Duplicate...", " ");
				rename("dup");
				run("Make Inverse");
				run("Clear", "slice");
				run("Translate...", "x=-1 y=-1 interpolation=None");
				run("Select None");
				makeOval(0, 0, 2*R/px, 2*R/px);
				run("Analyze Particles...", "  show=Nothing display exclude clear");
				N=nResults;
				density=N/(R*R*PI);
				density2=N_eis/(R*R*PI);
				close("dup");
				if (N > 1) {
					selectWindow("MASK");
					roiManager("Select", j);
					run("Analyze Particles...", "  show=Nothing display exclude clear");
					N=nResults;
					run("Summarize");
					size=getResult("Area", N);
					size_SD=getResult("Area", N+1);
					length=getResult("Major", N);
					length_SD=getResult("Major", N+1);
					print(title+","+j+1+","+area_fraction+","+density+","+density2+","+size+","+size_SD+","+length+","+length_SD);
				}
			}
			
		}
	}
	close("*");
}

selectWindow("Log");
saveAs("Text", dir+"Summary.csv");
date = File.dateLastModified(dir+"Summary.csv");
date2 = replace(date, ":", "-");
saveAs("Text", dir+"Summary ("+date2+").csv");
File.delete(dir+"Summary.csv");
close("Summary ("+date2+").csv");

close("Results");
close("Log");
close("ROI manager");

waitForUser("Finito!");