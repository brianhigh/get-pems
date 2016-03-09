# get-pems

## Description

Getting data from the State of California [PeMS](http://pems.dot.ca.gov) 
website using [RCurl](https://cran.r-project.org/web/packages/RCurl/index.html).

## Purpose

This project provides script which automates the download of data from the 
State of California Caltrans PeMS website. The data will be used for
academic research in the field of environmental health.

## Data Source Terms of Use

The [terms of use](http://pems.dot.ca.gov/?dnode=Help&content=help_tou) 
statement on the PeMS website declares:

"In general, information presented on this web site, unless otherwise indicated, 
is considered in the public domain. It may be distributed or copied as permitted 
by law."

The exception is copyrighted material such as photographs, which we will not
be using.

## Method

A "proof of concept" [Bash](https://www.gnu.org/software/bash/) script is used 
to test the use of [cURL](https://curl.haxx.se/) for programatically^1^ 
retrieving the data from the website. 

Such an approach is needed because the website interface would otherwise
require an inordinate amount of tedious clicking to retrieve data for
many freeways, sensors, and dates. Additionally, one would then have to 
combine multiple files to produce the desired dataset, adding extra columns
to capture the query values along the way. 

An [R](https://www.r-project.org/) script was written to automate the collection
of detector health records for a set of dates for a set of freeways. The cURL 
commands from the Bash script were recoded in R using RCurl. The script 
downloads the data from each web query as a TSV file and saves the file. The
data are also compiled into a dataframe and saved as a CSV file. A date column 
is added since the original TSV files do not contain this information.

Regular expressions are used for input data validation. If there is an error
with downloading files, the script can be run again and the previously
downloaded files will be read into R instead of downloading them again.

There is also some error-handling code to allow the script to continue on
some download errors, but this feature has not yet been extensively tested.

## Notes

1. This sort of approach was described in the 
[Web Scraping and Web Services Workshop](http://datascience.ucdavis.edu/NSFWorkshops/WebScraping/ScheduleOutline.html) 
web page (retrieved 2016-03-09). Our scripts were developed independently of 
this resource, however, as we only discovered that document after our scripts 
had already been developed.