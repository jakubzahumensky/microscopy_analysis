var border=0.3; //value needs to be adjusted based on actual microscopy images
var cell_cutoff=5;
var title="";
var roiDir="";
var MasksDir="";

var ext1 = "czi";
var ext2 = "oif";
var ext3 = "tif";

dir = getDirectory("Choose a Directory");
types = newArray("Convert Masks to ROIs", "Check ROIs", "Measure");
Dialog.create("Example Dialog");
	Dialog.addChoice("Type:", types);
	Dialog.show();
	type = Dialog.getChoice();

print("\\Clear");
print("exp_code,BR_date,strain,condition,frame#,mean_background,cell#,patches,patch_density,patch_intensity,PM_base,patch_prominence,cell_area,cell_I-integral,cell_I-mean,cell_I-SD,cytosol_area,cytosol_I-integral,cytosol_I-mean,cytosol_I-SD,cytosol_I-CV,PM_area,PM_I-integral,PM_I-mean,PM_I-SD,PM_I-CV,PM_I-mean/Cyt_I-mean");	

processFolder(dir);

function processFolder(dir) {
   list = getFileList(dir);
   for (i=0; i<list.length; i++) {
      showProgress(i+1, list.length);
      if (endsWith(list[i], "/"))
        processFolder(""+dir+list[i]);
      else {
		q = dir+list[i];
		if (matches(type, "Convert Masks to ROIs"))
			Map_to_ROIs();
			else 
			if (matches(type, "Check ROIs"))
			ROI_check();
			else measure();		
		}
	}
}

function prep() {
	roiDir = replace(dir, "data", "ROIs");
	MasksDir = replace(dir, "data", "Masks");
	if (endsWith(q, "." + ext1)||endsWith(q, "." + ext2)||endsWith(q, "." + ext3)) {
	   	run("Bio-Formats Windowless Importer", "open=[q]");
		rename(list[i]);
		title = replace(list[i], "."+ext1, "");
		title = replace(title, "."+ext2, "");
		title = replace(title, "."+ext3, "");

		getDimensions(width, height, channels, slices, frames);
//       	if (channels>2) Stack.setChannel(2);
	}
}



function Map_to_ROIs() {
	if (endsWith(dir, "data/")) {
		prep();

		File.makeDirectory(roiDir);
		run("Set Measurements...", "area bounding redirect=None decimal=3");
		run("Clear Results");
		run("Measure");
		image_W=getResult("Width", 0);
		image_H=getResult("Height", 0);
		open(MasksDir+"MASK_"+title+".tif");
	//	open(MasksDir+title+"_cp_masks.png");
		roiManager("reset");
		run("LabelMap to ROI Manager (2D)");
		selectWindow(list[i]);
		numROIs = roiManager("count");
		for(j=numROIs-1; j>=0 ; j--) {
			run("Clear Results");
			roiManager("Select", j);
			run("Set Measurements...", "area bounding redirect=None decimal=3");
			run("Measure");
			A=getResult("Area", 0);
			w=getResult("Width", 0);
			h=getResult("Height", 0);
			BX=getResult("BX", 0);
			BY=getResult("BY", 0);
			a=BX<border;
			b=BY<border;
			c=(BX+w)>(image_W-border);
			d=(BY+h)>(image_H-border);
			e=A<cell_cutoff;
			if (a+b+c+d+e>0) roiManager("Delete");
		}
		roiManager("Save", roiDir+title+"-RoiSet.zip");
		close("*");
	}
}


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
		run("Maximize");
		waitForUser("Check");
		roiManager("Save", roiDir+title+"-RoiSet.zip");
		close("*");
	}
}


function measure() {
	if (endsWith(dir, "data/")) {
		prep();
        	
	//background measurement
		run("Set Measurements...", "mean min redirect=None decimal=3");
		run("Clear Results");
		run("Measure");
		MIN=getResult("Min", 0);
		setThreshold(0, MIN*1.5);
		run("Create Selection");
		run("Measure");
		BC=getResult("Mean", 1);
	
	//quantification
		roiManager("reset");
		roiManager("Open", roiDir+title+"-RoiSet.zip");
		numROIs = roiManager("count");
		for(j=0; j<numROIs;j++) {
		//for(j=0; j<2;j++) {
			run("Set Measurements...", "area mean standard integrated redirect=None decimal=3");
			run("Clear Results");
			roiManager("Select", j);
				run("Fit Ellipse");
				run("Enlarge...", "enlarge=3 pixel");
				run("Measure");
				cell_area = getResult("Area", 0);
				cell_int = getResult("IntDen", 0);
				cell_int_BC = cell_int - cell_area * BC;
				cell_mean = getResult("Mean", 0);
				cell_mean_BC = cell_mean - BC;
				cell_SD = getResult("StdDev", 0);
				run("Clear Results");
				run("Create Mask");
				rename("Mask-outer");
			selectWindow(list[i]);
			roiManager("Select", j);
				run("Fit Ellipse");
				run("Enlarge...", "enlarge=-3 pixel");
				run("Measure");
				cyt_area = getResult("Area", 0);
				cyt_int = getResult("IntDen", 0);
				cyt_int_BC = cyt_int - cyt_area * BC;
				cyt_mean = getResult("Mean", 0);
				cyt_mean_BC = cyt_mean - BC;
				cyt_SD = getResult("StdDev", 0);
				cyt_CV = cyt_SD/cyt_mean_BC;
				PM_area = cell_area-cyt_area;
				PM_int_BC = cell_int_BC-cyt_int_BC;
				run("Create Mask");
				rename("Mask-inner");
				imageCalculator("Subtract create", "Mask-outer","Mask-inner");
				selectWindow("Result of Mask-outer");
				run("Create Selection");
			selectWindow(list[i]);
			run("Restore Selection");
			run("Clear Results");
			run("Measure");
				PM_mean = getResult("Mean", 0);
				PM_mean_BC = PM_mean - BC;
				PM_SD = getResult("StdDev", 0);
				PM_CV = PM_SD/PM_mean_BC;
				PM_div_Cyt = PM_mean_BC/cyt_mean_BC;
			selectWindow(list[i]);
			roiManager("Select", j);
				run("Fit Ellipse");
				run("Area to Line");
				run("Line Width...", "line=6");
				run("Set Measurements...", "standard redirect=None decimal=3");
				run("Clear Results");
				run("Measure");
					PM_length = getResult("Length", 0);
					PM_StdDev = getResult("StdDev", 0);
				run("Plot Profile");
				run("Find Peaks", "min._peak_amplitude="+1.25*PM_StdDev+" min._peak_distance=0 min._value=[] max._value=[] exclude list");
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
close("Summary ("+date2+").csv");

close("Results");
close("Log");
close("ROI manager");

waitForUser("Finito!");