library(tidyverse)
library(testthat)
library(lubridate)

## Read the comparator data from disk
comparator <- read_csv("data-raw/2023-01-13-comparator-trials.csv")
comparator_nctids <- read_csv(
    "data-raw/2023-01-13-comparator-nctids.csv"
)

## Test that
test_that(
    "Same number of NCTs in the results as the list to be downloaded",
    {
        distinct_nctids_downloaded <- comparator %>%
            distinct(nctid)
        expect_equal(
            nrow(distinct_nctids_downloaded),
            nrow(comparator_nctids)
        )
    }
)

test_that(
    "There are no NCTs missing in the downloaded results",
    {
        expect_equal(
            sum(comparator$nctid %in% comparator_nctids$nctids),
            nrow(comparator)
        )
    }
)

test_that(
    "There are no NCTs missing in the file of NCTs to download",
    {
        expect_equal(
            sum(comparator_nctids$nctids %in% comparator$nctid),
            nrow(comparator_nctids)
        )
    }
)

## The previous step downloaded all the trials that have been modified
## in any way since 2016-12-01, which will include trials that stopped
## outside our date range of interest; this will remove them and put
## them in order
comparator <- comparator %>%
    filter(! is.na(stop_date)) %>%
    filter(stop_date >= as.Date("2016-12-01")) %>%
    filter(stop_date <= as.Date("2019-11-30")) %>%
    arrange(stop_date)

## Write data set to a CSV in the inst/extdata/ folder
if (! file.exists("inst/")) {
    dir.create("inst/")
}
if (! file.exists("inst/extdata/")) {
    dir.create("inst/extdata/")
}
comparator %>%
    write_csv("inst/extdata/comparator.csv")

## Write data set to a .dba file in the data/ folder
usethis::use_data(comparator, overwrite = TRUE)
