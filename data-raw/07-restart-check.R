library(tidyverse)
library(cthist)
library(testthat)

## The date of the final check that a trial started again
rc_date <- "2023-12-20"

## Read in all the trials that stopped during Covid
c19stoppedtrials <- read_csv("inst/extdata/c19stoppedtrials.csv")

## Make a data frame of all the trials that have no recorded
## restart_date
tocheck <- c19stoppedtrials %>%
    filter(is.na(restart_date))

## Add an empty column, later we'll fill this in with the last date on
## which the trial was updated. We're doing this so that we don't have
## to download all the historical versions for all the trials; we'll
## only do that for the ones where they have been updated since they
## stopped.
tocheck$rcheck <- as.character(NA)

## These trials don't resolve anymore, so they can't have been started
## again
problem_trns <- tribble(
    ~nctid,
    "NCT03689985",
    "NCT04112342"
)

## Check all the trials that don't have a restart date recorded for
## when they were last updated (don't need to check the ones where
## they haven't been updated since they stopped)
for (trn in tocheck$nctid) {

    if (! trn %in% problem_trns$nctid) {

        last_change_date <- clinicaltrials_gov_dates(trn) %>%
            slice_tail() %>%
            pull(date)

        message(trn)
        message(last_change_date)

        tocheck <- tocheck %>%
            mutate(
                rcheck = ifelse(
                    nctid == trn,
                    last_change_date,
                    rcheck
                )
            )

        message(
            paste(
                nrow(filter(tocheck, is.na(rcheck))),
                "remaining"
            )
        )
        
    }
        
}

## Manually set the problem TRNs to FALSE
tocheck <- tocheck %>%
    mutate(
        rcheck = ifelse(
            nctid %in% problem_trns$nctid,
            FALSE,
            rcheck
        )
    )

## Make a data frame of trials to be fully checked, as they have been
## changed since the last update, so they might have restarted (the
## rest can be safely discarded)
full_check <- tocheck %>%
    filter(stop_date != rcheck)

## Make an empty frame and write to disk
full_check_file <- "data-raw/2023-12-21-full-check.csv"
tribble(
    ~nctid, ~restart_date, ~restart_status
) %>%
    write_csv(full_check_file)

## Loop through all the TRNs where the registry record has been
## updated since it stopped
for (trn in full_check$nctid) {

    ## Check that the TRN hasn't already been processed
    alreadychecked <- read_csv(full_check_file)
    if (! trn %in% alreadychecked$nctid) {

        ## Get the stop date for that TRN
        sdate <- full_check %>%
            filter(nctid == trn) %>%
            pull(stop_date)

        ## Download all the historical versions for the TRN and keep
        ## only ones from after the stop date that are not
        ## "Terminated," "Suspended" or "Withdrawn", then only take
        ## the first of those
        restart_version <- clinicaltrials_gov_download(trn) %>%
            filter(version_date > sdate) %>%
            filter(
                ! overall_status %in%
                c("TERMINATED", "SUSPENDED", "WITHDRAWN")
            ) %>%
            slice_head()

        if (nrow(restart_version) == 1) {
            ## If there is one version that meets the criteria above,
            ## get its date and overall status
            rdate <- restart_version %>%
                pull(version_date)
            rstatus <- restart_version %>%
                pull(overall_status)
        } else {
            ## If not, set the date and overall status to NA
            rdate <- NA
            rstatus <- NA
        }

        ## Write these to disk
        tribble(
            ~nctid, ~restart_date, ~restart_status,
            trn,    rdate,          rstatus
        ) %>%
            write_csv(full_check_file, append=TRUE)
    }
    
}

## Check that no TRNs were missed
test_that(
    "All the TRNs have been checked",
    {
        done <- read_csv(full_check_file)

        expect_equal(
            sum(! full_check$nctid %in% done$nctid),
            0
        )
    }
)

## This is the set of all trials that have been restarted since the
## last check and when they restarted
updated <- read_csv(full_check_file) %>%
    filter(! is.na(restart_date))

## In the time since the data cutoff and the last check for trials to
## restart, the format of the overall status column changed. This
## lookup table allows us to transform the newly-downloaded restart
## statuses to be consistent with the old format.
status_lookup <- tribble(
    ~old_format,               ~restart_status,
    "Active, not recruiting",  "ACTIVE_NOT_RECRUITING",
    "Not yet recruiting",      "NOT_YET_RECRUITING",
    "Recruiting",              "RECRUITING",
    "Completed",               "COMPLETED",
    "Enrolling by invitation", "ENROLLING_BY_INVITATION"
)

## Apply the lookup table
updated <- updated %>%
    left_join(status_lookup) %>%
    select(! restart_status) %>%
    rename(new_restart_status = old_format) %>%
    rename(new_restart_date = restart_date)

## Insert the new data points into the c19stoppedtrials data frame
c19stoppedtrials <- c19stoppedtrials %>%
    left_join(updated) %>%
    mutate(
        combined_rdate = ifelse(
            ! is.na(restart_date),
            restart_date,
            new_restart_date
        ) %>%
            as.Date()
    ) %>%
    mutate(
        combined_rstatus = ifelse(
            ! is.na(restart_status),
            restart_status,
            new_restart_status
        )
    ) %>%
    select(! restart_date) %>%
    select(! new_restart_date) %>%
    rename(restart_date = combined_rdate) %>%
    select(! new_restart_status) %>%
    select(! restart_status) %>%
    rename(restart_status = combined_rstatus) %>%
    select(
        nctid,
        stop_date,
        stop_status,
        restart_date,
        restart_status,
        why_stopped,
        covid19_explicit,
        restart_expected
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
