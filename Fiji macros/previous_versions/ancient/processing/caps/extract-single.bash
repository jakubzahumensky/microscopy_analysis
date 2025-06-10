#sed -i 's/NaN//g' Results.tmp
grep -v '#' Results*.csv > Results.tmp
sed -i '1d' Results.tmp
cut -d "," -f 1 Results.tmp | sort | uniq > experiments.tmp

for x in $(cat experiments.tmp); do \
	mkdir $x; echo $x > $x/x.tmp; \
	grep $x Results.tmp | cut -d "," -f 2 | sort | uniq > $x/dates.tmp; \
	grep $x Results.tmp | cut -d "," -f 3 | sort | uniq > $x/strains.tmp; \
	grep $x Results.tmp | cut -d "," -f 4 | sort | uniq > $x/media.tmp; \
	grep $x Results.tmp | cut -d "," -f 6 | sort | uniq > $x/conditions.tmp; \
	for col in $(cat columns.csv); do \
		for MEDIUM in $(cat $x/media.tmp); do \
		for STRAIN in $(cat $x/strains.tmp); do \
		for COND in $(cat $x/conditions.tmp); do \
		for DATE in $(cat $x/dates.tmp); do \
			grep $x Results.tmp | grep ,$MEDIUM, | grep ,$STRAIN, | grep ,$COND, | grep ,$DATE, | awk -v i="$col" -F "," '{a+=$i} END{print a/NR}' &>> $x/$col-$DATE-means.tmp; \
			grep $x Results.tmp | grep ,$MEDIUM, | grep ,$STRAIN, | grep ,$COND, | grep ,$DATE, | awk -v i="$col" -F "," '{delta = $i - avg; avg += delta / NR; mean2 += delta * ($i - avg); } END { print sqrt(mean2 / NR); }' &>> $x/$col-$DATE-SDs.tmp; \
		done; \
		done; \
		done; \
		done; \
	done; \

	for MEDIUM in $(cat $x/media.tmp); do \
		for STRAIN in $(cat $x/strains.tmp); do \
		for COND in $(cat $x/conditions.tmp); do \
		for DATE in $(cat $x/dates.tmp); do \
			grep $x Results.tmp | grep ,$MEDIUM, | grep ,$STRAIN, | grep ,$COND, | grep -c ,$DATE, &>> $x/$DATE-cell_count.tmp; \
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
	for DATE in $(cat $x/dates.tmp); do echo $DATE > $x/date_$DATE.tmp; done; \
	paste $x/left_side_header.tmp $x/date_* > $x/header.tmp; \
	paste $x/left_side.tmp $x/*-cell_count.tmp > $x/cell_counts.tmp; \
	cat $x/header.tmp $x/cell_counts.tmp > $x/cell_counts.tsv; \
	
	for col in $(cat columns.csv); do \
		paste $x/left_side.tmp $x/$col*means.tmp > $x/$col-means.tmp; \
		paste $x/left_side.tmp $x/$col*SDs.tmp > $x/$col-SDs.tmp; \
		C=$(grep -w $col legend.csv | cut -d "," -f 2); \
		cat $x/header.tmp $x/$col-means.tmp > $x/$C-means.tsv; \
		cat $x/header.tmp $x/$col-SDs.tmp > $x/$C-SDs.tsv; \
	done; \

        echo -e medium'\t'strain'\t'condition > $x/header_top.tmp; \
        cp $x/left_side.tmp $x/master.tmp; \
        for col in $(cat columns-single.csv); do \
            paste $x/master.tmp $x/$col-$DATE-means.tmp $x/$col-$DATE-SDs.tmp > $x/master2.tmp; \
            cp $x/master2.tmp $x/master.tmp;\
            C=$(grep -w $col legend.csv | cut -d "," -f 2); \
            echo -e $C'-mean\t'$C'-SD' > $x/top.tmp; \
            paste $x/header_top.tmp $x/top.tmp > $x/header_top2.tmp; \
            cp $x/header_top2.tmp $x/header_top.tmp; \
        done; \
        cat $x/header_top.tmp $x/master.tmp > $x/_master.tsv; \

	rm $x/*.tmp
done
rm *.tmp
for FILE in $x/*.tsv; do sed -i 's/awk: cmd. line:1: fatal: division by zero attempted//g' $FILE; done





