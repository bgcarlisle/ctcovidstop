library(tidyverse)
library(cthist)
library(lubridate)

## When updating this data set, change this to today's date. It isn't
## set to take the system date because the update may take more than a
## day to complete.
current_update <- as.Date("2022-07-14")

## I'm calling the beginning of Dec 2019 the "date of interest",
## because the first infections occurred in this month. Don't change
## this when updating.
dateofinterest <- as.Date("2019-12-01")

## The previous update is the date on which the NCT's to check were
## last downloaded
previous_nctidfiles <- list.files("data-raw", "changed-nctids\\.csv$")

if (length(previous_nctidfiles) > 0) {
    latest_nctidfile <-
        previous_nctidfiles[length(previous_nctidfiles)]
    previous_update <- as.Date(substr(latest_nctidfile, 0, 10))
} else {
    previous_update <- dateofinterest
}

## Where to save the file of NCT numbers that need to have their data
## downloaded
nctidfile <- paste0(
    "data-raw/", current_update, "-changed-nctids.csv"
)

## Where to save the trial data that can be downloaded automatically
## from ClinicalTrials.gov
output_filename <- paste0("data-raw/", current_update, "-trials.csv")

if (! file.exists(nctidfile)) {
    ## There is no nctid file, so we'll download all the NCT numbers
    ## from between the date of the last update and the date provided
    ## above; in the case that there is no previous search, it will
    ## start at the date of interest (2019-12-01)
    
    ## Make an empty vector of nctids
    nctids <- c()

    ## We can only download 10,000 at a time, so we have to work in
    ## batches
    batch_lb <- previous_update
    batch_size <- days(7)

    ## Download all the NCTs that were last modified since the date of
    ## interest in batches
    while (batch_lb < current_update) {

        batch_ub <- batch_lb + batch_size - days(1)

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
        
        if (length(batch) > 10000) {
            message("WARNING: You need smaller batches")
        }
        
        nctids <- c(
            nctids,
            batch
        )
        
        batch_lb <- batch_lb + days(7)
        
    }

    tibble(nctids) %>%
        write_csv(nctidfile)

    ## All done downloading NCTs
    message(paste(length(nctids), "NCTs downloaded total"))

} else {

    nctids <- read_csv(nctidfile) %>%
        pull()
    
}

stoppedstatuses <- c(
    "Terminated",
    "Suspended",
    "Withdrawn"
)

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
