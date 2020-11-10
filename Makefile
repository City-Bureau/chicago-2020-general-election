S3_BUCKET = city-bureau-projects
CLOUDFRONT_ID = E1KVCPPPIJI04K
COOK_ONLY_IDS = 918 920 922 923 932 942 960 961 964 965 966 967 968 970 972 976 978 979
RESULTS :=  $(shell cat input/metadata.json | jq -r 'keys[]' | xargs -I {} echo "output/results/combined/{}.csv")

.PHONY: data
data: $(RESULTS) output/tiles/precincts/

.PHONY: all
all: input/results-metadata.json

.PRECIOUS: input/251/%.html input/cook/%.html output/results/251/%.csv output/results/cook/%.csv

.PHONY: deploy
deploy:
	aws s3 cp ./output/tiles s3://$(S3_BUCKET)/cook-2020-general-election/tiles/ --recursive --acl=public-read --cache-control "public, max-age=31536000" --size-only --content-encoding=gzip --region=us-east-1
	aws s3 cp ./output/results/combined s3://$(S3_BUCKET)/cook-2020-general-election/results/ --acl=public-read --cache-control "public, max-age=86400, must-revalidate" --size-only --recursive --acl=public-read --region=us-east-1
	aws cloudfront create-invalidation --distribution-id $(CLOUDFRONT_ID) --paths /cook-2020-general-election/*

output/tiles/precincts/: input/precincts.mbtiles
	mkdir -p output/tiles
	tile-join --no-tile-size-limit --force -e $@ $<

output/results/combined/%.csv: output/results/cook/%.csv output/results/251/%.csv
	mkdir -p $(dir $@)
	xsv cat rows $^ > $@

output/results/cook/0.csv: input/cook/0.html
	mkdir -p $(dir $@)
	pipenv run python scripts/scrape_cook_table.py $< | \
	xsv select id,township,ward,precinct,registered,ballots,turnout - > $@

output/results/cook/%.csv: input/cook/%.html
	mkdir -p $(dir $@)
	pipenv run python scripts/scrape_cook_table.py $< > $@

$(foreach i,$(COOK_ONLY_IDS),output/results/251/$(i).csv):
	touch $@

output/results/251/0.csv: input/251/0.html
	mkdir -p $(dir $@)
	echo "id,township,ward,precinct,registered,ballots,turnout" > $@
	pipenv run python scripts/scrape_table.py $< | \
	xsv select --no-headers 1-5,8- - | \
	xsv slice --no-headers -s 1 - >> $@

output/results/251/%.csv: input/251/%.html
	mkdir -p $(dir $@)
	pipenv run python scripts/scrape_table.py $< > $@

input/251/%.html:
	mkdir -p $(dir $@)
	curl https://chicagoelections.gov/en/election-results-specifics.asp -X POST -H "Content-Type: application/x-www-form-urlencoded" -d "election=251&race=$*&ward=&precinct=" -o $@

input/251/0.html:
	mkdir -p $(dir $@)
	curl https://chicagoelections.gov/en/election-results-specifics.asp -X POST -H "Content-Type: application/x-www-form-urlencoded" -d "election=251&race=&ward=&precinct=" -o $@

input/cook/0.html: input/cook/11.html
	cp $< $@

input/cook/%.html:
	mkdir -p $(dir $@)
	pipenv run python scripts/download_cook_table.py $* > $@

input/results-metadata.json:
	pipenv run python scripts/scrape_results_metadata.py > $@

input/precincts.mbtiles: input/precincts.geojson
	tippecanoe --simplification=10 --simplify-only-low-zooms --maximum-zoom=11 --no-tile-stats --generate-ids \
	--force --detect-shared-borders --coalesce-smallest-as-needed -L precincts:$< -o $@

input/precincts.geojson: input/chicago-precincts.geojson input/cook-precincts.geojson
	mapshaper -i $^ combine-files -merge-layers -simplify -o $@

input/chicago-precincts.geojson: input/chicago-wards.geojson
	wget -qO - https://raw.githubusercontent.com/datamade/chicago-municipal-elections/master/precincts/2019_precincts.geojson | \
	pipenv run python scripts/create_geojson_id.py | \
	mapshaper -i - \
	-clip $< \
	-each 'TOWNSHIP="Chicago"' \
	-each 'WARD = WARD.toString()' \
	-each 'PRECINCT = PRECINCT.toString()' \
	-o $@

input/cook-precincts.geojson: input/raw-cook-precincts.geojson
	mapshaper -i $< \
	-each 'id = NAME + " " + Num' \
	-filter-fields id,NAME,Num \
	-rename-fields TOWNSHIP=NAME,PRECINCT=Num \
	-each 'WARD = ""' \
	-o $@

input/chicago-wards.geojson:
	wget -O $@ 'https://data.cityofchicago.org/api/geospatial/sp34-6z76?method=export&format=GeoJSON'
