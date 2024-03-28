setBatchMode(true);

var version = "2";
var title = "";
var roiDir = "";
var extension_list = newArray("czi", "oif", "lif", "tif", "vsi");
var windows = newArray("Mask-inner","Mask-outer","Mask","C1-DUP","C2-DUP");
var area_select = newArray("whole frame", "whole cell", "plasma membrane", "cytosol");
var DirType = "data/";
var BR_date = "YYMMDD"
var exp_code = "ExpCode"
var RW0 = "Coloc_temp.csv";
var RW = "["+RW0+"]";
var RM = "";
var WARNING = "";
var E = "";
var threshold_method = newArray("Bisection", "Costes");

var BC = newArray(2);
var P = 0;
var tM1 = 0;
var tM2 = 0;
var Li = 0;
var K = 0;
var S = 0;

Dialog.create("Quantify colocalization");
//	Dialog.addDirectory("Directory:", "");
	Dialog.addDirectory("Directory:", "D:/Yeast/EXPERIMENTAL/microscopy/JZ-M-064-230413 - Candida - test/");
	Dialog.addString("Subset (optional):", "");
	Dialog.addString("Naming scheme:", "strain,medium,time,condition,frame", 33);	
	Dialog.addString("Experiment code scheme:", "XY-M-000", 33);
	Dialog.addChoice("Regions of interest:", area_select);
	Dialog.addChoice("Thresholding:", threshold_method);
	Dialog.addNumber("Red channel:", "1");
	Dialog.addNumber("Green channel:", "2");
    Dialog.show();
	dir = Dialog.getString();
	subset = Dialog.getString();
	naming_scheme = Dialog.getString();
	experiment_scheme = Dialog.getString();
	ROI_type = Dialog.getChoice();
	threshold = Dialog.getChoice();
	R = Dialog.getNumber();			
	G = Dialog.getNumber();
	RGB = newArray(R,G);

	if (matches(ROI_type, "plasma membrane")) RM = "[Mask]";	
	if (matches(ROI_type, "whole cell")) RM = "[ROI(s) in channel 1]"; //this needs to be checked
	if (matches(ROI_type, "whole frame")) RM = "<None>";

dirMaster = dir; //directory into which Result summary is saved

initialize();
processFolder(dir);
saveResults();

//_______________________________________________________FUNCTIONS_______________________________________________________
function initialize(){
	close("*");
	print("\\Clear");
	roiManager("reset");
	run("Clear Results");
//	if (isOpen(RW0))
//		print(RW, "\\Update:"); // clears the window
//	else
	run("Text Window...", "name="+RW+"width=256 height=32");
	getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
	print(RW,"# Basic macro run statistics:\n");
	print(RW,"# Date and time: "+year+"-"+month+1+"-"+dayOfMonth+" "+hour+":"+minute+":"+second+"\n");
	print(RW,"# Macro version: "+version+"\n");
	print(RW,"# Thresholding method: "+threshold+"\n");
	print(RW,"# IMPORTANT note on thresholding: \n");
	print(RW,"# Thresholding affects Pearson's and Mander's coefficients.\n");
	print(RW,"# If there is a warning these values should be discarded.\n");
	print(RW,"# They are marked with an * and are automatically excluded from graphs and analysis in GraphPad Prism\n");
	print(RW,"# The other parameters are unaffected by thresholding and are safe to use.\n");
	print(RW,"#\n");
	print(RW,"exp_code,BR_date," + naming_scheme + ",background-red_ch,background-green_ch,cell,Pearson,tManders_red_ch,tManders_green-ch,Li(ICQ),Kendall_tau,Spearman,warning\n");
}

function processFolder(dir) {
	list = getFileList(dir);
	for (i = 0; i < list.length; i++) {
		if (endsWith(list[i], "/"))
			processFolder(""+dir+list[i]);
		else {
			q = dir+list[i];
			if (endsWith(dir, DirType)) {
				if (indexOf(q, subset) >= 0) {
					extIndex = lastIndexOf(q, ".");
					ext = substring(q, extIndex + 1);
					if (contains(extension_list, ext))
						processFile(q);
				}			
			}
		}
	}
}

function processFile(q) {
	prep();
	if (matches(ROI_type, "whole frame")){
		extract_coefficients(title);		
		find_parents(dir);
		res = exp_code+","+BR_date+","+list[i]+","+BC[R-1]+","+BC[G-1]+","+","+P+E+","+tM1+E+","+tM2+E+","+Li+","+K+","+S+","+WARNING+"\n";
	} else {
		roiManager("reset");
		roiManager("Open", roiDir+title+"-RoiSet.zip");
		roiManager("Remove Channel Info");
		numROIs = roiManager("count");
		for (j = 0; j <= numROIs-1; j++) {
			if (matches(ROI_type, "plasma membrane")) 
				PM_mask(title,j);
			else 
				cell(title,j);
		extract_coefficients(title);		
		find_parents(dir);
		res = exp_code+","+BR_date+","+list[i]+","+BC[R-1]+","+BC[G-1]+","+j+1+","+P+E+","+tM1+E+","+tM2+E+","+Li+","+K+","+S+","+WARNING+"\n";
		}
	}
	print(RW, res);
	WARNING = "";
	E = "";
	close("*");
	selectWindow(RW0);
	saveAs("Text", dirMaster+RW0);
}


function contains(array, value) {
    for (i = 0; i < array.length; i++) 
        if (array[i] == value) return true;
    return false;
}

function prep() {
	roiDir = replace(dir, "data", "ROIs");
	run("Bio-Formats Windowless Importer", "open=[q]");
	run("Smooth", "stack");
	rename(list[i]);
	title = File.nameWithoutExtension;
//	run("Select None");
	getDimensions(width, height, channels, slices, frames);
	getPixelSize(unit, pixelWidth, pixelHeight);
	selectWindow(list[i]);
	run("Select None");
	run("Set Measurements...", "mean standard modal min redirect=None decimal=3");
	for (ch = 0; ch <= 1; ch++) {
		run("Duplicate...", "duplicate channels="+RGB[ch]);
		run("Clear Results");
		run("Measure");
		MIN = getResult("Min", 0);
		rename("DUP-CROP");
		run("Duplicate...", "duplicate");
		rename("DUP-CROP-BC");
		run("Subtract Background...", "rolling="+width+" stack");
		imageCalculator("Difference create stack", "DUP-CROP", "DUP-CROP-BC");
		run("Clear Results");
		run("Measure");
		MEAN = getResult("Mean", 0);
		selectWindow("DUP-CROP");
		setThreshold(0, MEAN);
		run("Create Selection");
		run("Measure");
//		run("Select None");
		BC[ch] = getResult("Mean", 1);
		if (BC[ch] > MIN)
			BC[ch] = MIN;
		close("DUP-CROP-BC");
		close("DUP-CROP");
		close("Result of DUP-CROP");
		selectWindow(list[i]);
		Stack.setChannel(RGB[ch]);
		run("Subtract...", "value="+BC[ch]);
		run("Clear Results");
		run("Measure");
		MIN = getResult("Min", 0);
/*waitForUser(MIN);
		if (MIN < 0) {
			run("Subtract...", "value="+MIN);
			WARNING = WARNING + "Negative pixels corrected to zero (whole image intensity shifted); ";
		}*/
	}
}

function PM_mask(title,j) {
	selectWindow(list[i]);
	roiManager("Select", j);
	run("Enlarge...", "enlarge=0.166"); //enlarge works with micometers
	run("Duplicate...", "duplicate channels=1-2");
	rename("DUP");
	run("Create Mask");
	rename("Mask-outer");
	selectWindow("DUP");
	run("Restore Selection");
	run("Enlarge...", "enlarge=-0.333");
	run("Create Mask");
	rename("Mask-inner");
	imageCalculator("Subtract create","Mask-outer","Mask-inner");
	selectWindow("Result of Mask-outer");
	run("Invert");
	rename("Mask");
	selectWindow("DUP");
}

function cell(title,j) {
	selectWindow(list[i]);
	roiManager("Select", j);
	if (matches(ROI_type, "whole cell"))
		run("Enlarge...", "enlarge=0.166"); //enlarge works with micometers
	else
		run("Enlarge...", "enlarge=-0.166");
	run("Duplicate...", "duplicate channels=1-2");
	rename("DUP");
	run("Restore Selection");
}

function extract_coefficients(title) {
	if (matches(ROI_type, "whole frame")){
		run("Duplicate...", "duplicate channels=1-2");
		rename("DUP");
	}
	run("Split Channels");
	if (matches(ROI_type, "plasma membrane") != 1){
		selectWindow("C1-DUP");
		run("Restore Selection");
	}
		run("Coloc 2", "channel_1=[C1-DUP] channel_2=[C2-DUP] roi_or_mask="+RM+" threshold_regression="+threshold+" li_icq spearman's_rank_correlation manders'_correlation kendall's_tau_rank_correlation costes'_significance_test psf=3 costes_randomisations=10");
	for (i = 0; i < windows.length; i++) {
		close(windows[i]);
	}
	logString = getInfo("log");
	if (indexOf(logString, "Threshold of ch. 1 too high") >= 0 || indexOf(logString, "Threshold of ch. 2 too high") >= 0) {
		WARNING = WARNING + "Threshold too high in one or both channels (above the mean); ";
		E = "*"; //ctrl+E in GraphPad Prism exludes values from plotting and analysis, it does so by appending a * to the cell in question
	} 
	if (indexOf(logString, "y-intercept far from zero") >= 0) {
		WARNING = WARNING + "y-intercept far from zero; ";
		E = "*"; //ctrl+E in GraphPad Prism exludes values from plotting and analysis, it does so by appending a * to the cell in question
	}
	LOG = split(logString,",,\n\n");
	for (i = LOG.length-1; i >= 5; i--) {
		if (LOG[i] == "Kendall's Tau-b rank correlation value") {
			K=(LOG[i+1]);
		}
		if (LOG[i] == "Manders' tM2 (Above autothreshold of Ch1)") {
			tM1=(LOG[i-1]); // how much ch1 (red) signal is also in ch2 (green)
			tM2=(LOG[i+1]); // how much ch2 (green) signal is also in ch1 (red)
		}
		if (LOG[i] == "Li's ICQ value") {
			Li=(LOG[i+1]);
		}
		if (LOG[i] == "Spearman's rank correlation value") {
			S=(LOG[i+1]);
		}
		if (LOG[i] == "Pearson's R value (above threshold)") {
			P=(LOG[i+1]);
			break;
		}
	}
	print("\\Clear");
}

function find_parents(dir) {
	parent = File.getParent(dir);
	grandparent = File.getParent(parent);
	parent_name = File.getName(parent);
	grandparent_name = File.getName(grandparent);
	BR_date = substring(parent_name, 0, 6);
	exp_code = substring(grandparent_name, 0, lengthOf(experiment_scheme));
}

function saveResults() {
	getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
	time_stamp = " ("+year+"-"+month+1+"-"+dayOfMonth+","+hour+"-"+minute+"-"+second+").csv";
	selectWindow(RW0);
	saveAs("Text", dirMaster + "Coloc_summary-" + ROI_type + time_stamp);
	close("Log");
	close(RW0);
	close("Coloc_summary-" + ROI_type + time_stamp);
	close("Results");
	close("ROI manager");
//	File.delete(dirMaster + "Coloc_temp.csv");
	File.delete(dirMaster + RW0);
	waitForUser("Finito!", "Macro finished successfully.");
}

setBatchMode(false);