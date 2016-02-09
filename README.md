# get-pems

## Description

Getting data from the State of California PeMS website using RCurl.

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

## Methods

A "proof of concept" script written in Bash is used to test the use of cURL
for programatically retrieving the data from the website.

Such an approach is needed because the website interface would otherwise
require an inordinate amount of tedious clicking to retrieve data for
many freeways, senssors, and dates. Additionally, one would then have to 
combine multiple files to produce the desired dataset, adding extra columns
to capture the query values along the way. 

The intent is to automate all of this work through the use of an R script. The
cURL commands from the Bash script will be recoding in R using RCurl.
