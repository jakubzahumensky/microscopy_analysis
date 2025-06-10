setBatchMode(true); // starts batch mode
var extension_list = newArray("czi", "oif", "tif", "vsi"); // only files with these extensions will be processed
var pixelWidth = 0;
var experiment_scheme = "JZ-M-000";

Dialog.create("WS_coloc)"); // Creates dialog window with the name "Batch export"
	Dialog.addDirectory("Directory:", "");	// Asks for directory to be processed. Copy paste your complete path here
    Dialog.show();
	dir = Dialog.getString();

dirMaster = dir;

run("Clear Results");
close("*");
print("\\Clear");
print("exp_code,BR_date,strain,medium,time,condition,frame,cell_count,Sur7_puncta,Elk1_puncta,coloc_puncta,Sur7_puncta_per_cell,Elk1_puncta_per_cell,Sur7_coloc_ratio,Elk1_coloc_ratio");
processFolder(dir);
selectWindow("Log");
saveAs("Text", dirMaster+"WS_coloc_results.csv");
close("Results");
close("ROI manager");
close("Log");

function processFolder(dir) {
	list = getFileList(dir);
	for (i = 0; i < list.length; i++) {
		showProgress(i+1, list.length);
		if (endsWith(list[i], "/"))
        	processFolder(""+dir+list[i]);
		else {
			if (endsWith(dir, "data/")){
				q = dir+list[i];
        		processFile(q);
			}
      }
   }
}

function processFile(q) {
	extIndex = lastIndexOf(q, ".");
	ext = substring(q, extIndex+1);
	if (contains(extension_list, ext)) {
		maskDir = mkdir("data", "PM_masks-WS");
		roiDir = mkdir("data", "ROIs");
		open(q);
        title = File.nameWithoutExtension;
        getPixelSize(unit, pixelWidth, pixelHeight);
		roiManager("reset");
		roiManager("Open", roiDir + title + "-RoiSet.zip");
		numROIs = roiManager("count");
		open(maskDir+title+".tif-PM_mask-WS.tif");
		rename("PM_mask");
		prep_WS(title,1);
		prep_WS(title,2);
	close("PM_mask");
	imageCalculator("Multiply create", "patches_ch1", "patches_ch2");
	rename("patches_coloc");
	run("Despeckle");
	ch1_patches = count_patches("patches_ch1", 0.36/pow(pixelWidth, 2), 0.5);
	ch2_patches = count_patches("patches_ch2", 0.36/pow(pixelWidth, 2), 0.5);
	coloc_patches = count_patches("patches_coloc", "Infinity", 0);
	parents = find_parents();
	print(parents[0]+","+parents[1]+","+title+","+numROIs+","+ch1_patches+","+ch2_patches+","+coloc_patches+","+ch1_patches/numROIs+","+ch2_patches/numROIs+","+100*coloc_patches/ch1_patches+","+100*coloc_patches/ch2_patches);
	close("*");
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

function prep_WS(title,channel){
	WSDir = mkdir("data", "watershed_segmentation-ch"+channel);
	open(WSDir+title+".tif-WS.png");
	run("Invert");
	rename("ch"+channel);
	imageCalculator("Multiply", "ch"+channel, "PM_mask");
	rename("patches_ch"+channel);
	run("Despeckle");
}

function count_patches(win_title,size_MAX,circ_min){
	selectWindow(win_title);
	run("Invert");
	run("Convert to Mask");
	run("Analyze Particles...", "size=0-"+size_MAX+" circularity=" + circ_min + "-1.00 show=Masks display clear overlay");
	run("Invert");
	patches = nResults;
	rename("patches_"+win_title);
	close(win_title);
	return patches;
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

setBatchMode(false);
waitForUser("Finito!");