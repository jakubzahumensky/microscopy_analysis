#########################################################################################################################
#version 2.5																											#
#																														#
#This script processes a 'Results' table, e.g., from microscopy image analysis, calculating means and SDs of all		#
#quantified parameters across strains, cultivation media and times, and conditions.										#
#It automatically extracts the column headers and uses them as filenames to store the calculated values 				#
#in the form of tables. The data from individual biological replicates are written into separate columns.				#
#The tables can be directly used for plotting in GraphPad Prism, Systat SigmaPlot etc.									#
#																														#
#The file to be processed needs to be in .csv format (i.e., have the csv extension and be comma-delimited).				#
#Any file with the .csv suffix will be processed, however only one csv file can be present in the folder				#
#when the script is run; otherwise it returns an error.																	#
#The script could be adjusted to accomodate processing of multiple csv files and store results into separate folders,	#
#but that currently does not appear to be useful for the general user.													#
#########################################################################################################################

#extract the column headers and use them to create a 'legend.tmp' file
#this is used later to identify the columns and to name the final files
grep exp_code *.csv | awk '
    {
	n=split($0,a,",")
	for (i=1; i<=n; i++)
		print i","a[i]
    }' > legend.tmp

#the first interesting column in the 'Results' file is just after the 'frame' column and the last one is at the very end
#if the 'frame' column is not found, the script processes all columns in the 'Results' file
start=$(grep frame legend.tmp | cut -d "," -f 1)
start=$((start+1))
end=$(wc -l legend.tmp | cut -d " " -f 1)

#find position of the column with 'experimental code' information
#define which experimental parameters are relevant for filtering before calculation of means and SDs
exp_code_column=$(grep exp_code legend.tmp | cut -d "," -f 1)
parameters=("BR_date" "strain" "medium" "time" "condition")

#remove the comments section in the beginning of the 'Results' file
#remove the column names from the 'Results' file
#extract experimental codes from the 'Results' file; a separate folder will be created for each
grep -v '#' *.csv > Results.tmp
sed -i '1d' Results.tmp
cut -d "," -f $exp_code_column Results.tmp | sort | uniq > experiments.tmp

dot="."
for x in $(cat experiments.tmp); do
	echo
	echo $x "- calculating means and SDs, and cells in replicates and conditions"
	mkdir $x; \
	#for each experiment, create temporary files (lists) with all possible strains, cultivation media and times, and conditions
	#if any of them is not defined, the list will contain a dot (decimal sign; 'grep $dot Results.tmp' returns all lines, as the decimal sign is omnipresent
	for i in $(seq 0 4); do
		grep $x Results.tmp | cut -d "," -f $(grep ${parameters[i]} legend.tmp | cut -d "," -f 1) | sort | uniq > $x/${parameters[i]}.tmp
		if [ ! -s $x/${parameters[i]}.tmp ]; then
			echo $dot > $x/${parameters[i]}.tmp
			echo " -> the above 'cut' issue means that the '" ${parameters[i]} "' parameter is not defined"
		fi;
	done;
	#loop through all possible parameters and calculate the means and SDs; store each in a separate table
	for STRAIN in $(cat $x/strain.tmp); do
		for MEDIUM in $(cat $x/medium.tmp); do
			for TIME in $(cat $x/time.tmp); do
				for COND in $(cat $x/condition.tmp); do
					echo "Crunching numbers for:" $STRAIN $MEDIUM $TIME $COND
					#create "left side" for the output tables
					echo -e $STRAIN'\t'$MEDIUM'\t'$TIME'\t'$COND &>> $x/left_side.tmp
					for DATE in $(cat $x/BR_date.tmp); do
						#count cells across conditions and strains etc.
						grep $x Results.tmp | grep ,$STRAIN, | grep ,$MEDIUM, | grep ,$TIME, | grep ,$COND, | grep -c ,$DATE, &>> $x/$DATE-cell_count.tmp
						for col in $(seq $start $end); do
							#calculate means and SDs for each combination of exp, date, strain, medium, condition, etc.
							grep $x Results.tmp | grep ,$DATE, | grep ,$STRAIN, | grep ,$MEDIUM, | grep ,$TIME, | grep ,$COND, | awk -v i="$col" -F "," '{a+=$i} END{print a/NR}' &>> $x/$col-$DATE-means.tmp
							grep $x Results.tmp | grep ,$DATE, | grep ,$STRAIN, | grep ,$MEDIUM, | grep ,$TIME, | grep ,$COND, | awk -v i="$col" -F "," '{delta = $i - avg; avg += delta / NR; mean2 += delta * ($i - avg); } END { print sqrt(mean2 / NR); }' &>> $x/$col-$DATE-SDs.tmp
						done
					done
				done
			done
		done
	done
	echo "Concatenating temporary files";
	#create the 'left side' of the header for the output tables
	echo -e strain'\t'medium'\t'cult_time'\t'condition > $x/left_side_header.tmp
	#create the 'right side' of the header for the output tables, i.e., columns of values for individual biological replicates
	for DATE in $(cat $x/BR_date.tmp); do
		echo $DATE > $x/date_$DATE.tmp
	done
	paste $x/left_side_header.tmp $x/date_* > $x/header.tmp
	#create a table with the number of cells in each condition in each biological replicate
	paste $x/left_side.tmp $x/*-cell_count.tmp > $x/cell_counts.tmp
	cat $x/header.tmp $x/cell_counts.tmp > $x/cell_counts.tsv
	#create tables with means and SDs for each analyzed parameter
	for col in $(seq $start $end); do
		paste $x/left_side.tmp $x/$col*means.tmp > $x/$col-means.tmp
		paste $x/left_side.tmp $x/$col*SDs.tmp > $x/$col-SDs.tmp
		C=$(grep -w $col legend.tmp | cut -d "," -f 2)
		cat $x/header.tmp $x/$col-means.tmp > $x/$C-means.tsv
		cat $x/header.tmp $x/$col-SDs.tmp > $x/$C-SDs.tsv
	done
	echo "Cleaning"
	rm $x/*.tmp
	rm $x/cell_no-*
done

rm *.tmp
for FILE in $x/*.tsv; do
	sed -i 's/awk: cmd. line:1: fatal: division by zero attempted//g' $FILE
done
echo "Finito!"