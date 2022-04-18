suppressMessages(library(tidyverse))
suppressMessages(library(testthat))

## Read the trials into memory
trials <- read_csv("data-raw/2022-04-13-trials.csv", col_types="cDcDcc")

## Get number of trials processed
processed <- nrow(trials)


## Get the already-done manual ratings using the following query:

## SELECT `nct_id` as `nctid`, `covid19_explicit`, `restartexpected`
## as `restart_expected` FROM `trials` WHERE `include` = 1;

## Clean the CSV up a bit, save it as webapp-ratings.csv, then read
## that into memory:

ratings <- read_csv(
    "data-raw/2021-10-21-ratings.csv",
    show_col_types=FALSE
)

## The following is commented out because we only needed to test this
## once

## test_that(
##     "Only C19-explicit trials were rated for expecting restart",
##     {
##         rated_non_c19 <- ratings %>%
##             filter(! covid19_explicit) %>%
##             filter(! is.na(restart_expected)) %>%
##             nrow()
##         expect_equal(
##             rated_non_c19,
##             0
##         )
##     }
## )

additional_ratings <- read_csv(
    "data-raw/2022-04-18-ratings.csv",
    show_col_types=FALSE
)

test_that(
    "Only C19-explicit trials were rated for expecting restart",
    {
        rated_non_c19 <- additional_ratings %>%
            filter(! covid19_explicit) %>%
            filter(! is.na(restart_expected)) %>%
            nrow()
        expect_equal(
            rated_non_c19,
            0
        )
    }
)

## Check that there aren't any major fuckups

## trials %>%
##     filter(is.na(stop_date)) %>%
##     filter(nctid %in% ratings$nctid)

## Remove trials that did not stop during Covid-19
trials <- trials %>%
    filter(! is.na(stop_date)) ## %>%
    ## arrange(desc(stop_date))


## What trials are not rated manually?
trials %>%
    filter(! nctid %in% ratings$nctid) %>%
    filter(! nctid %in% additional_ratings$nctid) %>%
    select(nctid, why_stopped) %>%
    mutate(covid19_explicit = NA) %>%
    mutate(restart_expected = NA) %>%
    write_csv("data-raw/2022-04-18-ratings.csv", append=TRUE)

test_that(
    "No new rows have been added (nothing to do!)",
    {
        newlyadded <- trials %>%
            filter(! nctid %in% ratings$nctid) %>%
            filter(! nctid %in% additional_ratings$nctid) %>%
            nrow()
        expect_equal(
            newlyadded,
            0
        )
    }
)

test_that(
    "No unrated rows in manual ratings CSV",
    {
        unrated_rows <- additional_ratings %>%
            filter(is.na(covid19_explicit)) %>%
            nrow()
        expect_equal(
            unrated_rows,
            0
        )
    }
)

message(paste0("Processed trials: ", processed, "; stopped: ", nrow(trials)))
