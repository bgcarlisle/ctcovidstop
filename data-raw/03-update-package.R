suppressMessages(library(tidyverse))
suppressMessages(library(testthat))

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

    message(trials_file)
    
    newrows <- read_csv(
        paste0("data-raw/", trials_file), col_types="cDcDcc") %>%
        mutate(search_date=as.Date(substr(trials_file, 0, 10))) %>%
        filter(! nctid %in% remove_nctids) %>%
        left_join(replace_nctids) %>%
        mutate(
            nctid = ifelse (! is.na(new_nctid), new_nctid, nctid)
        )

    ## Check that there are no duplicate downloaded trial data
    test_that(
        "No duplicate trial downloads",
        {
            expect_equal(
                sum(duplicated(paste(
                    newrows$nctid, newrows$new_nctid
                ))),
                0
            )
        }
    )

    newrows <- newrows %>%
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

## Check that there are no ratings for trials that are not downloaded
test_that(
    "There are no ratings for non-downloaded trials",
    {
        rated_but_not_downloaded <- ratings %>%
            filter(! nctid %in% trials$nctid)
        expect_equal(
            nrow(rated_but_not_downloaded),
            0
        )
    }
)

## Check that there are no ratings for trials that did not stop within
## our timeframe of interest
test_that(
    "There are no non-stopped trials that have ratings",
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
    filter(stop_date < as.Date("2022-12-01")) %>%
    left_join(ratings)

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

## Check that all ratings are complete
test_that(
    "All ratings for Covid-19 stoppage are complete",
    {
        expect_equal(
            sum(is.na(ratings$covid19_explicit)),
            0
        )
    }
)

## Check that if a Covid-19 stoppage was found, the trial was also
## assessed for whether a restart is expected
test_that(
    "If stopped for Covid-19, checked for an expected restart",
    {
        c19explicit_but_not_checked_for_restart <-
            c19stoppedtrials %>%
            filter(covid19_explicit) %>%
            filter(is.na(restart_expected)) %>%
            nrow()
        expect_equal(
            c19explicit_but_not_checked_for_restart,
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

## Give instructions to the user to update the rest of the package to
## reflect these changes
message(
    paste0(
        "Don't forget to indicate the latest search date (",
        substr(trials_files[length(trials_files)], 0, 10),
        ") in `README.md`, `R/ctcovidstop-package.R` and ",
        "`R/c19stoppedtrials.R`; also update the number of rows in ",
        "the data set in `R/c19stoppedtrials.R` to ",
        nrow(c19stoppedtrials),
        ", then increment the version number in `DESCRIPTION`, run ",
        "`devtools::document()`, `devtools::check()`, and then ",
        "update through git!"
    )
)
