#' Clinical trials that stopped during the SARS-CoV-2 pandemic
#'
#' This is a database of all ClinicalTrials.gov NCT Numbers
#' corresponding to clinical trials that were "stopped" (had their
#' overall status changed to "Terminated," "Suspended," or
#' "Withdrawn") between 2016-12-01 and 2019-11-30. This dataset
#' indicates the date that a trial was stopped, whether it was started
#' again and on what date, and the contents of the "why stopped?"
#' field on the date the trial was stopped.
#'
#' This data set was last updated on 2023-01-13.
#'
#' @format A tibble with 9665 rows and 6 variables:
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
#' }
#'
#' @usage data(comparator)
#'
#' @source Carlisle, B.G. Clinical Trials Stopped by Covid-19.
#' https://covid19.bgcarlisle.com
"comparator"
