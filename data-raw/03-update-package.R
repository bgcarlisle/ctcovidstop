library(tidyverse)
library(testthat)

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

## Then for each of those files, we read them in and append a column
## with the search date
for (trials_file in trials_files) {
    newrows <- read_csv(
        paste0("data-raw/", trials_file), col_types="cDcDcc") %>%
        mutate(search_date=as.Date(substr(trials_file, 0, 10)))

    ## Check that there are no duplicate downloaded trial data
    test_that(
        "No duplicate trial downloads",
        {
            expect_equal(
                sum(duplicated(newrows$nctid)),
                0
            )
        }
    )

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

## Check that there are no ratings for un-stopped trials
test_that(
    "There are no ratings for un-stopped trials",
    {
        rated_but_not_stopped <- trials %>%
            filter(is.na(stop_date)) %>%
            filter(nctid %in% ratings$nctid)
        expect_equal(
            nrow(rated_but_not_stopped),
            0
        )
    }
)

## Remove the trials that did not stop within the timeframe of
## interest and join the ratings to the trials
c19stoppedtrials <- trials %>%
    filter(! is.na(stop_date)) %>%
    left_join(ratings)

## Now we do a few basic tests for data integrity

## Check that there are no duplicate ratings
test_that(
    "There are no duplicate ratings",
    {
        expect_equal(
            sum(duplicated(ratings$nctid)),
            0
        )
    }
)

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

message(
    paste0(
        "Don't forget to indicate the latest search date in ",
        "`README.md` and `R/ctcovidstop-package.R`; then update the ",
        "search date and the number of rows in the data set in ",
        "`R/c19stoppedtrials.R` to ", nrow(c19stoppedtrials),
        ", then `document()`, `check()`, increment the version ",
        "number in `DESCRIPTION` and then update through git!"
    )
)
