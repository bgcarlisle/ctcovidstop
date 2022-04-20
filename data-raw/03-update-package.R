library(tidyverse)

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
## only the row with the latest search date; remove all the trials
## that never stopped and arrange by stop date:
trials <- trials %>%
    group_by(nctid) %>%
    slice_tail() %>%
    ungroup() %>%
    select(! search_date) %>%
    filter(! is.na(stop_date)) %>%
    arrange(stop_date)

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

## Join the ratings to the trials
c19stoppedtrials <- trials %>%
    left_join(ratings)

## Write data set to a CSV in the inst/extdata/ folder
if (! file.exists("inst/")) {
    dir.create("inst/")
}
if (! file.exists("inst/extdata/")) {
    dir.create("inst/extdata/")
}
c19stoppedtrials %>%
    write_csv("inst/extdata/c19stoppedtrials.csv")

## Write data set to a .dba file in the data/ folder
usethis::use_data(c19stoppedtrials, overwrite = TRUE)
