#version 2.5
#the name of the file to be processed needs to begin with "Results"
#sed -i 's/NaN//g' Results.tmp

#the dot is used as a wildcard if some parameters (strain, medium, time, condition) is missing in the results table
#the decimal dot is omnipresent throughout the Results, so grep $dot displays all lines
dot="."
grep exp_code Results* | awk '
     {
      n=split($0,a,",");
      for (i=1; i<=n; i++)
          print i","a[i]
     }' > legend.tmp

#the first interesting column in the Results file is just after the "frame" column and the last one is at the very end
#if the "frame" column is not found, the script starts at the first column and goes to the end
start=$(grep frame legend.tmp | cut -d "," -f 1)
start=$((start+1))
end=$(wc -l legend.tmp | cut -d " " -f 1)

#identify columns that describe the experiment and store their numbers in respective variables
exp_code_column=$(grep exp_code legend.tmp | cut -d "," -f 1)
BR_dates_column=$(grep BR_date legend.tmp | cut -d "," -f 1)
strains_column=$(grep strain legend.tmp | cut -d "," -f 1)
media_column=$(grep medium legend.tmp | cut -d "," -f 1)
times_column=$(grep time legend.tmp | cut -d "," -f 1)
conditions_column=$(grep condition legend.tmp | cut -d "," -f 1)

#remove the comments section in the beginning of the Results file
grep -v '#' Results*.csv > Results.tmp
#remove the column names from the Results file
sed -i '1d' Results.tmp
#extract experimental codes from the Results file; a separate folder will be created for each
cut -d "," -f 1 Results.tmp | sort | uniq > experiments.tmp

#calculate means and SDs for each combination of exp, date, strain, medium, condition, etc.
for x in $(cat experiments.tmp); do \
	mkdir $x; \
       	grep $x Results.tmp | cut -d "," -f $BR_dates_column | sort | uniq > $x/dates.tmp; \
	grep $x Results.tmp | cut -d "," -f $strains_column | sort | uniq > $x/strains.tmp; \
        if [ ! -s $x/strains.tmp ]; then
            echo $dot > $x/strains.tmp
        fi;
	grep $x Results.tmp | cut -d "," -f $media_column | sort | uniq > $x/media.tmp; \
        if [ ! -s $x/media.tmp ]; then
            echo $dot > $x/media.tmp
        fi;
	grep $x Results.tmp | cut -d "," -f $conditions_column | sort | uniq > $x/conditions.tmp; \
        if [ ! -s $x/conditions.tmp ]; then
            echo $dot > $x/conditions.tmp
        fi;
       	grep $x Results.tmp | cut -d "," -f $times_column | sort | uniq > $x/cult_times.tmp; \
        if [ ! -s $x/cult_times.tmp ]; then
            echo $dot > $x/cult_times.tmp
        fi;

        for col in $(seq $start $end); do \
                echo $x "- calculating means and SDs: column" $col "out of" $end; \
                for DATE in $(cat $x/dates.tmp); do \
		for STRAIN in $(cat $x/strains.tmp); do \
                for MEDIUM in $(cat $x/media.tmp); do \
                for TIME in $(cat $x/cult_times.tmp); do \
		for COND in $(cat $x/conditions.tmp); do \
                        grep $x Results.tmp | grep ,$DATE, | grep ,$STRAIN, | grep ,$MEDIUM, | grep ,$TIME, | grep ,$COND, | awk -v i="$col" -F "," '{a+=$i} END{print a/NR}' &>> $x/$col-$DATE-means.tmp; \
			grep $x Results.tmp | grep ,$DATE, | grep ,$STRAIN, | grep ,$MEDIUM, | grep ,$TIME, | grep ,$COND, | awk -v i="$col" -F "," '{delta = $i - avg; avg += delta / NR; mean2 += delta * ($i - avg); } END { print sqrt(mean2 / NR); }' &>> $x/$col-$DATE-SDs.tmp; \
		done; \
		done; \
		done; \
                done; \
		done; \
	done; \

#count cells across conditions and strains etc.
        echo "Counting cells in replicates and conditions"; \
        for MEDIUM in $(cat $x/media.tmp); do \
                for TIME in $(cat $x/cult_times.tmp); do \
		for STRAIN in $(cat $x/strains.tmp); do \
		for COND in $(cat $x/conditions.tmp); do \
		for DATE in $(cat $x/dates.tmp); do \
			grep $x Results.tmp | grep ,$STRAIN, | grep ,$MEDIUM, | grep ,$TIME, | grep ,$COND, | grep -c ,$DATE, &>> $x/$DATE-cell_count.tmp; \
		done; \
		done; \
		done; \
                done; \
        done; \

#create "left side" for the output tables
        echo "Concatenating temporary files"; \
        for MEDIUM in $(cat $x/media.tmp); do \
                for TIME in $(cat $x/cult_times.tmp); do \
		for STRAIN in $(cat $x/strains.tmp); do \
		for COND in $(cat $x/conditions.tmp); do \
			echo -e $STRAIN'\t'$MEDIUM'\t'$TIME'\t'$COND &>> $x/left_side.tmp; \
		done; \
		done; \
                done; \
	done; \

#create header fo the "left side" of the output tables
	echo -e strain'\t'medium'\t'cult_time'\t'condition > $x/left_side_header.tmp; \
	for DATE in $(cat $x/dates.tmp); do echo $DATE > $x/date_$DATE.tmp; done; \
	paste $x/left_side_header.tmp $x/date_* > $x/header.tmp; \
	paste $x/left_side.tmp $x/*-cell_count.tmp > $x/cell_counts.tmp; \
	cat $x/header.tmp $x/cell_counts.tmp > $x/cell_counts.tsv; \
	
        for col in $(seq $start $end); do \
		paste $x/left_side.tmp $x/$col*means.tmp > $x/$col-means.tmp; \
		paste $x/left_side.tmp $x/$col*SDs.tmp > $x/$col-SDs.tmp; \
		C=$(grep -w $col legend.tmp | cut -d "," -f 2); \
		cat $x/header.tmp $x/$col-means.tmp > $x/$C-means.tsv; \
		cat $x/header.tmp $x/$col-SDs.tmp > $x/$C-SDs.tsv; \
	done; \
        echo "Cleaning"; \
	rm $x/*.tmp
        rm $x/cell_no-*
done

rm *.tmp
for FILE in $x/*.tsv; do sed -i 's/awk: cmd. line:1: fatal: division by zero attempted//g' $FILE; done;\
echo "Finito!"