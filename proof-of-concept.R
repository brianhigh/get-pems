# Retrieve freeway sensor data from the State of California PeMS website.
#
# Copyright Brian High (https://github.com/brianhigh) and Surakshya Dhakal
# License: GNU GPL v3 http://www.gnu.org/licenses/gpl.txt

# Close connections and clear objects.
closeAllConnections()
rm(list=ls())

# Load libraries
library(RCurl)
library(XML)
library(plyr)
library(zoo)

# --------------------------------------------------------------------------
# Configuration
# --------------------------------------------------------------------------

# Data folder configuration - where the data files are to be stored
data.folder <- 'data'

# Session configuration - variables used to set up the HTTP session
username <- 'nobody@example.com'
password <- 's3kr!t'
base.url <- 'http://pems.dot.ca.gov'
user.agent <- 'Mozilla/5.0'         # https://en.wikipedia.org/wiki/User_agent
cookies <- 'cookies.txt'            # https://en.wikipedia.org/wiki/HTTP_cookie

# Page configuration - query specification for type of report page
form.num <- '1'
node.name <- 'Freeway'
content <- 'detector_health'
export.type <- 'text'

# Lanes configuration - specific freeway and direction to query
freeway <- '80'
direction <- 'E'

# Start date configuration - date for (beginning of) query (date or range)
mm.str <- '01'
dd.str <- '01'
yyyy.str <- '2015'

# Read in configuration file. This file can contain the settings listed above.
if (file.exists("conf.R")) source("conf.R")

# --------------------------------------------------------------------------

# --------------------------------------------------------------------------
# Functions
# --------------------------------------------------------------------------

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
    names(freeways) <- c("fwy", "dir", "name")
    return(freeways)
}

# --------------------------------------------------------------------------
# Detector health: Data Quality > Detector Health > Lanes
# --------------------------------------------------------------------------

# Create the data folder if needed.
dir.create(file.path(data.folder), showWarnings = FALSE, recursive = TRUE)

# Combine variables into login "form data" (formdata) string
formdata <- paste('redirect=&username=', username, '&password=', password, 
                  '&login=Login', sep='')

# Configure curl to use a cookie file and a custom user agent string.
cookies <- 'cookies.txt'
curl <- getCurlHandle(cookiefile = cookies, cookiejar = cookies,
                      useragent = user.agent)

# Load homepage, get a cookie, and parse output for a dataframe of freeways.
# From this dataframe, we can look-up the freeway number and lane directions.
# We can loop-through this dataframe (or a subset) to process many freeways.
r = dynCurlReader()
res <- curlPerform(postfields = formdata, url = base.url, curl=curl,
                   post = 1L, writefunction = r$update)
result.string <- r$value() 
freeways <- getFreeways(result.string)
write.csv(freeways, file.path(data.folder, "freeways.csv"), row.names=F)

# Calculate s_time_id (Unix time integer) from search.date.str
s.time.id <- as.character(as.integer(
    as.POSIXct(paste(yyyy.str, mm.str, dd.str, sep='-'), 
               origin="1970-01-01", tz = "GMT")))

# Combine variables into a "page" (page) string
page <- paste('report_form=', form.num, '&dnode=', node.name, '&content=', 
              content, '&export=', export.type, sep='')

# Combine variables into a "lane" string
lane <- paste('fwy=',freeway, '&dir=', direction, sep='')

# Combine variables into a "start date" (sdate) string
sdate <- paste(mm.str, dd.str, yyyy.str, sep='%2F')

# Get the TSV file for the detector_health for chosen freeway and date
r.url <- paste(base.url, '/?', page, '&', lane, '&s_time_id=', s.time.id, 
             '&s_time_id_f=', sdate, sep='')
r = dynCurlReader()
result.string <- getURL(url = r.url, curl = curl)
writeLines(result.string, 
           file.path(data.folder, 
                     paste0(node.name, '-', content, '-', freeway, '-', 
                            direction, '-', yyyy.str, mm.str, dd.str, '.tsv')))
freeway.health <- suppressWarnings(read.table(text=result.string, header=TRUE, 
                                              sep='\t', fill=TRUE))

# --------------------------------------------------------------------------
# Detector performance: Performance > Aggregates > Time Series
# --------------------------------------------------------------------------

# Get detector performance for a whole month, given a freeway.

# Page configuration - query specification for type of report page
# (Continued from above...)
node.name <- 'VDS'
content <- 'loops'
form.tab <- 'det_timeseries'

# Lanes configuration - specific freeway and direction to query
freeway <- '80'
direction <- 'E'

# Start date configuration - date for (beginning of) query (date or range)
mm.str <- '01'
yyyy.str <- '2015'

quantities <- c("flow", "occ", "speed", "truck_flow", "truck_prop", "vmt",
                "vht", "q", "truck_vmt","truck_vht")

# Combine variables into a "page" (page) string
page <- paste('report_form=', form.num, '&dnode=', node.name, '&content=', 
              content, '&tab=', form.tab, '&export=', export.type, sep='')

# Combine variables into a "start date" (sdate) and time string
sdate <- as.Date(as.yearmon(paste(yyyy.str, mm.str, sep=''), "%Y%m"))
sdate.str <- as.character(sdate)
sdatetime <- paste(sdate.str, '+00:00', sep='')

# Calculate s_time_id (Unix time integer) from sdate.str
s.time.id <- as.character(as.integer(as.POSIXct(sdate.str, 
                                                origin="1970-01-01", 
                                                tz = "GMT")))

# Combine variables into a "end date" (edate) and time string
edate <- as.Date(as.yearmon(paste(yyyy.str, mm.str, sep=''), "%Y%m"), frac=1)
edate.str <- as.character(edate)
edatetime <- paste(edate.str, '+23:59', sep='')

# Calculate e_time_id (Unix time integer) from edate.str
e.time.id <- as.character(as.integer(as.POSIXct(edate.str, 
                                                origin="1970-01-01", 
                                                tz = "GMT") + 86340))

# Construct string of default data values which do not change with each query.
static.data <- paste('&tod=all&tod_from=0&tod_to=0&dow_0=on&dow_1=on&dow_2=on',
                     '&dow_3=on&dow_4=on&dow_5=on&dow_6=on&holidays=on&q2=',
                     '&gn=hour&agg=on&lane1=on&lane2=on&lane3=on&lane4=on',
                     '&lane5=on&lane6=on&lane7=on&lane8=on', sep='')

get.perf <- function(vds, quantity){
    # Create the data folder if needed.
    my.dir <- file.path(data.folder, 
                        node.name, content, form.tab, vds, quantity)
    dir.create(file.path(my.dir), showWarnings = FALSE, recursive = TRUE)

    # Get the TSV file for the  for chosen VDS, quanitity, and date
    r.url <- paste(base.url, '/?', page, '&', lane, '&s_time_id=', s.time.id, 
                   '&s_time_id_f=', sdatetime, '&e_time_id=', e.time.id, 
                   '&e_time_id_f=', edatetime, '&station_id=', vds, '&q=', 
                   quantity, static.data, sep='')
    r = dynCurlReader()
    result.string <- getURL(url = r.url, curl = curl)
    writeLines(result.string, 
               paste(my.dir, '/', node.name, '-', content, '-', form.tab, '-', 
                     vds, '-', quantity, '-', yyyy.str, mm.str, '.tsv', 
                     sep=""))
    perf <- suppressWarnings(read.table(
        text=result.string, header=TRUE, sep='\t', fill=TRUE, row.names=NULL))
    
    # The columns are off by 1, so shift left by 1. Rename last three columns. 
    n <- length(names(perf))
    names(perf) <- c(names(perf)[c(-1, -(n - 1), -n)], 
                     'agg', 'lane.points', 'observed')

    # Clean up column names
    names(perf) <- gsub("\\.+", '.', names(perf))
    names(perf) <- gsub("\\.$", '', names(perf))
    names(perf) <- gsub("(Lane\\.\\d).*$", '\\1', names(perf))
    
    # Add a column for VDS so we don't lose it when combining results later.
    perf$VDS <- vds
    
    return(perf)
}

# Get performance data for all VDSs and quantities for a freeway and month.
vds.list <- unique(freeway.health$VDS)
df <- unique(data.frame(VDS=rep(vds.list, each=length(quantities)), 
                 quantity=rep(quantities, each=length(vds.list))))
result <- adply(df, 1, function(x) get.perf(x$VDS, x$quantity))
write.csv(result, file.path(data.folder, 'performance.csv'), row.names=FALSE)

# Clean up.
rm(curl)
gc()
