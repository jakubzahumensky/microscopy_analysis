# sed -i 's/NaN//g' Results-cleaned.tmp
grep -v '#' Results*.csv > Results.tmp
grep -v NaN Results.tmp > Results-cleaned.tmp
cut -d "," -f 1 Results-cleaned.tmp | sort | uniq > experiments.tmp

for x in $(cat experiments.tmp); do \
	mkdir $x-cleaned; echo $x > $x-cleaned/x.tmp; \
	grep $x Results-cleaned.tmp | cut -d "," -f 2 | sort | uniq > $x-cleaned/dates.tmp; \
	grep $x Results-cleaned.tmp | cut -d "," -f 3 | sort | uniq > $x-cleaned/strains.tmp; \
	grep $x Results-cleaned.tmp | cut -d "," -f 4 | sort | uniq > $x-cleaned/media.tmp; \
	grep $x Results-cleaned.tmp | cut -d "," -f 5 | sort | uniq > $x-cleaned/conditions.tmp; \
	for col in $(cat columns.csv); do \
		for MEDIUM in $(cat $x-cleaned/media.tmp); do \
		for STRAIN in $(cat $x-cleaned/strains.tmp); do \
		for COND in $(cat $x-cleaned/conditions.tmp); do \
		for DATE in $(cat $x-cleaned/dates.tmp); do \
			grep $x Results-cleaned.tmp | grep ,$MEDIUM, | grep ,$STRAIN, | grep ,$COND, | grep ,$DATE, | awk -v i="$col" -F "," '{a+=$i} END{print a/NR}' &>> $x-cleaned/$col-$DATE-means.tmp; \
			grep $x Results-cleaned.tmp | grep ,$MEDIUM, | grep ,$STRAIN, | grep ,$COND, | grep ,$DATE, | awk -v i="$col" -F "," '{delta = $i - avg; avg += delta / NR; mean2 += delta * ($i - avg); } END { print sqrt(mean2 / NR); }' &>> $x-cleaned/$col-$DATE-SDs.tmp; \
		done; \
		done; \
		done; \
		done; \
	done; \

	for MEDIUM in $(cat $x-cleaned/media.tmp); do \
		for STRAIN in $(cat $x-cleaned/strains.tmp); do \
		for COND in $(cat $x-cleaned/conditions.tmp); do \
		for DATE in $(cat $x-cleaned/dates.tmp); do \
			grep $x Results-cleaned.tmp | grep ,$MEDIUM, | grep ,$STRAIN, | grep ,$COND, | grep -c ,$DATE, &>> $x-cleaned/$DATE-cell_count.tmp; \
		done; \
		done; \
		done; \
	done; \
	for MEDIUM in $(cat $x-cleaned/media.tmp); do \
		for STRAIN in $(cat $x-cleaned/strains.tmp); do \
		for COND in $(cat $x-cleaned/conditions.tmp); do \
			echo -e $MEDIUM'\t'$STRAIN'\t'$COND &>> $x-cleaned/left_side.tmp; \
		done; \
		done; \
	done; \
		
	echo -e medium'\t'strain'\t'condition > $x-cleaned/left_side_header.tmp; \
	for DATE in $(cat $x-cleaned/dates.tmp); do echo $DATE > $x-cleaned/date_$DATE.tmp; done; \
	paste $x-cleaned/left_side_header.tmp $x-cleaned/date_* > $x-cleaned/header.tmp; \
	paste $x-cleaned/left_side.tmp $x-cleaned/*-cell_count.tmp > $x-cleaned/cell_counts.tmp; \
	cat $x-cleaned/header.tmp $x-cleaned/cell_counts.tmp > $x-cleaned/cell_counts.tsv; \
	
	for col in $(cat columns.csv); do \
		paste $x-cleaned/left_side.tmp $x-cleaned/$col*means.tmp > $x-cleaned/$col-means.tmp; \
		paste $x-cleaned/left_side.tmp $x-cleaned/$col*SDs.tmp > $x-cleaned/$col-SDs.tmp; \
		C=$(grep -w $col legend.csv | cut -d "," -f 2); \
		cat $x-cleaned/header.tmp $x-cleaned/$col-means.tmp > $x-cleaned/$C-means.tsv; \
		cat $x-cleaned/header.tmp $x-cleaned/$col-SDs.tmp > $x-cleaned/$C-SDs.tsv; \
	done; \
	rm $x-cleaned/*.tmp
done
rm *.tmp
for FILE in $x-cleaned/*.tsv; do sed -i 's/awk: cmd. line:1: fatal: division by zero attempted//g' $FILE; done
