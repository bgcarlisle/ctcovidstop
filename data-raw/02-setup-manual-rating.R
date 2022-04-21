## This script checks the downloaded trials for ones that stopped 

## This script can be run while `01-download-trials.R` is running and
## nothing bad will happen.

suppressMessages(library(tidyverse))
suppressMessages(library(testthat))

current_update <- as.Date("2022-04-13")

## Read the trials into memory. We want the most up-to-date search
## result for each NCT number, so first we make an empty data frame
## for the trials:
trials <- tribble(
    ~nctid,
    ~stop_date,
    ~stop_status,
    ~restart_date,
    ~restart_status,
    ~why_stopped,
    ~search_date
)

## Then we read in all the files that end with "trials.csv":
trials_files <- list.files("data-raw", "trials\\.csv$")

## Then for each of those files, we read them in and append a column
## with the search date
for (trials_file in trials_files) {
    newrows <- read_csv(paste0("data-raw/", trials_file), col_types="cDcDcc") %>%
        mutate(search_date=as.Date(substr(trials_file, 0, 10)))

    trials <- trials %>%
        bind_rows(newrows)
}

## Then we take out all the rows with duplicate NCT numbers, leaving
## only the row with the latest search date
trials <- trials %>%
    group_by(nctid) %>%
    slice_tail() %>%
    ungroup() %>%
    select(! search_date)

## Get number of trials processed
processed <- nrow(trials)



## Read the ratings into memory.
ratings <- tribble(
    ~nctid,
    ~covid19_explicit,
    ~restart_expected
)

## Get all the ratings files
ratings_files <- list.files("data-raw", "ratings\\.csv$")

## Then for each of those files, we read them in and select the
## relevant columns
for (ratings_file in ratings_files) {
    newrows <- read_csv(
        paste0("data-raw/", ratings_file),
        show_col_types = FALSE
    ) %>%
        select(nctid, covid19_explicit, restart_expected)

    ratings <- ratings %>%
        bind_rows(newrows)
}

## Check that there aren't any major fuckups

## trials %>%
##     filter(is.na(stop_date)) %>%
##     filter(nctid %in% ratings$nctid) %>%
##     select(nctid)

## Remove trials that did not stop during Covid-19
trials <- trials %>%
    filter(! is.na(stop_date))


if (! file.exists(
          paste0("data-raw/", current_update, "-ratings.csv"))
    ) {

    tribble(
        ~nctid,
        ~why_stopped,
        ~covid19_explicit,
        ~restart_expected
    ) %>%
        write_csv(
            paste0("data-raw/", current_update, "-ratings.csv")
        )
    
}

## What trials are not rated manually?
trials %>%
    filter(! nctid %in% ratings$nctid) %>%
    select(nctid, why_stopped) %>%
    mutate(covid19_explicit = NA) %>%
    mutate(restart_expected = NA) %>%
    write_csv(paste0("data-raw/", current_update, "-ratings.csv"), append=TRUE)

newlyadded <- trials %>%
    filter(! nctid %in% ratings$nctid) %>%
    nrow()

if (newlyadded > 0) {
    message("New rows have been added to the ratings CSV (get to work!)")
} else {
    message("No new rows have been added (nothing to do!)")
}

unrated_rows <- ratings %>%
    filter(is.na(covid19_explicit)) %>%
    nrow()

if (unrated_rows > 0) {
    message("There are unrated rows in the ratings CSV (get to work!)")
}

message(paste0("Processed trials: ", processed, "; stopped: ", nrow(trials)))
