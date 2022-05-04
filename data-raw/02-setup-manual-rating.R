## This script checks the downloaded trials for ones that stopped and
## adds them to the ratings file to be manually curated

## This script can be run while `01-download-trials.R` is running and
## it will provide feedback on its progress

suppressMessages(library(tidyverse))

## The ratings file will be given the same date as the latest of the
## changed NCT numbers files
nctid_files <- list.files(
    "data-raw",
    "^[0-9]{4}-[0-9]{2}-[0-9]{2}-changed-nctids\\.csv$"
)
current_update <- nctid_files[length(nctid_files)] %>%
    substr(0, 10)

## Read the trials into memory. We want the most up-to-date search
## result for each NCT number and there may/should be duplicates in
## later updated searches, so we need to paste together all the trials
## CSV's. First we make an empty data frame for the trials:
trials <- tribble(
    ~nctid,
    ~stop_date,
    ~stop_status,
    ~restart_date,
    ~restart_status,
    ~why_stopped,
    ~search_date
)

## Then we read in all the files that match the pattern:
## "YYYY-MM-DD-trials.csv":
trials_files <- list.files(
    "data-raw",
    "^[0-9]{4}-[0-9]{2}-[0-9]{2}-trials\\.csv$"
)

## Then for each of those files, we read them in, add them to the data
## frame we made earlier and append a column with the search date
for (trials_file in trials_files) {
    newrows <- read_csv(
        paste0("data-raw/", trials_file), col_types="cDcDcc"
    ) %>%
        mutate(search_date=as.Date(substr(trials_file, 0, 10)))

    trials <- trials %>%
        bind_rows(newrows)
}

## Then we take out all the rows with duplicate NCT numbers, leaving
## only the row with the latest search date
trials <- trials %>%
    group_by(nctid) %>%
    arrange(search_date) %>%
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

## There are many ratings files, so we should put them all together.
## List all the files that match the pattern: "YYYY-MM-DD-ratings.csv"
ratings_files <- list.files(
    "data-raw",
    "^[0-9]{4}-[0-9]{2}-[0-9]{2}-ratings\\.csv$"
)

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

## Remove trials that did not stop during Covid-19
trials <- trials %>%
    filter(! is.na(stop_date))

## Make a ratings file for the current update if it does not exist
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

## Find the stopped trials from the trials download file that are not
## yet rated manually and write them to the end of the ratings file
## with NA's for the columns that are to be manually rated
trials %>%
    filter(! nctid %in% ratings$nctid) %>%
    select(nctid, why_stopped) %>%
    mutate(covid19_explicit = NA) %>%
    mutate(restart_expected = NA) %>%
    write_csv(
        paste0("data-raw/", current_update, "-ratings.csv"),
        append=TRUE
    )

## Count the number that have been added to the ratings file
newly_added <- trials %>%
    filter(! nctid %in% ratings$nctid) %>%
    nrow()

## Count the number of ratings that are not done yet (these would be
## generated if the script was run previously and the ratings weren't
## completed before running it again)
unrated_rows <- ratings %>%
    filter(is.na(covid19_explicit)) %>%
    nrow()

## Alert the user if there are new ratings to do
if (newly_added > 0 | unrated_rows > 0) {
    message(
        paste(
            "New rows have been added to",
            "data-raw/", current_update, "-ratings.csv",
            "that you can rate"
        )
    )
} else {
    message("No new rows have been added")
}

## Give some feedback regarding the state of the trial downloading
## script
message(
    paste0(
        "Processed trials: ", processed, "; stopped: ", nrow(trials)
    )
)
