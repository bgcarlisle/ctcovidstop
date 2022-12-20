## This script goes through all the trials that have NA for the
## `stop_date` column and double-checks that they actually didn't
## stop. The results of this get written to
## `2022-12-05-final-check-nctids.csv` and
## `2022-12-05-final-check-trials.csv`, and then consolidated into the
## rest of the package as if the check were a regular update done on
## 2022-12-20.

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
trials %>%
    filter(is.na(stop_date)) %>%
    select(nctid) %>%
    write_csv("data-raw/2022-12-05-final-check-nctids.csv")

dateofinterest <- as.Date("2019-12-01")

nctids <- read_csv("data-raw/2022-12-05-final-check-nctids.csv") %>%
        pull()

stoppedstatuses <- c(
    "Terminated",
    "Suspended",
    "Withdrawn"
)

output_filename <- "data-raw/2022-12-05-final-check-trials.csv"

check_for_stop_or_start <- function (
                            nctid,
                            starting_versionno,
                            n_versions,
                            checkstop
                            ) {

    if (starting_versionno > n_versions) {
        return(FALSE)
    }
    
    changed_vdates <- clinicaltrials_gov_dates(nctid, TRUE)

    versions_to_check <- clinicaltrials_gov_dates(nctid) %>%
        tibble::as_tibble() %>%
        rename(version_date = value) %>%
        mutate(version_number = row_number()) %>%
        mutate(
            to_check = (version_date %in% changed_vdates |
                        version_number == starting_versionno) &
                version_number >= starting_versionno
        ) %>%
        filter(to_check) %>%
        select(version_number) %>%
        pull()

    for (vno in versions_to_check) {

        dl_success <- FALSE

        while (! dl_success) {

            version_data <- clinicaltrials_gov_version(nctid, vno)
            message(paste("Downloading version", vno, "of", nctid))

            if (version_data[1] != "Error") {
                dl_success <- TRUE
            }
            
        }
        
        if (checkstop) {
            ## We're checking to see when it stopped
            return_condition <-
                trimws(version_data$ostatus) %in% stoppedstatuses
        } else {
            ## We're checking to see when it's not stopped
            return_condition <-
                ! trimws(version_data$ostatus) %in% stoppedstatuses
            
        }

        if (return_condition) {

            return(
                c(
                    version_data,
                    version_number = vno
                )
            )
            
        }

        if (vno == n_versions) {

            return (FALSE)
            
        }
        
    }
    
}

# Here starts the trial data download loop *****

if (! file.exists(output_filename)) {

    alreadydone <- tribble(~nctid)

    tibble(
        nctid = character(),
        stop_date = character(),
        stop_status = character(),
        restart_date = character(),
        restart_status = character(),
        why_stopped = character()
    ) %>%
        write_csv(output_filename)

} else {
    alreadydone <- read_csv(output_filename, show_col_types=FALSE)
}

## Loop through NCT ids
for (nctid in nctids) {

    if (! nctid %in% alreadydone$nctid) {
        
        ## Clear variables from last loop just in case
        stopdate <- NA
        stopstatus <- NA
        restartdate <- NA
        restartstatus <- NA
        whystopped <- NA

        dl_success <- FALSE

        while(! dl_success) {
            ## Download the dates for this NCT id
            dates <- clinicaltrials_gov_dates(nctid)
            message(nctid)

            if (dates[1] != "Error") {
                dl_success <- TRUE
            }
        }

        ## Make a data frame that matches the version number to the
        ## date
        dates <- tibble(
            version_date = as.Date(dates),
            versionno = seq(1:length(dates))
        )

        ## Make a data frame including only the dates that were before
        ## the date of interest
        versions_before_date_of_interest <- dates %>%
            filter(version_date <= dateofinterest)

        if (nrow(versions_before_date_of_interest) > 0) {
            ## There are versions posted before the date of interest,
            ## so we need to check that the trial wasn't already
            ## stopped before Covid

            ## Get the version number for the last version posted
            ## before the date of interest
            versionno_before_date_of_interest <- dates %>%
                filter(version_date <= dateofinterest) %>%
                slice_tail() %>%
                select(versionno) %>%
                pull()


            dl_success <- FALSE
            while (! dl_success) {
                
                message(
                    paste(
                        "Downloading version",
                        versionno_before_date_of_interest, "of", nctid
                    )
                )
                version_before_date_of_interest <-
                    clinicaltrials_gov_version(
                        nctid,
                        versionno_before_date_of_interest
                    )

                if (version_before_date_of_interest[1] != "Error") {
                    dl_success <- TRUE
                }
                
            }

            version_before_date_of_interest_not_stopped <-
! trimws(version_before_date_of_interest$ostatus) %in% stoppedstatuses

            if (version_before_date_of_interest_not_stopped) {
                ## The version immediately before the date of interest
                ## was not stopped, so if it stopped, it happened
                ## during the pandemic

                ## Loop through the remaining versions and check
                ## whether it stopped during the pandemic

                trial_stopped <- check_for_stop_or_start (
                    nctid,
                    versionno_before_date_of_interest + 1,
                    nrow(dates),
                    TRUE
                )

                if (is.list(trial_stopped)) {
                    ## The trial stopped after the date of interest
                    stopdate <-
                      dates$version_date[trial_stopped$version_number]
                    stopstatus <- trial_stopped$ostatus
                    whystopped <- trial_stopped$whystopped

                    ## See if it started again
                    trial_restarted <- check_for_stop_or_start (
                        nctid,
                        trial_stopped$version_number + 1,
                        nrow(dates),
                        FALSE
                    )
                    
                    if (is.list(trial_restarted)) {
                        restartdate <-
                    dates$version_date[trial_restarted$version_number]
                        restartstatus <- trial_restarted$ostatus
                        
                    } else {
                        restartdate <- NA
                        restartstatus <- NA
                    }
                    
                } else {
                    ## The trial never stopped after the date of
                    ## interest
                    stopdate <- NA
                    stopstatus <- NA
                    restartdate <- NA
                    restartstatus <- NA
                    whystopped <- NA  
                }
                
            } else {
                ## The version immediately before the date of interest
                ## was stopped, so we have to check whether it started
                ## and then stopped again during the pandemic

                trial_started <- check_for_stop_or_start (
                    nctid,
                    versionno_before_date_of_interest + 1,
                    nrow(dates),
                    FALSE
                )

                if (is.list(trial_started)) {
                    ## The trial started after the date of interest,
                    ## so we have to check whether it stopped during
                    ## the pandemic

                    trial_stopped <- check_for_stop_or_start (
                        nctid,
                        trial_started$version_number + 1,
                        nrow(dates),
                        TRUE
                    )

                    if (is.list(trial_stopped)) {
                        ## The trial started after the date of
                        ## interest, but later stopped again
                        stopdate <-
                      dates$version_date[trial_stopped$version_number]
                        stopstatus <- trial_stopped$ostatus
                        whystopped <- trial_stopped$whystopped

                        ## Finally, check whether the trial started
                        ## again
                        trial_restarted <- check_for_stop_or_start (
                            nctid,
                            trial_stopped$version_number + 1,
                            nrow(dates),
                            FALSE
                        )

                        if (is.list(trial_restarted)) {
                            ## The trial restarted
                            restartdate <-
                    dates$version_date[trial_restarted$version_number]
                            restartstatus <- trial_restarted$ostatus
                            
                        } else {
                            ## The trial never restarted
                            restartdate <- NA
                            restartstatus <- NA
                        }
                        
                    } else {
                        ## The trial started after the date of
                        ## interest, and never stopped again
                        stopdate <- NA
                        stopstatus <- NA
                        restartdate <- NA
                        restartstatus <- NA
                        whystopped <- NA                        
                    }

                } else {
                    ## The trial was stopped before the date of
                    ## interest and never started, so it couldn't have
                    ## stopped during our timeframe
                    stopdate <- NA
                    stopstatus <- NA
                    restartdate <- NA
                    restartstatus <- NA
                    whystopped <- NA
                    
                }
                
            }

        } else {
            ## There are no versions posted before the date of
            ## interest, so start at version 1 and check whether it
            ## stopped during the pandemic
            
            trial_stopped <- check_for_stop_or_start (
                nctid,
                1,
                nrow(dates),
                TRUE
            )

            if (is.list(trial_stopped)) {
                ## The trial stopped

                stopdate <-
                    dates$version_date[trial_stopped$version_number]
                stopstatus <- trial_stopped$ostatus
                whystopped <- trial_stopped$whystopped

                ## See if the trial started again
                trial_restarted <- check_for_stop_or_start (
                    nctid,
                    trial_stopped$version_number + 1,
                    nrow(dates),
                    FALSE
                )

                if (is.list(trial_restarted)) {
                    ## The trial restarted
                    restartdate <-
                    dates$version_date[trial_restarted$version_number]
                    restartstatus <- trial_restarted$ostatus
                    
                } else {
                    ## The trial never restarted
                    restartdate <- NA
                    restartstatus <- NA
                }
                
            } else {
                ## Trial never stopped
                stopdate <- NA
                stopstatus <- NA
                restartdate <- NA
                restartstatus <- NA
                whystopped <- NA
                
            }
            
        }

        newrow <- tribble(
            ~nctid,
            ~stop_date,
            ~stop_status,
            ~restart_date,
            ~restart_status,
            ~why_stopped,
            nctid,
            stopdate,
            stopstatus,
            restartdate,
            restartstatus,
            whystopped
        ) %>%
            write_csv(output_filename, append=TRUE)

        alreadydone <- read_csv(output_filename, show_col_types=FALSE)

        percentdone <- paste0(
            format(
                100 * nrow(alreadydone) / length(nctids), digits=4
            ),
            "%"
        )

        message(
            paste0(
                Sys.time(), " ",
                nctid, " processed (", percentdone, ")"
            )
        )
        
    }
    
}
## Here ends the loop *****

## Get all the trials that actually did stop before data cutoff
read_csv(output_filename, col_types="cDcDcc") %>%
    filter(! is.na(stop_date)) %>%
    filter(stop_date <= as.Date("2022-11-30")) %>%
    write_csv("data-raw/2022-12-20-trials.csv")

read_csv(output_filename, col_types="cDcDcc") %>%
    filter(! is.na(stop_date)) %>%
    filter(stop_date <= as.Date("2022-11-30")) %>%
    select(nctid) %>%
    write_csv("data-raw/2022-12-20-changed-nctids.csv")

## Now, re-run `02-setup-manual-rating.R`, `03-update-package.R`
