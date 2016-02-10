#!/bin/bash

# This is a prototype to use for working out the method of retrieving data
# from the State of California PeMS website.
#
# Copyright Brian High (https://github.com/brianhigh) and Surakshya Dhakal
# License: GNU GPL v3 http://www.gnu.org/licenses/gpl.txt

# --------------------------------------------------------------------------
# Configuration
# --------------------------------------------------------------------------

# Data folder configuration - where the data files are to be stored
DATA='data'

# Session configuration - variables used to set up the HTTP session
USERNAME='nobody@example.com'
PASSWORD='s3kr!t'
BASEURL='http://pems.dot.ca.gov'
USERAGENT='Mozilla/5.0'          # https://en.wikipedia.org/wiki/User_agent
COOKIES='cookies.txt'            # https://en.wikipedia.org/wiki/HTTP_cookie

# Page configuration - query specification for type of report page
FORM='1'
NODE='Freeway'
CONTENT='detector_health'
EXPORT='text'

# Combine variables into a "page" (PG) string
PG="report_form=${FORM}&dnode=${NODE}&content=${CONTENT}&export=${EXPORT}"

# Lanes configuration - specific freeway and direction to query
FWY='1'
DIR='N'

# Combine variables into a "lanes" (LN) string
LN="fwy=${FWY}&dir=${DIR}"

# Start date configuration - date for (beginning of) query (date or range)
MONTH='02'
DAY='05'
YEAR='2016'

# Combine variables into a "start date" (SDATE) string
SDATE="${MONTH}%2F${DAY}%2F${YEAR}"

# There is no end date in this sample query.

# --------------------------------------------------------------------------

# Remove old cookie file
rm -f "$COOKIES"

# Create data directory
mkdir -p "$DATA"

# Visit home page to get cookie
curl -o "${DATA}/freeways-and-forms.html" \
  "$BASEURL" -c "$COOKIES" -A "$USERAGENT" \
  --data "redirect=&username=${USERNAME}&password=${PASSWORD}&login=Login"

# Find "freeway" choices in HTML select option tags and write to CSV file.
echo '"fwy","dir","name"' > "${DATA}/freeways.csv"  # Write the header first.
perl -wnl -e \
  's/.*\/\?dnode=Freeway\&.*fwy=(.*)\&.*=(.*)">(.*)<.*/$1,$2,$3/g and print' \
  "${DATA}/freeways-and-forms.html" >> "${DATA}/freeways.csv"

# Visit the main detector_health page for chosen freeway to get the s_time_id
curl -o "${DATA}/${NODE}-${CONTENT}-${FWY}-${DIR}.html" -b "$COOKIES" \
  -A "$USERAGENT" "${BASEURL}/?dnode=${NODE}&content=${CONTENT}&${LN}"

# Extract the s_time_id from HTML using a regular expression
UDATE=$(perl -wnl -e 's/name="s_time_id" value="(\d+)"/$1/g and print "$1"' \
  "${DATA}/${NODE}-${CONTENT}-${FWY}-${DIR}.html")

# Get the TSV file for the detector_health for chosen freeway and date
curl -o "${DATA}/${NODE}-${CONTENT}-${FWY}-${DIR}-${YEAR}${MONTH}${DAY}.tsv" \
  -b "$COOKIES" -A "$USERAGENT" \
  "${BASEURL}/?${PG}&${LN}&s_time_id=${UDATE}&s_time_id_f=${SDATE}"
