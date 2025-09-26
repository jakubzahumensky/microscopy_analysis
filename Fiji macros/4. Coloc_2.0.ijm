/***************************************************************************************************************************************
 * BASIC MACRO INFORMATION
 *
 * title: "Colocalization"
 * author: Jakub Zahumensky
 * - e-mail: jakub.zahumensky@iem.cas.cz
 * - e-mail: jakub.zahumensky@gmail.com
 * - GitHub: https://github.com/jakubzahumensky
 * - Department of Functional Organisation of Biomembranes
 * - Institute of Experimental Medicine CAS
 * - citation: https://doi.org/10.1093/biomethods/bpae075
 *
 * Summary:
 * This macro takes raw microscopy images and ROIs defined elsewhere and then analyses colocalization of specified channels.
 * The user has the option to select if colocalization is performed using the whole image, individual cells, or their plasma membranes.
 ***************************************************************************************************************************************/

//setBatchMode(true);

macro_name = "Quantification of colocalization in microscopy images";
version = "2.0"; // not backward compatible with 8.x versions of ROI_prep!
publication = "Zahumensky & Malinsky, 2024; doi: 10.1093/biomethods/bpae075";
GitHub_microscopy_analysis = "https://github.com/jakubzahumensky/microscopy_analysis";


/* definitions of constants and global variables used in the macro below */
var title = "";
var roiDir = "";
extension_list = newArray("czi", "oif", "lif", "tif", "vsi");
image_types = newArray("transversal", "tangential");
area_select = newArray("whole frame", "whole cell", "plasma membrane", "cytosol");
threshold_method = newArray("Costes", "Bisection");

initial_folder = "";
initial_folder = "D:/Yeast/EXPERIMENTAL/microscopy/JZ-M-075-250926 - Atg8 vs eisosome mutants - coloc w Sur7/250202/";

var windows = newArray("Mask-inner","Mask-outer","Mask","C1-DUP","C2-DUP");
var DirType = "data/";
var BR_date = "YYMMDD"
var exp_code = "XY-M-000"
var RW0 = "Coloc_temp.csv";
var RW = "["+RW0+"]";
var RM = "";
var WARNING = "";
var E = "";

var BC = newArray(2);
var P = 0;
var tM1 = 0;
var tM2 = 0;
var Li = 0;
var K = 0;
var S = 0;

/****************************************************************************************************************************************************/
/* INITIAL DIALOG WINDOW TO TAKE USER INPUT
 * Display the "Quantify colocalziation" dialog window, including a help message. Multiple parameters need to be set by the user.
 * Detailed explanation in the help message
 */
help_message = "<html>"
		+ "<center><b>" + macro_name + " " + version + "</b></center>"
		+ "<center><i>source: " + GitHub_microscopy_analysis + "</i></center><br>"

		+ "<b>Directory</b><br>"
		+ "Specify the directory where you want <i>Fiji</i> to start looking for folders with images. The macro works <i>recursively</i>, i.e., it looks into all <i>sub</i>folders. "
		+ "All folders with names <i>ending</i> with the word \"<i>data</i>\" are processed. All other folders are ignored. <br><br>"

		+ "<b>Subset</b><br>"
		+ "If used, only images with filenames containing specified <i>string</i> (i.e., group of characters and/or numbers) will be processed. "
		+ "This option can be used to selectively process images of a specific strain, condition, etc. "
		+ "Leave empty to process all images in specified directory (and its subdirectories). <br><br>"

		+ "<b>Naming scheme</b><br>"
		+ "Specify how your files are named (without extension). Results are reported in a comma-separated table, with the parameters specified here used as column headers. "
		+ "The default \"<i>strain,medium,time,condition,frame</i>\" creates 5 columns, with titles \"strains\", \"medium\" etc. "
		+ "Using a consistent naming scheme across your data enables automated downstream data processing. <br><br>"

		+ "<b>Experiment code scheme</b><br>"
		+ "Specify how your experiments are coded. The macro assumes a folder structure of <i>\".../experimental_code/biological_replicate_date/image_type/data/\"</i>. See protocol for details. <br><br>"

		+ "<b>Image type</b><br>"
		+ "Select if your images represent <i>transversal</i> (also called <i>equatorial</i>) or <i>tangential</i> sections of the cells. <br><br>"
		
		+ "<b>Regions of interest</b><br>"
		+ "Select what type of area of the image you wish to analyze for colocalization: whole frame, whole cells, plasma membranes, cytosols. "
		+ "Not that for the options other than 'whole frame', ROIs need to be prepared in advance, for exaple by the 'ROI_prep' macro. "
		+ "In the case that one of these options is selected, the colocalization parameters are reported separately for each cell/plasma membane/cytosol. <br><br>"
		
		+ "<b>First & Second Channel</b><br>"
		+ "Specify image channels which are to be analyzed for colocalization. The order of selection is reflected in the Results table. <br><br>"
		
		+ "</html>";


Dialog.create("Quantify colocalization");
	Dialog.addDirectory("Directory:", initial_folder);
	Dialog.addString("Subset (optional):", "");
	Dialog.addString("Naming scheme:", "strain,medium,time,condition,frame", 33);
	Dialog.addString("Experiment code scheme:", exp_code, 33);
	Dialog.addChoice("Image type:", image_types);
	Dialog.addChoice("Regions of interest:", area_select);
	Dialog.addChoice("Thresholding:", threshold_method);
	Dialog.addNumber("First channel:", "1");
	Dialog.addNumber("Second channel:", "3");
    Dialog.show();
	dir = Dialog.getString();
	subset = Dialog.getString();
	naming_scheme = Dialog.getString();
	experiment_scheme = Dialog.getString();
	image_type = Dialog.getChoice();
	ROI_type = Dialog.getChoice();
	threshold = Dialog.getChoice();
	R = Dialog.getNumber();
	G = Dialog.getNumber();
	RGB = newArray(R, G);
	
	if (matches(ROI_type, "plasma membrane"))
		RM = "[Mask]";
	if (matches(ROI_type, "whole cell") || matches(ROI_type, "cytosol"))
		RM = "[ROI(s) in channel 1]"; //this needs to be checked
	if (matches(ROI_type, "whole frame"))
		RM = "<None>";

dirMaster = dir; //directory into which Result summary is saved

initialize();
processFolder(dir);
saveResults();

/****************************************************************************************************************************************************/
/* "the macro" */
function initialize(){
	close("*");
	print("\\Clear");
	roiManager("reset");
	run("Clear Results");
	
	/* print the header of the Results table */
	if (isOpen(RW0)){
		selectWindow(RW0);
		run("Close");
	}
//		print(RW, "\\Close:"); // clears the window
	run("Text Window...", "name=" + RW + "width=256 height=32");
	getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
	print(RW, "# Basic macro run statistics:\n");
	print(RW, "# Date and time: " + year + "-" + month + 1 + "-" + dayOfMonth + " " + hour + ":" + minute + ":" + second + "\n");
	print(RW, "# Macro version: " + version + "\n");
	print(RW, "# Thresholding method: " + threshold + "\n");
	print(RW, "# ROI: " + ROI_type + "\n");
	print(RW, "#\n");
	print(RW, "# IMPORTANT note on thresholding: \n");
	print(RW, "# Thresholding affects Pearson's and Mander's coefficients.\n");
	print(RW, "# If there is a warning these values should be discarded.\n");
	print(RW, "# They are marked with an * and are automatically excluded from graphs and analysis in GraphPad Prism\n");
	print(RW, "# The other parameters are unaffected by thresholding and are safe to use.\n");
	print(RW, "#\n");
	print(RW, "exp_code,BR_date," + naming_scheme + ",background-red_ch,background-green_ch,cell,Pearson,tManders_red_ch,tManders_green-ch,Li(ICQ),Kendall_tau,Spearman,warning\n");
}


/****************************************************************************************************************************************************/
/* BASIC STRUCTURE FOR RECURSIVE DATA PROCESSING */
function processFolder(dir){
	list = getFileList(dir);
	for (i = 0; i < list.length; i++){
		if (endsWith(list[i], "/"))
			processFolder(""+dir+list[i]);
		else {
			q = dir+list[i];
			if (endsWith(dir, DirType)){
				if (indexOf(q, subset) >= 0 && endsWith(dir, image_type + "/data/")){
					extIndex = lastIndexOf(q, ".");
					ext = substring(q, extIndex + 1);
					if (contains(extension_list, ext))
						processFile(q);
				}
			}
		}
	}
}


function processFile(q){
	prepare();
	if (matches(ROI_type, "whole frame")){
		extract_coefficients(title);
		find_parents();
		res = exp_code+","+BR_date+","+list[i]+","+String.join(BC)+","+","+P+E+","+tM1+E+","+tM2+E+","+Li+","+K+","+S+","+WARNING+"\n";
		print(RW, res);
	} else {
		roiManager("reset");
		roiManager("Open", roiDir+title+"-RoiSet.zip");
		roiManager("Remove Channel Info");
		numROIs = roiManager("count");
		for (j = 0; j <= numROIs-1; j++){
			if (matches(ROI_type, "plasma membrane"))
				create_PM_mask(title,j);
			else
				cell(title,j);
			extract_coefficients(title);
			find_parents();
			res = exp_code+","+BR_date+","+list[i]+","+String.join(BC)+","+j+1+","+P+E+","+tM1+E+","+tM2+E+","+Li+","+K+","+S+","+WARNING+"\n";
			print(RW, res);
		}
	}
//	print(RW, res);
	WARNING = "";
	E = "";
	close("*");
	selectWindow(RW0);
	saveAs("Text", dirMaster+RW0);
}


function contains(array, value){
	for (i = 0; i < array.length; i++)
		if (array[i] == value) return true;
	return false;
}


function prepare(){
	roiDir = replace(dir, "data", "ROIs");
	run("Bio-Formats Windowless Importer", "open=[q]");
	run("Smooth", "stack");
	rename(list[i]);
	title = File.nameWithoutExtension;
	selectWindow(list[i]);
	run("Select None");
	run("Set Measurements...", "mean standard modal min redirect=None decimal=3");
	for (ch = 0; ch <= 1; ch++){
		BC[ch] = measure_background(list[i], ch);
		run("Duplicate...", "title=DUP-" + RGB[ch] + " duplicate channels=" + RGB[ch]);
	}
	close(list[i]);
	run("Merge Channels...", "c1=DUP-" + RGB[0] + " c2=DUP-" + RGB[1] + " create");
	rename(list[i]);
}


/****************************************************************************************************************************************************/
/* To get an estimate of the image background, the background is subtracted in the original image using brute force (rolling ball approach).
 * The result is then subtracted from the original image, creating an image of the background.
 * The mean intensity of this image is then used as background intensity estimate.
 */
function measure_background(image_title, channel){
	selectWindow(image_title);
	getDimensions(width, height, channels, slices, frames);
	run("Duplicate...", "duplicate channels=" + RGB[channel]);
	run("Select None");
	getStatistics(area, mean, min, max, std, histogram);
	// If offset is set correctly during image acquisition, zero  intensity usually originates when multichannel images are aligned.
	// In this case, they need to be cropped before the background estimation.
	if (min == 0)
		run("Auto Crop (guess background color)");
	rename("DUP-CROP");
	run("Duplicate...", "duplicate");
	rename("DUP-CROP-background");
	// Brute-force background subtraction (by using the "rolling ball" approach), the width of the whole image is used as the diameter of the ball.
	run("Subtract Background...", "rolling=" + width + " stack");
	imageCalculator("Difference create stack", "DUP-CROP", "DUP-CROP-background");
	getStatistics(area, mean, min, max, std, histogram);
	selectWindow("DUP-CROP");
	setThreshold(0, mean);
	run("Create Selection");
	getStatistics(area, image_background, min, max, std, histogram);
	run("Select None");
	windows_list = newArray("DUP-CROP-background", "DUP-CROP", "Result of DUP-CROP");
	close_windows(windows_list);
	return image_background;
}


/* close all windows specified in the agrument array (if they are open) */
function close_windows(win_list){
	for (i = 0; i < win_list.length; i++){
		if (isOpen(win_list[i]))
			close(win_list[i]);
	}
}


function create_PM_mask(title,j){
	selectWindow(list[i]);
	roiManager("Select", j);
	run("Enlarge...", "enlarge=0.166"); //enlarge works with micometers
	run("Duplicate...", "duplicate title=DUP");
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

function cell(title,j){
	selectWindow(list[i]);
	roiManager("Select", j);
	if (matches(ROI_type, "whole cell"))
		run("Enlarge...", "enlarge=0.166"); //enlarge works with micrometers
	else
		run("Enlarge...", "enlarge=-0.166");

	run("Duplicate...", "duplicate title=DUP");
	run("Restore Selection");
}

function extract_coefficients(title){
	selectWindow(list[i]);
	if (matches(ROI_type, "whole frame")){
		run("Duplicate...", "duplicate title=DUP");
	}
	
	selectWindow("DUP");
	run("Split Channels");
	selectWindow("C1-DUP");
	run("Select None");

	if (matches(ROI_type, "plasma membrane") != 1){
		selectWindow("C1-DUP");
		run("Restore Selection");
	}

	run("Coloc 2", "channel_1=[C1-DUP] channel_2=[C2-DUP] roi_or_mask=" + RM + " threshold_regression=" + threshold + " li_icq spearman's_rank_correlation manders'_correlation kendall's_tau_rank_correlation costes'_significance_test psf=3 costes_randomisations=10");
	
	for (i = 0; i < windows.length; i++){
		close(windows[i]);
	}
	
	
	logString = getInfo("log");
	if (indexOf(logString, "Threshold of ch. 1 too high") >= 0 || indexOf(logString, "Threshold of ch. 2 too high") >= 0){
		WARNING = WARNING + "Threshold too high in one or both channels (above the mean); ";
		E = "*"; //ctrl+E in GraphPad Prism exludes values from plotting and analysis, it does so by appending a * to the cell in question
	}
	if (indexOf(logString, "y-intercept far from zero") >= 0){
		WARNING = WARNING + "y-intercept far from zero; ";
		E = "*"; //ctrl+E in GraphPad Prism exludes values from plotting and analysis, it does so by appending a * to the cell in question
	}
	
	LOG = split(logString,",,\n\n");
	for (i = LOG.length-1; i >= 5; i--){
		if (LOG[i] == "Kendall's Tau-b rank correlation value"){
			K=(LOG[i+1]);
		}
		if (LOG[i] == "Manders' tM2 (Above autothreshold of Ch1)"){
			tM1=(LOG[i-1]); // how much ch1 (red) signal is also in ch2 (green)
			tM2=(LOG[i+1]); // how much ch2 (green) signal is also in ch1 (red)
		}
		if (LOG[i] == "Li's ICQ value"){
			Li=(LOG[i+1]);
		}
		if (LOG[i] == "Spearman's rank correlation value"){
			S=(LOG[i+1]);
		}
		if (LOG[i] == "Pearson's R value (above threshold)"){
			P=(LOG[i+1]);
			break;
		}
	}
	print("\\Clear");
}


// Function to extract the biological replicate date and experiment accession code
// For this to work properly, correct data structure is required:
// folder with a name that starts with the accession code, containing subfolders, each starting with the date in the YYMMDD format
// each biological replicate folder contains the "transversal" and/or "tangential" folders
// each of these contains at least the "data" and "ROIs" folder
function find_parents(){
	parent = File.getParent(File.getParent(dir)); // bio replicate date (two levels up from the "data" folder)
	grandparent = File.getParent(parent); // one level above the bio replicate folder; name starts with the experiment code (accession number)
	// replace spaces with underscores in both to prevent possible issues in automatic R processing of the Results table
	BR_date = replace(File.getName(parent)," ","_");
	exp_code = replace(File.getName(grandparent)," ","_");
	// date is expected in YYMMDD (or another 6-digit) format; if it is shorter, the whole name is used; analogous with the "experimental code"
	if (lengthOf(BR_date) > 6)
		BR_date = substring(BR_date, 0, 6);
	if (lengthOf(exp_code) > lengthOf(experiment_scheme))
		exp_code = substring(exp_code, 0, lengthOf(experiment_scheme));
}


function saveResults(){
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