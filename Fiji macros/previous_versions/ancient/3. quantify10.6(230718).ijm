////////////////////////////////////////////////////////////////////////////////
// Abbreviations used:
// PM - plasma membrane
// cyt - cytosol
// CV - coefficient of variance
// BC - background; when appended to a variable, means "background corrected"
////////////////////////////////////////////////////////////////////////////////

version = "10.6";
extension_list = newArray("czi", "oif", "lif", "tif", "vsi"); //only files with these extensions will be processed
image_types = newArray("transversal", "tangential"); //there are either tranversal (going through the middle) or tangential (showing the surface) microscopy images. Z-stack projections are a special case of the latter.
boolean = newArray("yes","no");

//initial values of variables that change within functions
var title="";
var roiDir="";
var patchesDir="";
var pixelHeight = 0;
var CHANNEL = newArray(1);
var ch = 1;
var proc_files = "";
var pixelWidth = 0;
var Image_Area = 0;

CV_threshold = 0; //CV for discrimination of cells without patches
PBody_threshold = 5; //intensity fol threshold for the identification of abnormally bright puncta at/near the plasma membrane (PM) - can correspond to P-bodies, stress granules, mitochondria in close contact with the PM
cell_size_min = 0;
SaveMasks = false;
ScaleFactor = 2/3; //scaling factor for circular ROI creation inside segmentation masks of tangential cell sections

//following three parameters only change if deconvovled images are analyzed
Gauss_Sigma = 1; //Smoothing factor (Gauss)
//PatchProminence = 1.666; //Patch prominence threshold - set semi-empirically
PatchProminence = 1.333; //Patch prominence threshold - set semi-empirically

//The following is displayed when the "Help" button is pressed in the Dialog window below
html0 = "<html>"
	+"<b>Directory</b><br>"
	+"Specify the directory where you want <i>Fiji</i> to start looking for folders with images. "
	+"The macro works <u>recursively</u>, i.e., it looks into all subfolders. All folders with names <u>ending</u> with the word \"<i>data</i>\" "
	+"(for <i>transversal</i> image type) or \"<i>data-caps</i>\" (for <i>tangential</i> image type) are processed. "
	+"All other folders are ignored.<br>"
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
	+"<b>Experiment code scheme</b><br>"
	+"Specify how your experiments are coded. The macro assumes a folder structure of <i>\".../experimental_code/biological_replicate_date/data<sup>*</sup>/\"</i>. See protocol for details.<br>"
	+"<sup>*</sup> - or <i>\"data-caps\"</i> for tangential images. <br>"
	+"<br>"
	+"<b>Image type</b><br>"
	+"Select if your images represent <i>transversal</i> (also called <i>equatorial</i>) or <i>tangential</i> sections of the cells.<br>"
	+"</html>";

Dialog.create("Quantify");
	Dialog.addDirectory("Directory:", "");
	Dialog.addString("Subset (optional):", "");
	Dialog.addString("Channel:", ch);
	Dialog.addString("Naming scheme:", "strain,medium,time,condition,frame", 33);
	Dialog.addString("Experiment code scheme:", "XY-M-000", 33);
	Dialog.addChoice("Image type:", image_types);
	Dialog.addHelp(html0);
    Dialog.show();
	dir = Dialog.getString();
	subset = Dialog.getString();
	channel = Dialog.getString();
	naming_scheme = Dialog.getString();
	experiment_scheme = Dialog.getString();
	image_type = Dialog.getChoice();

dirMaster = dir; //directory into which Result summary is saved
temp_file = "Results-temporary(" + image_type + ").txt";

if (matches(image_type, "transversal")) {
	DirType="data/";
	cell_size_min = 5;
} else {
	DirType="data-caps/";
	cell_size_min = 3;
}

//The following is displayed when the "Help" button is pressed in the Dialog window below
html1 = "<html>"
	+"<b>Min and max cell size</b><br>"
	+"Specify lower (<i>min</i>) and upper (<i>max</i>) limit for cell area (in &micro;m<sup>2</sup>; as appears in the microscopy images). "
	+"Only cells within this range will be included in the analysis. The default lower limit is set to 5 &micro;m<sup>2</sup>, which corresponds to a small bud of a haploid yeast. "
	+"<i>The user is advised to measure a handful of cells before adjusting these limits. If in doubt, set limits 0-Infinity and filter the results table.</i><br>"
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

Dialog.create("Quantification options");
	Dialog.addNumber("Cell size from:", cell_size_min);
	Dialog.addToSameRow();
	Dialog.addNumber("to:","Infinity",0,6, fromCharCode(181) + "m^2");
	Dialog.addNumber("Coefficient of variance (CV) threshold", 0);
	Dialog.addChoice("Deconvolved:", boolean ,"no");
//	Dialog.addChoice("Save segmentation masks (tangential only)", boo, "no");
	Dialog.addHelp(html1);
	Dialog.show();
	cell_size_min = Dialog.getNumber();
	cell_size_max = Dialog.getNumber();
	CV = Dialog.getNumber();
	DECON = Dialog.getChoice();
//	SaveMasks = Dialog.getChoice();
	//for deconvolved images (based on testing, not theory):
	if (DECON == "yes") {
		Gauss_Sigma = 0; //no smoothing is used
		PatchProminence = 1.333; //patch prominence can be set lower compared to regular confocal images
//		wait_period = wait_period_decon; //waiting time needs to be longer between certain macro steps
	}

CHANNEL = sort_channels(channel);
for (l = 0; l <= CHANNEL.length-1; l++){
	ch = CHANNEL[l];
	initialize();
	processFolder(dir);
	channel_wrap_up();
}
final_wrap_up();

//////////////////////////////////////////////
//definitions of functions used in the macro//
//////////////////////////////////////////////
function processFolder(dir) {
	list = getFileList(dir);
	for (i=0; i<list.length; i++) {
		showProgress(i+1, list.length);
		if (endsWith(list[i], "/"))
        	processFolder(""+dir+list[i]);
	    else {
			q = dir+list[i];
			if (endsWith(dir, DirType) && indexOf(proc_files, q) < 0 && indexOf(q, subset) >= 0)
				if (check_ROIs(dir, list[i])){
					extIndex = lastIndexOf(q, ".");
					ext = substring(q, extIndex+1);
					if (contains(extension_list, ext)){
//						print("[processed_files.tsv]",q+"\n");
						if (matches(image_type, "transversal")) measure_tranversal();
							else measure_tangential();
					}
				}
		}
	}
}

function contains(array, value) {
    for (i=0; i < array.length; i++)
        if (array[i] == value) return true;
    return false;
}

function sort_channels(channel){
	if (indexOf(channel, "-") >= 0){
		X = "--";
		channel_temp = split(channel,"--");
		j=0;
		for (i=channel_temp[0]; i <= channel_temp[1]; i++){
			CHANNEL[j]=i;
			j++;
		}
	} else {
		CHANNEL=split(channel,",,");
	};
	return CHANNEL;
}

function check_ROIs(dir, string){
	title = substring(string, 0, lastIndexOf(string, "."));
	roiDir = replace(dir, "data", "ROIs");
	if (File.exists(roiDir + title + "-RoiSet.zip")){
		return true;
	} else {
		print("[files_without_ROIs.tsv]",q+"\n");
		return false;
	}
}

function prep() {
	roiDir = replace(dir, "data", "ROIs");
	if (SaveMasks == true) {
		patchesDir = replace(dir, "data", "patches");
		File.makeDirectory(patchesDir);
	}
	run("Bio-Formats Windowless Importer", "open=[q]");
	rename(list[i]);
	title = File.nameWithoutExtension;
	run("Select None");
	getDimensions(width, height, channels, slices, frames);
	getPixelSize(unit, pixelWidth, pixelHeight);
	run("Clear Results");
	run("Measure");
	Image_Area = getResult("Area", 0);
	Stack.setChannel(ch);
	if (matches(image_type, "transversal")) {
			run("Duplicate...", "title=DUP channels="+ch);
			run("Gaussian Blur...", "sigma=Gauss_Sigma");
		selectWindow(list[i]);
			run("Duplicate...", "title=DUP_profile channels="+ch);
			run("Normalize Local Contrast", "block_radius_x=5 block_radius_y=5 standard_deviations=10 center stretch");
			run("Enhance Local Contrast (CLAHE)", "blocksize=8 histogram=64 maximum=3 mask=*None*");
			run("Unsharp Mask...", "radius=1 mask=0.6");
			run("Gaussian Blur...", "sigma=Gauss_Sigma");
//		selectWindow(list[i]);
//			run("Duplicate...", "title=DUP_threshold channels="+ch);
		selectWindow(list[i]);
			run("Duplicate...", "title=DUP_watershed channels="+ch);
			run("Select None");
			run("8-bit");
			run("Watershed Segmentation", "blurring='0.0'   watershed='1 1 0 255 0 0'   display='2 0' ");
			while(!isOpen("Dams"))
				wait(1);
			selectWindow("Binary watershed lines");
			run("Despeckle");
			rename("Watershed-Segmented");
			run("Open");
			close("Dams");
	}
	roiManager("reset");
	roiManager("Open", roiDir+title+"-RoiSet.zip");
	roiManager("Remove Channel Info");
}

//To get an estimate of the image background, the background is subtracted in the original image using brutal force.
//The result is then subtracted from the original image, creating an image of the background. Mean intensity of this image is then used as background intensity estimate.
function measure_background() {
	selectWindow(list[i]);
	getDimensions(width, height, channels, slices, frames);
	run("Duplicate...", "duplicate channels="+ch);
	run("Select None");
	run("Clear Results");
	run("Measure");
	MIN = getResult("Min", 0); //if offset is set correctly during image acquisition, zero pixel intensity usually originates when multichannel images are aligned. In this case, they need to be cropped before the background estimation
		if (MIN == 0) run("Auto Crop (guess background color)");
	rename("DUP-CROP");
	run("Duplicate...", "duplicate");
	rename("DUP-CROP-BC");
	run("Subtract Background...", "rolling=" + width + " stack");
	imageCalculator("Difference create stack", "DUP-CROP", "DUP-CROP-BC");
	run("Clear Results");
	run("Measure");
	MEAN = getResult("Mean", 0);
	selectWindow("DUP-CROP");
	setThreshold(0, MEAN);
	run("Create Selection");
	run("Measure");
	run("Select None");
	BC = getResult("Mean", 1);
	close("DUP-CROP-BC");
	close("DUP-CROP");
	close("Result of DUP-CROP");
	return BC;
}

function find_parents() {
	parent = File.getParent(dir);
	grandparent = File.getParent(parent);
	parent_name = File.getName(parent);
	grandparent_name = File.getName(grandparent);
	if (lengthOf(parent_name) >= 6)
		BR_date = replace(substring(parent_name, 0, 6)," ","_");
	else 
		BR_date = replace(parent_name," ","_");
	exp_code = replace(substring(grandparent_name, 0, lengthOf(experiment_scheme))," ","_");
	return newArray(exp_code, BR_date);
}

function measure_tranversal() {
	prep();
	BC = measure_background();
	//quantification - open ROIs prepared with ROI_prep.ijm macro and cycle through them one by one
	numROIs = roiManager("count");
	for(j = 0; j < numROIs; j++) {
//	for(j = 0; j <= 6; j++) { //the shortened loop can be used for testing

// measure cell characteristics: area, integral_intensity_BC, mean_intensity_BC, intensity_SD, intensity_CV
// 0.166 makes the ROI slightly bigger to include the whole plasma membrane:  
		cell = measure_ROI(j, 0.166); //measures cell characteristics
		//shape characterization from the Results table created by the measure_ROI function
		major_axis = getResult("Major", 0);
		minor_axis = getResult("Minor", 0);
		eccentricity = sqrt(1-pow(minor_axis/major_axis, 2));
		if (cell[0] > cell_size_min && cell[0] < cell_size_max && cell[4] > CV){ //cell[0] corresponds to cell area; cell[4] to intensity CV
			run("Create Mask"); // masks the whole cell; preparation for plasma membrane segmentation
			rename("Mask-cell");
			cytosol = measure_ROI(j, -0.166); // -0.166 makes the ROI smaller to only include cytosol
		//preparation for plasma membrane segmentation
			run("Create Mask");
			rename("Mask-cytosol");
		//preparation for measurements just below the plasma membrane
			cortical_cytosol = measure_cort(); //array: mean, SD; not corrected for BC
		//plasma membrane segmentation
			imageCalculator("Subtract create", "Mask-cell","Mask-cytosol");
			selectWindow("Result of Mask-cell");
			run("Create Selection"); //selection of the plasma membrane only
			selectWindow(list[i]);
			run("Restore Selection"); //transfer of the selection to the raw microscopy image
			plasma_membrane = measure(); //selection is created using the difference of masks and this is transferred to the original image, where the parameters are measured
////////////////////////////////////////////////////////////////////////////////////////////////////////////
		select_window("DUP");
//		select_window("DUP_profile");
		select_ROI(j);
			run("Area to Line"); //convert the ellipse (area object) to a line that has a beginning and end
			run("Line Width...", "line="+0.332/pixelHeight);
			run("Clear Results");
			run("Measure");
				PM_length = getResult("Length", 0); //length measured along the plasma membrane
				PM_mean = getResult("Mean", 0);
//				PM_StdDev = getResult("StdDev", 0);
//				PEAK_amp = PM_StdDev;
				PEAK_amp = getResult("StdDev", 0);

			select_window("DUP");
//			select_window("DUP_profile");
			PM_base_BC = get_PM_base();
			if (plasma_membrane[2] < (cortical_cytosol[0] - BC)) {
				Peak_MIN = PatchProminence*(cortical_cytosol[2]+BC);
			} else {
				Peak_MIN = PatchProminence*(PM_base_BC+BC);
			}
			select_window("Plot of DUP");
//			select_window("Plot of DUP_profile");
//			run("Find Peaks", "min._peak_amplitude=PEAK_amp min._peak_distance=0 min._value=Peak_MIN max._value=[] exclude list");
			run("Find Peaks", "min._peak_amplitude=PEAK_amp min._peak_distance=0 min._value=PM_mean max._value=[] exclude list");
			Table.rename("Plot Values", "Results");
			patch_numbers = quant_patches(PM_length, PM_base_BC); //patches, patch_density, patch_intensity_BC, patch_prominence, P_bodies
			patch_distribution = charaterize_patch_distribution(patch_numbers[0]); //patch_distance_min, patch_distance_max,	patch_distance_mean, patch_distance_stdDev, patch_distance_CV

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////			
//plot_profile NEW
//setLineWidth(4);			
			select_window("DUP_profile");
			select_ROI(j);
			run("Area to Line"); //convert the ellipse (area object) to a line that has a beginning and end
			run("Line Width...", "line="+0.332/pixelHeight);
			run("Clear Results");
			run("Measure");
				PM_length = getResult("Length", 0); //length measured along the plasma membrane
				PM_mean = getResult("Mean", 0);
				Peak_MIN = PM_mean;
				PEAK_amp = getResult("StdDev", 0);
			selectWindow("DUP_profile");
			run("Plot Profile");
			run("Find Peaks", "min._peak_amplitude=PEAK_amp min._peak_distance=0 min._value=Peak_MIN max._value=[] exclude list");
				Table.rename("Plot Values", "Results");
				patch_numbers2 = quant_patches(PM_length, PM_base_BC);
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////			
//patches from thresholding			
//setLineWidth(4);
//			selectWindow("DUP_threshold");
			select_window("DUP_profile");
			run("Duplicate...", "duplicate channels=1");
			run("Select None");
			select_ROI(j);
			run("Area to Line"); //convert the ellipse (area object) to a line that has a beginning and end
//			run("Line Width...", "line="+0.332/pixelHeight);
			run("Clear Results");
			run("Measure");
				PM_mean = getResult("Mean", 0);
				PM_StdDev = getResult("StdDev", 0);
			setThreshold(PM_mean, 65535, "raw");
			run("Convert to Mask");
			run("Despeckle");
			membrane_buff = 1;
			clean(membrane_buff);
			run("Adjustable Watershed", "tolerance=0.1");
			run("Analyze Particles...", "size=0.03-0.20 circularity=0.75-1.00 show=Overlay display clear overlay");
			threshold_patches = nResults;
			close();

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////			
//watershed patches

			selectWindow("Watershed-Segmented");
			size_MAX = 0.36/pow(pixelWidth, 2);
			membrane_buff = 5*0.166/pixelWidth;
			run("Duplicate...", "duplicate channels=1");
			clean(membrane_buff);
			run("Despeckle");
//			run("Analyze Particles...", "size=0-"+size_MAX+" circularity=0.50-1.00 show=Overlay display clear overlay");
			run("Analyze Particles...", "size=0-"+size_MAX+" circularity=0.50-1.00 show=Overlay display clear overlay");
//			run("Analyze Particles...", "size=5-33 circularity=0.75-1.00 show=Overlay display clear overlay");
			watershed_patches = nResults;
			close("Watershed-Segmented-1");

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////						
			
			
			
			prot_fraction_in_patches = (1-PM_base_BC/plasma_membrane[2])*100;
			
			PM_div_Cyt = plasma_membrane[2]/cytosol[2];
			cyt_div_cell = cytosol[2]/cell[2]; //ratio of BC corrected mean intensities
			PM_div_cell = plasma_membrane[2]/cell[2];
			cyt_div_cell_I_integral = cytosol[1]/cell[1]; //ratio of BC corrected integral intensities
			PM_div_cell_I_integral = plasma_membrane[1]/cell[1];

			parents = find_parents();

//			print(exp_code+","+BR_date+","+replace(title," ","_")+","+BC+","+(j+1)+","+patches+","+patch_density+","+patch_intensity_BC+","+PM_base_BC+","+patch_prominence+","+cell_area+","+cell_I_integral_BC+","+cell_I_mean_BC+","+cell_I_SD+","+cell_CV+","+cyt_area+","+cyt_int_BC+","+cyt_mean_BC+","+cyt_SD+","+cyt_CV+","+PM_area+","+PM_int_BC+","+PM_mean_BC+","+PM_SD+","+PM_CV+","+PM_div_Cyt+","+prot_fraction_in_patches+","+patch_distance_min+","+patch_distance_max+","+patch_distance_mean+","+patch_distance_stdDev+","+patch_distance_CV+","+PM_div_cell+","+cyt_div_cell+","+PM_div_cell_I_integral+","+cyt_div_cell_I_integral+","+major_axis+","+minor_axis+","+eccentricity+","+PB_count);
			print(parents[0]+","+parents[1] //experiment code, biological replicate date
				+","+replace(title," ","_")+","+BC+","+(j+1)
				+","+patch_numbers[0]+","+patch_numbers[1]+","+patch_numbers[2]+","+PM_base_BC+","+patch_numbers[3] //patches, patch_density, patch_intensity_BC, patch_prominence
				+","+cell[0]+","+cell[1]+","+cell[2]+","+cell[3]+","+cell[4] // cell parameters: area, integral_intensity_BC, mean_intensity_BC, SD, CV
				+","+cytosol[0]+","+cytosol[1]+","+cytosol[2]+","+cytosol[3]+","+cytosol[4] // cytosol parameters: area, integral_intensity_BC, mean_intensity_BC, SD, CV
				+","+plasma_membrane[0]+","+plasma_membrane[1]+","+plasma_membrane[2]+","+plasma_membrane[3]+","+plasma_membrane[4]// plasma membrane parameters: area, integral_intensity_BC, mean_intensity_BC, SD, CV
				+","+PM_div_Cyt
				+","+prot_fraction_in_patches+","+patch_distribution[0]+","+patch_distribution[1]+","+patch_distribution[2]+","+patch_distribution[3]+","+patch_distribution[4] //patch_distance_min, patch_distance_max,	patch_distance_mean, patch_distance_stdDev, patch_distance_CV
				+","+PM_div_cell+","+cyt_div_cell+","+PM_div_cell_I_integral+","+cyt_div_cell_I_integral+","+major_axis+","+minor_axis+","+eccentricity+","+patch_numbers[4] //P_bodies at the end
				+","+patch_numbers2[0]+","+patch_numbers2[1]//+","+patch_numbers2[2]+","+PM_base_BC+","+patch_numbers2[3]
				+","+threshold_patches
				+","+watershed_patches
				);
			close("Mask-cell");
			close("Mask-cytosol");
			close("Mask-cyt-outer");
			close("Mask-cyt-inner");
			close("Result of Mask-cell");
			close("Result of Mask-cyt-outer");
			close("Plot of "+title);
			close("Peaks in Plot of "+title);
			close("Plot of DUP");
			close("Peaks in Plot of DUP");
			close("Plot of DUP_profile");
			close("Peaks in Plot of DUP_profile");
		}
	}
	close("*");
	save_temp();
}

function measure_tangential() {
	prep();
	BC = measure_background();
	numROIs = roiManager("count");
//count eisosomes from RAW data using the "Find Maxima" plugin
	for(j=0; j<numROIs; j++) {
//	for(j=3; j<8; j++) {
		selectWindow(list[i]);
		roiManager("Select", j);
		run("Clear Results");
		run("Measure");
		Area = getResult("Area", 0);
		cell_I_mean = getResult("Mean", 0);
		cell_I_mean_BC = cell_I_mean - BC; //background correction
		cell_I_SD = getResult("StdDev", 0); //standard deviation of the mean intensity (does not change with background)
		cell_CV = cell_I_SD/cell_I_mean_BC;
		if (Area > cell_size_min && Area < cell_size_max && cell_CV > CV){
			R=sqrt(ScaleFactor*Area/PI);
			origin_x=(getResult("X", 0)-R)/pixelHeight+1;
			origin_y=(getResult("Y", 0)-R)/pixelHeight+1;
			makeOval(origin_x, origin_y, 2*R/pixelHeight, 2*R/pixelHeight);
			run("Clear Results");
			run("Measure");
			MODE_ROI=getResult("Mode", 0);
			MEAN_ROI=getResult("Mean", 0);
			MEAN_ROI_BC = MEAN_ROI - BC;
			SD_ROI=getResult("StdDev", 0);
			CV_ROI=SD_ROI/MEAN_ROI_BC;
			N_eis=0;
			run("Clear Results");
			run("Find Maxima...", "prominence=MODE_ROI strict exclude output=Count");
			if (CV_ROI > CV_threshold)
				N_eis=getResult("Count", 0);
			density2=N_eis/(R*R*PI);
			area_fraction=0;
			size=NaN;
			size_SD=NaN;
			length=NaN;
			length_SD=NaN;
			width=NaN;
			width_SD=NaN;
			density=0;
			MEAN2=NaN;
			patch_I_mean=NaN;
		//make mask from current ROI
			if (N_eis > 0) {
				run("Duplicate...", "title=DUP duplicate channels="+ch);
				run("Duplicate...", "title=DUP2");
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
					patch_I_mean=getResult("Mean", 0);
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
//					makeOval(0, 0, 2*R/pixelHeight, 2*R/pixelHeight);
					run("Clear Results");
					run("Measure");
					M=getResult("Mean", 0);
					if (M > 128)
						run("Invert"); //if patches are white, invert
					run("Adjustable Watershed", "tolerance=0.01");
					if (SaveMasks == true) {
						saveAs("PNG", patchesDir+list[i]+"-"+j);
						rename("MASK");
					}
					run("Clear Results");
					run("Measure");
					M=getResult("Mean", 0);
					if (M > 0) { //proceed only if there is any signal
						run("Make Inverse");
//						run("Translate...", "x=-1 y=-1 interpolation=None");
						run("Select None");
						makeOval(0, 0, 2*R/pixelHeight, 2*R/pixelHeight);
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
						if (N > 1) { //summarize only if there is more than one patch
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
			find_parents();
			patch_I_mean_BC=patch_I_mean-BC;
			print(exp_code+","+BR_date+","+title+","+BC+","+j+1+","+density2+","+density+","+area_fraction+","+length+","+length_SD+","+width+","+width_SD+","+size+","+size_SD+","+patch_I_mean_BC);
		}
	}
	close("*");
	save_temp();
}

//prepare Fiji and find out if previous analysis run concluded
function initialize(){
	close("*");
	setBackgroundColor(255, 255, 255); //this is important for proper work with masks
//	setOption("ScaleConversions", true);
//	setLineWidth(4);
	run("Set Measurements...", "area mean standard modal min integrated centroid fit redirect=None decimal=5");
	run("Text Window...", "name=[processed_files.tsv] width=256 height=20");
	run("Text Window...", "name=[files_without_ROIs.tsv] width=256 height=10");
	if (File.exists(dirMaster + temp_file)){
		if (getBoolean("Incomplete analysis dectected.", "Continue previous analysis", "Start fresh") == 1){
			File.openAsString(dirMaster + temp_file);
			proc_files = File.openAsString(dirMaster + "processed_files.tsv");
			print("[processed_files.tsv]",proc_files+"\n");
		} else
			print_header();
	} else {
		print_header();
	}
}

//print the header of the Results output file
function print_header(){
	getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
	print("\\Clear");
	print("# Basic macro run statistics:");
	print("# Date and time: " + year + "-" + String.pad(month + 1,2) + "-" + String.pad(dayOfMonth,2) + " " + String.pad(hour,2) + ":" + String.pad(minute,2) + ":" + String.pad(second,2));
	print("# Macro version: " + version);
	print("# Channel: " + ch);
	print("# Cell (ROI) size interval: " + cell_size_min + "-" + cell_size_max +" um^2");
	print("# Coefficient of variance threshold: " + CV);
	if (matches(image_type, "transversal")) {
		print("# Smoothing factor (Gauss): " + Gauss_Sigma);
		print("# Patch prominence: " + PatchProminence);
	}
	print("#"); //emptyline that is ignored in bash and R
	//the parameters quantified from transversal and tangential focal planes are necessarily different. Hence, the columns in the Results file are also different
	if (matches(image_type, "transversal"))
		print("exp_code,BR_date," + naming_scheme + ",mean_background,cell_no"
		+",patches,patch_density,patch_intensity,PM_base,patch_prominence"
		+",cell_area,cell_I.integral,cell_I.mean,cell_I.SD,cell_I.CV,cytosol_area,cytosol_I.integral,cytosol_I.mean,cytosol_I.SD,cytosol_I.CV"
		+",PM_area,PM_I.integral,PM_I.mean,PM_I.SD,PM_I.CV,PM_I.div.Cyt_I(mean)"
		+",prot_in_patches,patch_distance_min,patch_distance_max,patch_distance_mean,patch_distance_stdDev,patch_distance_CV"
		+",PM_I.div.cell_I(mean),Cyt_I.div.cell_I(mean),PM_I.div.cell_I(integral),Cyt_I.div.cell_I(integral)"
		+",major_axis,minor_axis,eccentricity,P_bodies"
		+",patches_NEW,patch_density_NEW"//,patch_intensity_NEW,PM_base_NEW,patch_prominence_NEW"
		+",patches_threshold"
		+",patches_watershed"
		);
	else
		print("exp_code,BR_date," + naming_scheme + ",mean_background,cell_no,patch_density(find_maxima),patch_density(analyze_particles),area_fraction(patch_vs_ROI),length,length_SD,width,width_SD,size,size_SD,mean_patch_intensity");
}

function save_temp(){
	selectWindow("Log");
	saveAs("Text", dirMaster + "Results-temporary(" + image_type + ")");
	print("[processed_files.tsv]",q+"\n");
	selectWindow("processed_files.tsv");
	saveAs("Text", dirMaster + "processed_files.tsv");
	selectWindow("files_without_ROIs.tsv");
	saveAs("Text", dirMaster + "files_without_ROIs.tsv");
}

//saving of the output in csv format and cleaning up the Fiji (ImageJ) space
function channel_wrap_up(){
	getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
	res = "Results of " + image_type + " image analysis, channel " + ch + " (" + year + "-" + String.pad(month + 1,2) + "-" + String.pad(dayOfMonth,2) + "," + String.pad(hour,2) + "-" + String.pad(minute,2) + "-" + String.pad(second,2) + ").csv";
	selectWindow("Log");
	saveAs("Text", dirMaster + res);
	close("Log");
	close("Results");
	close("ROI manager");
}

//saving of the output in csv format and cleaning up the Fiji (ImageJ) space
function final_wrap_up(){
	setBackgroundColor(0, 0, 0); //reverts the backgroudn to default ImageJ settings
	print("[processed_files.tsv]","\\Close");
	if (File.length(dirMaster + "processed_files.tsv") == 0) {
		waitForUser("This is curious...", "No images were analysed. Check if you had prepared ROIs before you ran the analysis.");
	} else
		if (File.length(dirMaster + "files_without_ROIs.tsv") > 0) {
			waitForUser("Finito!", "Analysis finished successfully, but one or more images were not processed due to missing ROIs.\nThese are listed in \"files_without_ROIs.tsv\"");
		} else {
			print("[files_without_ROIs.tsv]","\\Close");
			File.delete(dirMaster + "Results-temporary(" + image_type + ").txt"); //removes the temporary Results file
			close("Log");
			waitForUser("Finito!", "Analysis finished successfully."); //informs the user that the analysis has finished successfully
		}
}

//following code analyses distribution of fl. maxima along the plasma membrane: shortest, longest, average distance, and coeffcient of variance of their distribution (a measure of uniformity)
//for this purpose, PM_add variable is introduced to allow for the measurement of distance between the last and first fl. maxima along the plasma membrane
function charaterize_patch_distribution(patches){
	patch_distance_min = NaN;
	patch_distance_max = NaN;
	patch_distance_mean = NaN;
	patch_distance_stdDev = NaN;
	patch_distance_CV = NaN;
	if (patches > 1) {
		MAXIMA = newArray(patches);
		for (p = 0; p < patches; p++){
//						for (p=P_bodies; p<patches; p++){ //at this point, maxima are ordered by intensity; starting at "P_bodies" makes the algorithm discart P-bodies
			MAXIMA[p] = getResult("X1",p);
		}
		Array.sort(MAXIMA);//sorts positions of the intensity maxima in ascending manner
		PM_add = PM_length+MAXIMA[0];
		if (PM_add > MAXIMA[MAXIMA.length-1]) MAXIMA = Array.concat(MAXIMA, PM_add);
			else patches = patches-1;
		patch_distance = newArray(MAXIMA.length-1);
		for (p = 0; p < MAXIMA.length-1; p++){
		 	patch_distance[p] = MAXIMA[p+1]-MAXIMA[p];
		}
		Array.getStatistics(patch_distance, patch_distance_min, patch_distance_max, patch_distance_mean, patch_distance_stdDev);
		patch_distance_CV = patch_distance_stdDev / patch_distance_mean;
	}
	return newArray(patch_distance_min, patch_distance_max,	patch_distance_mean, patch_distance_stdDev, patch_distance_CV);
}

function quant_patches(PM_length, PM_base_BC){
	patches = 0;
	P_bodies = 0;
	patch_intensity_sum=0;
	for (k = 0; k < nResults; k++) {
		patch_I = getResult("Y1",k);
		if (patch_I > 0) {
			patches++;
			patch_I_BC = patch_I - BC;
			patch_prom = patch_I_BC/plasma_membrane[2];
			if (patch_prom > PBody_threshold)
				P_bodies++;
			else
				patch_intensity_sum = patch_intensity_sum + patch_I;
		} else
			break;
	}
	patch_density = patches/PM_length;
	patch_intensity = patch_intensity_sum/(patches-P_bodies);
		patch_intensity_BC = patch_intensity-BC;
	patch_prominence = patch_intensity_BC/PM_base_BC;
	return newArray(patches, patch_density, patch_intensity_BC, patch_prominence, P_bodies);
}		

function get_PM_base(){
	run("Plot Profile");
	run("Find Peaks", "min._peak_amplitude = [] min._peak_distance = 0 min._value = [] max._value = [] list"); //"Find Peaks" is part of the BAR plugin package,available here: https://imagej.net/plugins/bar#installation
	Table.rename("Plot Values", "Results");
	mins = 0;
	PM_base_sum = 0;
	for (k = 0; k < nResults; k++) {
		min_I=getResult("Y2",k);
		if (min_I > 0) {
			PM_base_sum = PM_base_sum + min_I;
			mins++;
		}
	}
	PM_base = PM_base_sum/mins;
	PM_base_BC = PM_base-BC;
//	run("Summarize");
//	plot_mean_BC = getResult("Y0", nResults-4) - BC; //Y0 - intensities along the plasma membrane, the whole intensity plot
//	PEAK = plot_mean_BC * 0.5;
//					waitForUser(BC+"||"+plot_mean_BC+"||"+PEAK);
	return PM_base_BC;
}

function measure_ROI(j, buff){
	select_window(list[i]); //selects raw microscopy image again
	select_ROI(j);
	run("Enlarge...", "enlarge="+buff);
	measurements = measure();
	return measurements;
}

function measure(){
	run("Clear Results");
	run("Measure");
	area = getResult("Area", 0); //area of cell interior
	integral_intensity = getResult("IntDen", 0); //integrated fluorescence intensity
	integral_intensity_BC = integral_intensity - area * BC; //backgorund correction
	mean_intensity = getResult("Mean", 0); //mean fluorescence intensity
	mean_intensity_BC = mean_intensity - BC; //background correction
	SD = getResult("StdDev", 0); //standard deviation of the mean intracellular intensity
	CV = SD/mean_intensity_BC; 
	return newArray(area, integral_intensity_BC, mean_intensity_BC, SD, CV);
}

function measure_cort(){
	select_window(list[i]); //selects raw microscopy image again
	select_ROI(j);
	run("Enlarge...", "enlarge=-0.249");
//	run("Enlarge...", "enlarge=-0.166");
	run("Create Mask");
	rename("Mask-cyt-outer");
	selectWindow(list[i]); //selects raw microscopy image again
	select_window(list[i]);
	select_ROI(j);
	run("Enlarge...", "enlarge=-0.415");
//	run("Enlarge...", "enlarge=-0.332");
	run("Create Mask");
	rename("Mask-cyt-inner");
	imageCalculator("Subtract create", "Mask-cyt-outer","Mask-cyt-inner");
	selectWindow("Result of Mask-cyt-outer");
	run("Create Selection");
	selectWindow(list[i]);
	run("Restore Selection"); //transfer of the selection to the raw microscopy image
	run("Clear Results");
	run("Measure");
	CortCyt_mean = getResult("Mean", 0);
	CortCyt_mean_BC = CortCyt_mean - BC;
	CortCyt_mean_SD = getResult("StdDev", 0);
	return newArray(CortCyt_mean, CortCyt_mean_SD);
}

function clean(membrane_buff){
	D = membrane_buff*0.166;
	roiManager("Select", j);
	run("Enlarge...", "enlarge=-"+D);
	run("Clear", "slice");
	roiManager("Select", j);
	run("Enlarge...", "enlarge="+D);
	run("Make Inverse");
	run("Clear", "slice");
	run("Select None");
}

function select_window(win_title){
	selectWindow(win_title);
	while(!(getTitle == win_title))
		wait(1);
//		selectWindow(win_title);
}

function select_ROI(j){
	roiManager("Select", j);
	while(selectionType() == -1)
		wait(1);
//		roiManager("Select", j);
}