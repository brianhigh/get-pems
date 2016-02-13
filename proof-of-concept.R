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
freeway <- '1'
direction <- 'N'

# Start date configuration - date for (beginning of) query (date or range)
mm.str <- '02'
dd.str <- '05'
yyyy.str <- '2016'

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
# Main routine
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
write.csv(freeways, paste(data.folder, "freeways.csv", sep="/"), row.names=F)

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
           paste(data.folder, '/', node.name, '-', content, '-', freeway, '-', 
                 direction, '-', yyyy.str, mm.str, dd.str, '.tsv', sep=""))

# Clean up.
rm(curl)
gc()
