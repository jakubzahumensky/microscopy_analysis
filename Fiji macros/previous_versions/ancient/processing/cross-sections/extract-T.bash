sed -i 's/NaN//g' Summary*.csv
cut -d "," -f 1 Summary*.csv | sort | uniq > experiments.tmp
sed -i '1d' experiments.tmp

for x in $(cat experiments.tmp); do \
	mkdir $x; echo $x > $x/x.tmp; \
	grep $x Summary*.csv | cut -d "," -f 2 | sort | uniq > $x/dates.tmp; \
	grep $x Summary*.csv | cut -d "," -f 3 | sort | uniq > $x/strains.tmp; \
	grep $x Summary*.csv | cut -d "," -f 4 | sort | uniq > $x/media.tmp; \
	grep $x Summary*.csv | cut -d "," -f 5 | sort | uniq > $x/conditions.tmp; \
	for col in $(cat columns.csv); do \
		for MEDIUM in $(cat $x/media.tmp); do \
		for STRAIN in $(cat $x/strains.tmp); do \
		for COND in $(cat $x/conditions.tmp); do \
		for DATE in $(cat $x/dates.tmp); do \
			grep $x Summary*.csv | grep ,$MEDIUM, | grep ,$STRAIN, | grep ,$COND, | grep ,$DATE, | awk -v i="$col" -F "," '{a+=$i} END{print a/NR}' &>> $x/$col-$DATE-means.tmp; \
			grep $x Summary*.csv | grep ,$MEDIUM, | grep ,$STRAIN, | grep ,$COND, | grep ,$DATE, | awk -v i="$col" -F "," '{delta = $i - avg; avg += delta / NR; mean2 += delta * ($i - avg); } END { print sqrt(mean2 / NR); }' &>> $x/$col-$DATE-SDs.tmp; \
		done; \
		done; \
		done; \
		done; \
	done; \

	for MEDIUM in $(cat $x/media.tmp); do \
		for STRAIN in $(cat $x/strains.tmp); do \
		for COND in $(cat $x/conditions.tmp); do \
		for DATE in $(cat $x/dates.tmp); do \
			grep $x Summary*.csv | grep ,$MEDIUM, | grep ,$STRAIN, | grep ,$COND, | grep -c ,$DATE, &>> $x/$DATE-cell_count.tmp; \
		done; \
		done; \
		done; \
        done; \

        for MEDIUM in $(cat $x/media.tmp); do \
		for STRAIN in $(cat $x/strains.tmp); do \
		for COND in $(cat $x/conditions.tmp); do \
			echo -e $MEDIUM'\t'$STRAIN'\t'$COND &>> $x/left_side.tmp; \
		done; \
		done; \
	done; \
		
	echo -e medium'\t'strain'\t'condition > $x/left_side_header.tmp; \
#	for COND in $(cat $x/conditions.tmp); do echo $COND &>> $x/cond_$COND.tmp; echo $COND &>> $x/cond_$COND.tmp; echo $COND &>> $x/cond_$COND.tmp; done; \
	paste $x/left_side_header.tmp $x/cond_* > $x/header.tmp; \
	paste $x/left_side.tmp $x/*-cell_count.tmp > $x/cell_counts.tmp; \
	cat $x/header.tmp $x/cell_counts.tmp > $x/cell_counts.tsv; \
	
	for col in $(cat columns.csv); do \
		paste $x/left_side.tmp $x/$col*means.tmp > $x/$col-means.tmp; \
		paste $x/left_side.tmp $x/$col*SDs.tmp > $x/$col-SDs.tmp; \
		C=$(grep -w $col legend.csv | cut -d "," -f 2); \
		cat $x/header.tmp $x/$col-means.tmp > $x/$C-means.tsv; \
		cat $x/header.tmp $x/$col-SDs.tmp > $x/$C-SDs.tsv; \
	done; \
	rm $x/*.tmp
done
rm *.tmp
for FILE in $x/*.tsv; do sed -i 's/awk: cmd. line:1: fatal: division by zero attempted//g' $FILE; done
