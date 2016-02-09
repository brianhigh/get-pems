#!/bin/bash

# This is a prototype to use for working out the method of retrieving data
# from the State of California PeMS website.
#
# Copyright Brian High (https://github.com/brianhigh) and Surakshya Dhakal
# License: GNU GPL v3 http://www.gnu.org/licenses/gpl.txt

# Configure
DATA='data'

USERNAME='nobody@example.com'
PASSWORD='s3kr!t'
BASEURL='http://pems.dot.ca.gov'
USERAGENT='Mozilla/5.0'
COOKIES='cookies.txt'

FORM='1'
NODE='Freeway'
CONTENT='detector_health'
EXPORT='text'
PAGE="report_form=${FORM}&dnode=${NODE}&content=${CONTENT}&export=${EXPORT}"

FWY='1'
DIR='N'
ROAD="fwy=${FWY}&dir=${DIR}"

MONTH='02'
DAY='05'
YEAR='2016'
DATE="${MONTH}%2F${DAY}%2F${YEAR}"

# Remove old cookie file
rm -f "$COOKIES"

# Create data directory
mkdir -p "$DATA"

# Visit home page to get cookie
curl -o "${DATA}/freeways_and_forms.html" \
    "$BASEURL" -c "$COOKIES" -A "$USERAGENT" \
    --data "redirect=&username=$USERNAME&password=$PASSWORD&login=Login"

# Visit the main detector_health page for chosen freeway to get the s_time_id
curl -o "${DATA}/${NODE}_${CONTENT}_${FWY}_${DIR}.html" -b cookies.txt \
    -A "Mozilla/5.0" "$BASEURL/?dnode=${NODE}&content=${CONTENT}&${ROAD}"

# Extract the s_time_id from HTML using a regular expression
UDATE=$(perl -wnl -e 's/name="s_time_id" value="(\d+)"/$1/g and print "$1"' \
    "${DATA}/${NODE}_${CONTENT}_${FWY}_${DIR}.html")

# Set query-string defaults
DEF='eqpo=&tag=&st_cd=on&st_ch=on&st_ff=on&st_hv=on&st_ml=on&st_fr=on&st_or=on'

# Get the TSV file for the detector_health for chosen freeway and date
curl -o "${DATA}/${NODE}_${CONTENT}_${FWY}_${DIR}_${YEAR}${MONTH}${DAY}.tsv" \
    -b "$COOKIES" -A "$USERAGENT" \
    "${BASEURL}/?${PAGE}&${ROAD}&s_time_id=${UDATE}&s_time_id_f=${DATE}&${DEF}"
