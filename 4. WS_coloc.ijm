setBatchMode(true); // starts batch mode
extension_list = newArray("czi", "oif", "tif", "vsi", "lif"); // only files with these extensions will be processed
image_types = newArray("transversal", "tangential"); //there are either tranversal (going through the middle) or tangential (showing the surface) microscopy images. Z-stack projections are a special case of the latter.

var pixelWidth = 0;
var experiment_scheme = "JZ-M-000";
var subset_default = "";
var count = 0;
var FOCI = newArray(2);

html = "<html>"
	+"<b>Directory</b><br>"
	+"Specify the directory where you want <i>Fiji</i> to start looking for folders with images. The macro works <i>recursively</i>, i.e., it looks into all subfolders. "
	+"All folders with names <i>ending</i> with the word \"<i>data</i>\" for <i>transversal</i> image type) or \"<i>data-caps</i>\" (for <i>tangential</i> image type) are processed. "
	+"All other folders are ignored.<br>"
	+"<br>"
	+"<b>Subset</b><br>"
	+"If used, only images with filenames containing specified <i>string</i> (i.e., group of characters and/or numbers) will be processed. "
	+"This option can be used to selectively process images of a specific strain, condition, etc. "
	+"Leave empty to process all images in specified directory (and its subdirectories).<br>"
	+"<br>"
	+"<b>Channels</b><br>"
	+"Specify <i>2</i> image channels (comma separated) to be analyzed.<br>" 
	+"<br>"
	+"<b>Naming scheme</b><br>"
	+"Specify how your files are named (without extension). Results are reported in a comma-separated table, with the parameters specified here used as column headers. "
	+"The default \"<i>strain,medium,time,condition,frame</i>\" creates 5 columns, with titles \"strains\", \"medium\" etc. "
	+"Using a consistent naming scheme accross your data enables automated downstream data processing.<br>"
	+"<br>"
	+"<b>Experiment code scheme</b><br>"
	+"Specify how your experiments are coded. The macro assumes a folder structure of <i>\".../experimental_code/biological_replicate_date/data<sup>*</sup>/\"</i>. See protocol for details.<br>"
	+"<sup>*</sup> - or <i>\"data-caps\"</i> for tangential images. <br>"
	+"<br>"
	+"</html>";

Dialog.create("WS_coloc"); // Creates dialog window with the name "Batch export"
	Dialog.addDirectory("Directory:", "");	// Asks for directory to be processed. Copy paste your complete path here
    Dialog.addString("Subset (optional):", subset_default);
    Dialog.addString("Channels:", "1,2");
    Dialog.addString("Naming scheme:", "strain,medium,time,condition,frame", 33);
	Dialog.addString("Experiment code scheme:", "XY-M-000", 33);
	Dialog.addChoice("Image type:", image_types);
	Dialog.addHelp(html);
    Dialog.show();
	dir = replace(Dialog.getString(), "\\", "/");
	subset = Dialog.getString();
	CHANNEL = split(replace(Dialog.getString(), " ", ""), ",,");
	naming_scheme = Dialog.getString();
	experiment_scheme = Dialog.getString();
	image_type = Dialog.getChoice();

dirMaster = dir;

run("Clear Results");
close("*");
print("\\Clear");
print("exp_code,BR_date," + naming_scheme + ",cell_count,channel_1_puncta,channel_2_puncta,coloc_puncta,coloc_ratio-ch1_with_ch2,coloc_ratio-ch2_with_ch1");

countFiles(dir);
processFolder(dir);

selectWindow("Log");
getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
res = "Results of WS coloc analysis (" + year + "-" + String.pad(month + 1,2) + "-" + String.pad(dayOfMonth,2) + "," + String.pad(hour,2) + "-" + String.pad(minute,2) + "-" + String.pad(second,2) + ").csv";
saveAs("Text", dirMaster + res);
close("Results");
close("ROI manager");
close("Log");

function processFolder(dir) {
	list = getFileList(dir);
	for (i = 0; i < list.length; i++) {
		showProgress(i+1, list.length);
		if (endsWith(list[i], "/"))
        	processFolder("" + dir + list[i]);
		else {
			q = dir + list[i];
//			if ((endsWith(dir, "data/") || endsWith(dir, "data-caps/")) && indexOf(q, subset) >= 0){
			if (endsWith(dir, image_type + "/data/") && indexOf(q, subset) >= 0){
				extIndex = lastIndexOf(q, ".");
				ext = substring(q, extIndex+1);
				if (contains(extension_list, ext))
					processFile(q);
			}
		}
	}
}

function countFiles(dir) {
	list = getFileList(dir);
	for (i = 0; i < list.length; i++) {
		if (endsWith(list[i], "/"))
			countFiles("" + dir + list[i]);
		else {
			q = dir + list[i];
//			if ((endsWith(dir, "data/") || endsWith(dir, "data-caps/")) && indexOf(q, subset) >= 0){
			if (endsWith(dir, image_type + "/data/") && indexOf(q, subset) >= 0){
				count++;
				open(dir + list[i]);
				getDimensions(width, height, channels, slices, frames);
				Array.getStatistics(CHANNEL, CHANNEL_min, CHANNEL_max, CHANNEL_mean, CHANNEL_stdDev);
				if (channels < CHANNEL_max)
					exit("One or more images in the data set do not have one or more selected channels ("+ CHANNEL[0] + " & " + CHANNEL[1] +"). Check your data and restart analysis.");
				close();
			}
		}
	}
}

function contains(array, value) {
    for (i=0; i<array.length; i++) 
        if (array[i] == value) return true;
    return false;
}

function mkdir(template_dir, dir_name){
   	DIR = replace(dir, template_dir, dir_name);
	if(!File.exists(DIR))
		File.makeDirectory(DIR);
	return DIR;
}

function processFile(q) {
//get pixelsize from the image
	open(q);
    title = File.nameWithoutExtension;
    getPixelSize(unit, pixelWidth, pixelHeight);
//count analyzed cells
    roiDir = File.getParent(dir)+"/"+replace(File.getName(dir), "data", "ROIs")+"/";
	roiManager("reset");
	roiManager("Open", roiDir + title + "-RoiSet.zip");
	numROIs = roiManager("count");
    
	for (i = 0; i <= CHANNEL.length-1; i++){
		watershedDir = File.getParent(dir) + "/" + replace(File.getName(dir), "data", "watershed_segmentation-ch") + CHANNEL[i] + "/";
		open(watershedDir + title + "-WS_foci.png");
//		run("Invert");
		rename("foci_ch" + CHANNEL[i]);
	}
	imageCalculator("Multiply create", "foci_ch"+CHANNEL[0], "foci_ch"+CHANNEL[1]);
	rename("foci_coloc");
//	run("Invert");
	run("Despeckle");	
	for (i = 0; i <= CHANNEL.length-1; i++){
		FOCI[i] = count_foci("foci_ch" + CHANNEL[i], 0.36/pow(pixelWidth, 2), 0.5); //win_title, size_MAX, min_circularity
	}
	coloc_foci = count_foci("foci_coloc", "Infinity", 0);
	parents = find_parents();
	print(parents[0]+","+parents[1]+","+title+","+numROIs+","+FOCI[0]+","+FOCI[1]+","+coloc_foci+","+100*coloc_foci/FOCI[0]+","+100*coloc_foci/FOCI[1]);
	close("*");
}

function count_foci(win_title,size_MAX,circularity_min){
	selectWindow(win_title);
	run("Invert");
	run("Convert to Mask");
	run("Analyze Particles...", "size=0-"+size_MAX+" circularity=" + circularity_min + "-1.00 show=Masks display clear overlay");
	run("Invert");
	foci = nResults;
	close(win_title);
	return foci;
}

function find_parents(){
	parent = File.getParent(File.getParent(dir)); // bio replicate date (two levels up from the "data" folder)
	grandparent = File.getParent(parent); // one level above the bio replicate filder; name starts with the experiment code (accession number)
	// replace spaces with underscores in both to prevent possible issues in automatic bash and R processing
	BR_date = replace(File.getName(parent)," ","_");
	exp_code = replace(File.getName(grandparent)," ","_");
	// date is expected in YYMMDD (or another 6-digit) format; if it is shorter, the whole name is kept; analogous with the "experimental code"
	if (lengthOf(BR_date) > 6)
		BR_date = substring(BR_date, 0, 6);
	if (lengthOf(exp_code) > lengthOf(experiment_scheme))
		exp_code = substring(exp_code, 0, lengthOf(experiment_scheme));
	return newArray(exp_code, BR_date);
}

setBatchMode(false);
waitForUser("Finito!");