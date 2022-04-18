## This data set was updated on 2022-04-14. To update it, you'll need
## to check all the trials that have been modified between 2022-04-14
## and the present day.

## To do that, you'll need to change where it starts the `batch_lb`
## variable off at `dateofinterest` to as.Date("2022-04-14")

## Make sure to change the nctidfile to update the search date

## When the NCTs are downloaded, then you can run the trial data
## download loop; again, be sure to change the `output_filename` so
## you don't write over your old work

## It'll take a while

## At the end you'll have an updated data frame; you can remove the
## rows from the old one that are in the new one, since those will be
## the "trustworthy" ones

library(tidyverse)
library(cthist)
library(lubridate)

## Where to save the output
output_filename <- "data-raw/2022-04-13-trials.csv"

## I'm calling the beginning of Dec 2019 the "date of interest",
## because the first infections occurred in this month
dateofinterest <- as.Date("2019-12-01")

nctidfile <- "data-raw/2022-04-14-changed-nctids.csv"

if (! file.exists(nctidfile)) {
    
    ## Make an empty vector of nctids
    nctids <- c()

    ## Start the lower bound of the batch at the date of interest
    batch_lb <- dateofinterest
    batch_size <- days(7)

    ## Download all the NCTs that were last modified since the date of
    ## interest in batches
    while (batch_lb < Sys.Date()) {

        batch_ub <- batch_lb + batch_size - days(1)

        message(paste("Downloading NCTs modified between", batch_lb, "and", batch_ub))
        
        batch <- paste0("https://clinicaltrials.gov/ct2/results/download_fields?down_count=10000&down_flds=all&down_fmt=csv&lupd_s=", format(batch_lb, "%m"),"%2F", format(batch_lb, "%d"), "%2F", format(batch_lb, "%Y"), "&lupd_e=", format(batch_ub, "%m"),"%2F", format(batch_ub, "%d"), "%2F", format(batch_ub, "%Y")) %>%
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
    
    for (vno in seq(from=starting_versionno, to=n_versions)) {

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
                version_data$ostatus %in% stoppedstatuses
        } else {
            ## We're checking to see when it's not stopped
            return_condition <-
                ! version_data$ostatus %in% stoppedstatuses
            
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

        ## Make a data frame that matches the version number to the date
        dates <- tibble(
            version_date = as.Date(dates),
            versionno = seq(1:length(dates))
        )

        ## Make a data frame including only the dates that were before the
        ## date of interest
        versions_before_date_of_interest <- dates %>%
            filter(version_date <= dateofinterest)

        if (nrow(versions_before_date_of_interest) > 0) {
            ## There are versions posted before the date of interest, so
            ## we need to check that the trial wasn't already stopped
            ## before Covid

            ## Get the version number for the last version posted before
            ## the date of interest
            versionno_before_date_of_interest <- dates %>%
                filter(version_date <= dateofinterest) %>%
                slice_tail() %>%
                select(versionno) %>%
                pull()


            dl_success <- FALSE
            while (! dl_success) {
                
                message(paste("Downloading version", versionno_before_date_of_interest, "of", nctid))
                version_before_date_of_interest <- clinicaltrials_gov_version(
                    nctid,
                    versionno_before_date_of_interest
                )

                if (version_before_date_of_interest[1] != "Error") {
                    dl_success <- TRUE
                }
                
            }

            version_before_date_of_interest_not_stopped <-
                ! version_before_date_of_interest$ostatus %in% stoppedstatuses

            if (version_before_date_of_interest_not_stopped) {
                ## The version immediately before the date of interest was
                ## not stopped, so if it stopped, it happened during the
                ## pandemic

                ## Loop through the remaining versions and check whether
                ## it stopped during the pandemic

                trial_stopped <- check_for_stop_or_start (
                    nctid,
                    versionno_before_date_of_interest + 1,
                    nrow(dates),
                    TRUE
                )

                if (is.list(trial_stopped)) {
                    ## The trial stopped after the date of interest; see
                    ## if it started again

                    trial_restarted <- check_for_stop_or_start (
                        nctid,
                        trial_stopped$version_number + 1,
                        nrow(dates),
                        FALSE
                    )
                    
                    if (is.list(trial_restarted)) {

                        stopdate <-
                            dates$version_date[trial_stopped$version_number]
                        stopstatus <- trial_stopped$ostatus
                        restartdate <-
                            dates$version_date[trial_restarted$version_number]
                        restartstatus <- trial_restarted$ostatus
                        whystopped <- trial_stopped$whystopped
                        
                    } else {

                        stopdate <-
                            dates$version_date[trial_stopped$version_number]
                        stopstatus <- trial_stopped$ostatus
                        restartdate <- NA
                        restartstatus <- NA
                        whystopped <- trial_stopped$whystopped
                        
                    }
                    
                } else {
                    ## The trial never stopped after the date of interest
                    stopdate <- NA
                    stopstatus <- NA
                    restartdate <- NA
                    restartstatus <- NA
                    whystopped <- NA
                    
                }
                
            } else {
                ## The version immediately before the date of interest was
                ## stopped, so we have to check whether it started and
                ## then stopped again during the pandemic

                trial_started <- check_for_stop_or_start (
                    nctid,
                    versionno_before_date_of_interest + 1,
                    nrow(dates),
                    FALSE
                )

                if (is.list(trial_started)) {
                    ## The trial started after the date of interest, so we
                    ## have to check whether it stopped during the
                    ## pandemic

                    trial_stopped <- check_for_stop_or_start (
                        nctid,
                        trial_started$version_number + 1,
                        nrow(dates),
                        TRUE
                    )
                    
                } else {
                    ## The trial was stopped before the date of interest
                    ## and never started, so it couldn't have stopped
                    ## during our timeframe
                    stopdate <- NA
                    stopstatus <- NA
                    restartdate <- NA
                    restartstatus <- NA
                    whystopped <- NA
                    
                }
                
            }

        } else {
            ## There are no versions posted before the date of interest,
            ## so start at version 1 and check whether it stopped during
            ## the pandemic
            
            trial_stopped <- check_for_stop_or_start (
                nctid,
                1,
                nrow(dates),
                TRUE
            )

            if (is.list(trial_stopped)) {
                ## See if it started again

                trial_restarted <- check_for_stop_or_start (
                    nctid,
                    trial_stopped$version_number + 1,
                    nrow(dates),
                    FALSE
                )

                if (is.list(trial_restarted)) {

                    stopdate <-
                        dates$version_date[trial_stopped$version_number]
                    stopstatus <- trial_stopped$ostatus
                    restartdate <-
                        dates$version_date[trial_restarted$version_number]
                    restartstatus <- trial_restarted$ostatus
                    whystopped <- trial_stopped$whystopped
                    
                } else {

                    stopdate <-
                        dates$version_date[trial_stopped$version_number]
                    stopstatus <- trial_stopped$ostatus
                    restartdate <- NA
                    restartstatus <- NA
                    whystopped <- trial_stopped$whystopped
                    
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

        percentdone <- paste0(format(100 * nrow(alreadydone) / length(nctids), digits=4), "%")

        message(paste0(Sys.time(), " ", nctid, " processed (", percentdone, ")"))
        
    }
    
}
