library(tidyverse)
library(testthat)
library(lubridate)

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
trials_files <- list.files(
    "data-raw",
    "^[0-9]{4}-[0-9]{2}-[0-9]{2}-trials\\.csv$"
)

## Read in the transformation library for obsolete NCT numbers
obsolete <- read_csv("data-raw/obsolete-nctids.csv")

remove_nctids <- obsolete %>%
    filter(is.na(new)) %>%
    select(old) %>%
    pull()

replace_nctids <- obsolete %>%
    filter(! is.na(new)) %>%
    rename(nctid = old, new_nctid = new)

## Then for each of those files, we read them in and append a column
## with the search date
for (trials_file in trials_files) {
    newrows <- read_csv(
        paste0("data-raw/", trials_file), col_types="cDcDcc") %>%
        mutate(search_date=as.Date(substr(trials_file, 0, 10))) %>%
        filter(! nctid %in% remove_nctids) %>%
        left_join(replace_nctids) %>%
        mutate(
            nctid = ifelse (! is.na(new_nctid), new_nctid, nctid)
        ) %>%
        select(! new_nctid)

    trials <- trials %>%
        bind_rows(newrows)
}

## Then we take out all the rows with duplicate NCT numbers, leaving
## only the row with the latest search date and arrange by stop date:
trials <- trials %>%
    group_by(nctid) %>%
    arrange(search_date) %>%
    slice_tail() %>%
    ungroup() %>%
    select(! search_date) %>%
    arrange(stop_date)

## Read the ratings into memory.
ratings <- tribble(
    ~nctid,
    ~covid19_explicit,
    ~restart_expected
)

## Get all the ratings files
ratings_files <- list.files(
    "data-raw",
    "^[0-9]{4}-[0-9]{2}-[0-9]{2}-ratings\\.csv$"
)

## Then for each of those files, we read them in and select the
## relevant columns and put them together into the same data frame
for (ratings_file in ratings_files) {
    newrows <- read_csv(
        paste0("data-raw/", ratings_file),
        show_col_types = FALSE
    ) %>%
        select(nctid, covid19_explicit, restart_expected)

    ratings <- ratings %>%
        bind_rows(newrows)
}

## Remove the trials that did not stop within the timeframe of
## interest and join the ratings to the trials
c19stoppedtrials <- trials %>%
    filter(! is.na(stop_date)) %>%
    filter(stop_date < as.Date("2022-12-01")) %>%
    left_join(ratings)

## Check that all the trials that have been changed between 2019-12-01
## and 2022-12-01 were downloaded
dateofinterest <- as.Date("2019-12-01")
dateoflastupdate <- as.Date("2022-12-05")

nctids <- c()

batch_lb <- dateofinterest
batch_size <- days(7)

while (batch_lb < dateoflastupdate) {

    batch_ub <- batch_lb + batch_size - days(1)

    if (batch_ub > dateoflastupdate) {
        batch_ub <- dateoflastupdate
    }

    message(
        paste(
            "Downloading NCTs modified between",
            batch_lb, "and", batch_ub
        )
    )

    batch <- paste0(
        "https://clinicaltrials.gov/ct2/results/",
        "download_fields?down_count=10000&",
        "down_flds=all&down_fmt=csv&lupd_s=",
        format(batch_lb, "%m"),
        "%2F", format(batch_lb, "%d"),
        "%2F", format(batch_lb, "%Y"),
        "&lupd_e=", format(batch_ub, "%m"),
        "%2F", format(batch_ub, "%d"),
        "%2F", format(batch_ub, "%Y")) %>%
        read_csv(show_col_types=FALSE) %>%
        select(`NCT Number`) %>%
        pull()

    message(paste(length(batch), "NCTs downloaded"))
    
    if (length(batch) >= 10000) {
        message("WARNING: You need smaller batches")
    }
        
    nctids <- c(
        nctids,
        batch
    )
    
    batch_lb <- batch_lb + days(7)
    
}

test_that(
    "All changed trials have been checked",
    {
        all_changed_trials <- tibble(nctids) %>%
            mutate(checked = nctids %in% trials$nctid) %>%
            filter(! checked) %>%
            select (! checked)
        
        expect_equal(
            nrow(all_changed_trials),
            0
        )
    }
)

test_that(
    "All analyzed trials appear in the set of changed trials",
    {        
        analyzed_trials_not_in_changed <- trials %>%
            mutate(in_changed = nctid %in% nctids) %>%
            filter(! in_changed)
        
        expect_equal(
            nrow(analyzed_trials_not_in_changed),
            0
        )
    }
)

## All trials that were changed between 2019-12-01 and 2022-11-30 but
## didn't stop
c19nonstoppedtrials <- trials %>%
    filter(is.na(stop_date)) %>%
    select(nctid) %>%
    sample_n(10)

c19stoppedtrials %>%
    sample_n(10)
