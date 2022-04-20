#' Clinical trials that stopped during the SARS-CoV-2 pandemic
#'
#' This is a database of all ClinicalTrials.gov NCT Numbers
#' corresponding to clinical trials that were "stopped" (had their
#' overall status changed to "Terminated," "Suspended," or
#' "Withdrawn") during the SARS-CoV-2 pandemic that began with human
#' infections starting in December 2019. This dataset indicates the
#' date that a trial was stopped, whether it was started again and on
#' what date, and the contents of the "why stopped?" field on the date
#' the trial was stopped. This dataset also includes columns with
#' manually coded data for whether the "why stopped?" field explicitly
#' indicates that the reason for stopping included the SARS-CoV-2
#' pandemic.
#'
#' @format A tibble with XX rows and 8 variables:
#' \describe{
#'   \item{nctid}{chr Clinical trial registry number}
#'   \item{stop_date}{date The date that the clinical trial's overall
#'   status was changed to Terminated, Suspended or Withdrawn after
#'   2019-12-01, or NA if this never occurred}
#'   \item{stop_status}{chr The status of the clinical trial registry
#'   entry on the date it was stopped (Terminated, Suspended or
#'   Withdrawn) or NA if this never happened}
#'   \item{restart_date}{date The date that the clinical trial's
#'   overall status was changed from Terminated, Suspended or
#'   Withdrawn after it was stopped, or NA if this never occurred}
#'   \item{restart_status}{chr The status of the clinical trial
#'   registry entry on the date it was changed from Terminated,
#'   Suspended or Withdrawn again, or NA if this never happened}
#'   \item{why_stopped}{chr The reason that the trial was stopped, as
#'   reported in the `why_stopped` field on ClinicalTrials.gov}
#'   \item{covid19_explicit}{logical If the "why stopped?" field cites
#'   Covid-19 explicitly as a reason why the trial was stopped, TRUE,
#'   otherwise FALSE}
#'   \item{restart_expected}{logical If the "why stopped?" field cites
#'   Covid-19 explicitly as a reason why the trial was stopped and
#'   there is a stated expectation that the trial will start again,
#'   TRUE; if there is no stated expectation that the trial will start
#'   again, FALSE. If the trial did not cite Covid-19 explicitly as a
#'   reason for stopping, NA.}
#' }
#'
#' @usage data(c19stoppedtrials)
#'
#' @source Carlisle, B.G. Clinical Trials Stopped by Covid-19.
#' https://covid19.bgcarlisle.com
"c19stoppedtrials"
