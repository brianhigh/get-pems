# Retrieve freeway detector data from the State of California PeMS website.
#
# * Looks up detector health data for a set of days and a set of freeways.
# * Please configure as needed. See the "Configuration" section for details.
#
# Copyright Brian High (https://github.com/brianhigh) and Surakshya Dhakal
# License: GNU GPL v3 http://www.gnu.org/licenses/gpl.txt

# Close connections and clear objects.
closeAllConnections()
rm(list=ls())

# Install packages and load into memory.
for (pkg in c("RCurl", "XML", "plyr")) {
    if(pkg %in% rownames(installed.packages()) == FALSE) {
        install.packages(pkg, quiet = TRUE, 
                         repos="http://cran.fhcrc.org",
                         dependencies=TRUE)
    }
    suppressWarnings(suppressPackageStartupMessages(
        require(pkg, character.only = TRUE, quietly = TRUE)))
}

# --------------------------------------------------------------------------
# Configuration
# --------------------------------------------------------------------------

# Data folder configuration - where the data files are to be stored
data.folder <- 'data'

# Session configuration - variables used to set up the HTTP session
# You should only need to change the first two (username and password).
username <- 'nobody@example.com'
password <- 's3kr!t'
base.url <- 'http://pems.dot.ca.gov'
user.agent <- 'Mozilla/5.0'         # https://en.wikipedia.org/wiki/User_agent
cookies <- 'cookies.txt'            # https://en.wikipedia.org/wiki/HTTP_cookie

# Lanes configuration - specific freeway and direction to query
# - Freeway-lane entries must be listed as one entry per line
# - Entries much match this "regex": ^(?:I|SR|US)\\d+[NSEW]?-[NSEW]{1}$
# - Where ^(?:I|SR|US) means: starts with I or SR or US
# - And \\d+[NSEW]?- means:
#   - one or more digits 
#   - *optionally* followed by a single N or S or E or W
#   - followed by a single dash
# - And [NSEW]{1}$ means: ends with a single N or S or E or W
# - Example: SR24-W
# - Example: I880S-S
freeways.of.interest.file <- "freeways_of_interest.txt"

# Start date configuration - a vector of a single date or multiple dates
# - query date(s) must be in ISO 8601 form: YYYY-MM-DD
# - See: https://en.wikipedia.org/wiki/ISO_8601
# - Dates much match this "regex": '^\\d{4}-\\d{2}-\\d{2}$'
# - Where this means: four digits, a dash, two digits, a dash, and two digits
# Examples:
# search.date <- c('2016-02-05')
# search.date <- c('2016-02-05', '2016-02-06', '2016-02-07')
# search.date <- seq(as.Date("2015-01-01"), as.Date("2015-12-31"), "days")
search.date <- seq(as.Date("2015-01-01"), as.Date("2015-01-03"), "days")

# Read in configuration file. This file can contain the settings listed above.
if (file.exists("conf.R")) source("conf.R")

# --------------------------------------------------------------------------
# Functions
# --------------------------------------------------------------------------

## Function getDetectorHealthPage will fetch a freeway's detector health page
getDetectorHealthPage <- function(freeway, direction, search.date.str, 
                                  s.time.id, curl, base.url, data.folder) {
    # Combine variables into a "lane" string
    lane <- paste('fwy=', freeway, '&dir=', direction, sep='')
    
    # Parse the search.date.str into a vector
    search.date.v <- unlist(strsplit(search.date.str, '-'))
    names(search.date.v) <- c("year", "month", "day")
    
    # Combine variables into a "start date" (sdate) string
    sdate <- paste(search.date.v[['month']], 
                   search.date.v[['day']], 
                   search.date.v[['year']], 
                   sep='%2F')
    
    # Combine variables into a "file date" (fdate) string
    fdate <- paste(search.date.v[['year']], 
                   search.date.v[['month']], 
                   search.date.v[['day']], 
                   sep='')
    
    # Page configuration - query specification for type of report page
    form.num <- '1'
    node.name <- 'Freeway'
    content <- 'detector_health'
    export.type <- 'text'
    
    # Combine variables into a "page" (page) string
    page <- paste('report_form=', form.num, '&dnode=', node.name, '&content=', 
                  content, '&export=', export.type, sep='')

    # Combine variables into a "output filename" (output.filename) string
    output.filename <- paste(data.folder, '/', node.name, '-', 
                             content, '-', freeway, '-', direction, '-', fdate, 
                             '.tsv', sep='')
    
    # If the data filehas alread been saved, load the file, or get from web
    if (! file.exists(output.filename)) {
        tryCatch({
            # Get TSV file for the detector_health for chosen freeway and date
            r.url <- paste(base.url, '/?', page, '&', lane, '&s_time_id=', 
                         s.time.id, '&s_time_id_f=', sdate, sep='')
            
            # Get TSV data file from website and store as a string in memory
            r = dynCurlReader()
            result.string <- getURL(url = r.url, curl = curl)
            
            # Write string to file
            writeLines(result.string, output.filename)
            
            # Read table from string into a dataframe
            health <- read.table(text=result.string, sep='\t', header=T, 
                                 fill=T, quote='', stringsAsFactors=F)
            }, error=function(e) {
                cat("ERROR :",conditionMessage(e), "\n")
                return(data.frame(NULL))
            })
    } else {
        # Read from file
        health <- read.table(output.filename, sep='\t', header=T, fill=T, 
                             quote='', stringsAsFactors=F)
    }
    
    # Add variables to make this dataset unique from others and return
    if (nrow(health) > 0) health$search.date <- as.Date(search.date.str)
    return(health)

}

## Function getDetectorHealth will fetch the detector health for each freeway
#  In the dataframe freeways
getDetectorHealth <- function(freeways, search.date.str, curl,
                              base.url, data.folder) {
    cat("Trying ", search.date.str, "...", "\n")
    
    # Calculate s_time_id (Unix time integer) from search.date.str
    s.time.id <- as.character(as.integer(as.POSIXct(search.date.str, 
                                                    origin="1970-01-01",
                                                    tz = "GMT")))
    
    detector.health <- adply(.data=freeways, .margins=c(1), 
                             .fun=function(x) getDetectorHealthPage(
                                 x$freeway, x$direction, search.date.str, 
                                 s.time.id, curl, base.url, data.folder))
}

## Function subsetFreeways will subset freeways by those of interest
subsetFreeways <- function(freeways, freeways.of.interest.file) {
    # If there is a freeways_of_interest file, subset freeways by its contents.
    if (file.exists(freeways.of.interest.file)) {
        freeways.of.interest <- readLines(freeways.of.interest.file)

        # Remove quotation marks, if present
        freeways.of.interest <- gsub('["\\\']', '', freeways.of.interest)
        
        # Remove any which do not match the required format
        freeways.of.interest <- freeways.of.interest[
            grep('^(?:I|SR|US)\\d+[NSEW]?-[NSEW]{1}$', freeways.of.interest)]
        
        # Convert to dataframe and merge with "freeways" to perform subset
        freeways.of.interest <- data.frame(name=freeways.of.interest, 
                                           stringsAsFactors=F)
        freeways <- merge(freeways, freeways.of.interest, by = "name")
    }
    return(freeways)
}

## Function getSTimeId() finds the "s_time_id" value in an HTML document.
# Note: You could also extract available cities and counties with this method.
getSTimeId <- function(doc) {
    optValues <- xpathSApply(
        htmlParse(doc), 
        paste('//form[@name="rpt_vars"]/table[@id="bts_report_controls"]', 
              '/tr/td/input[@id="s_time_id"]', sep=''), 
        function(x) xmlAttrs(x)["value"]
    )
    
    return(optValues[[1]])
}

## Function getFreeways() finds "freeway" choices in HTML select option tags.
# Note: You could also extract available cities and counties with this method.
getFreeways <- function(doc) {
    optValues <- xpathSApply(htmlParse(doc), 
                        '//form[@class="crossNav"]/select[@name="url"]/option', 
                        function(x) paste(xmlAttrs(x)["value"], 
                                               '&name=', xmlValue(x), sep=''))
    freeways <- optValues[grepl('dnode=Freeway', optValues)]
    freeways <- strsplit(gsub("[^&]*=", "", freeways), '&')
    freeways <- adply(.data=unname(freeways), .margins=c(1))
    freeways <- freeways[, c(3:5)]
    names(freeways) <- c("freeway", "direction", "name")
    return(freeways)
}

# --------------------------------------------------------------------------
# Main routine
# --------------------------------------------------------------------------

# Create the data folder if needed.
dir.create(file.path(data.folder), showWarnings = FALSE, recursive = TRUE)

# Load homepage, get a cookie, and parse output for a dataframe of freeways.
# From this dataframe, we can look-up the freeway number and lane directions.
# We can loop-through this dataframe (or a subset) to process many freeways.
formdata <- paste('redirect=&username=', username, '&password=', password, 
                  '&login=Login', sep='')

# Configure curl to use a cookie file and a custom user agent string.
curl <- getCurlHandle(cookiefile = cookies, cookiejar = cookies,
                      useragent = user.agent)

# Load the page into R as a string.
r = dynCurlReader()
res <- curlPerform(postfields = formdata, url = base.url, curl = curl,
                   post = 1L, writefunction = r$update)
result.string <- r$value() 

# Parse the page to get freeway data and write to a CSV file.
freeways <- getFreeways(result.string)
write.csv(freeways, paste(data.folder, "freeways.csv", sep="/"), row.names=F)

# Select only those freeways which are of interest to us.
freeways <- subsetFreeways(freeways, freeways.of.interest.file)

# Get detector health for each date and freeway and write to a CSV file.
search.date <- as.character(search.date)
search.date <- search.date[grep('^\\d{4}-\\d{2}-\\d{2}$', search.date)]
detector.health <- adply(.data=search.date, .margins=c(1), 
                         .fun=function(x) getDetectorHealth(freeways, x, curl,
                                                            base.url, 
                                                            data.folder))
# Remove extra variables.
detector.health$X1 <- NULL
detector.health$name <- NULL

# Save dataframe as CSV.
write.csv(detector.health, paste(data.folder, "detector_health.csv", sep="/"), 
          row.names=F)

# Clean up. Cookies file will be written to disk. Memory will be freed.
rm(curl)
gc()
