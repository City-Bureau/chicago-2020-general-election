S3_BUCKET = city-bureau-projects
RACES_251 = $(shell cat input/results-metadata.json | jq -r '.["251"].races | keys[]' | xargs -I {} echo "output/results/251/{}.csv")

.PHONY: data
data: $(RACES_251) output/tiles/precincts/

.PHONY: all
all: input/results-metadata.json

.PRECIOUS: input/251/%.html

.PHONY: deploy
deploy:
	aws s3 cp ./output/tiles s3://$(S3_BUCKET)/chicago-2020-general-election/tiles/ --recursive --acl=public-read --content-encoding=gzip --region=us-east-1
	aws s3 cp ./output/results s3://$(S3_BUCKET)/chicago-2020-general-election/results/ --recursive --acl=public-read --region=us-east-1

output/tiles/precincts/: input/precincts.mbtiles
	mkdir -p output/tiles
	tile-join --no-tile-size-limit --force -e $@ $<

output/results/251/%.csv: input/251/%.html
	mkdir -p $(dir $@)
	pipenv run python scripts/scrape_table.py $< > $@

input/251/%.html:
	mkdir -p $(dir $@)
	curl https://chicagoelections.gov/en/election-results-specifics.asp -X POST -H "Content-Type: application/x-www-form-urlencoded" -d "election=251&race=$*&ward=&precinct=" -o $@

input/251/0.html:
	mkdir -p $(dir $@)
	curl https://chicagoelections.gov/en/election-results-specifics.asp -X POST -H "Content-Type: application/x-www-form-urlencoded" -d "election=251&race=&ward=&precinct=" -o $@

input/results-metadata.json:
	pipenv run python scripts/scrape_results_metadata.py > $@

input/precincts.mbtiles: input/precincts.geojson
	tippecanoe --simplification=10 --simplify-only-low-zooms --maximum-zoom=11 --no-tile-stats --generate-ids \
	--force --detect-shared-borders --coalesce-smallest-as-needed -L precincts:$< -o $@

input/precincts.geojson: input/chi-precincts.geojson input/wards.geojson
	mapshaper -i $< -clip $(filter-out $<,$^) -o $@

input/chi-precincts.geojson: input/raw-chi-precincts.geojson
	cat $< | pipenv run python scripts/create_geojson_id.py > $@

input/raw-chi-precincts.geojson:
	wget -O $@ https://raw.githubusercontent.com/datamade/chicago-municipal-elections/master/precincts/2019_precincts.geojson

input/wards.geojson:
	wget -O $@ 'https://data.cityofchicago.org/api/geospatial/sp34-6z76?method=export&format=GeoJSON'
