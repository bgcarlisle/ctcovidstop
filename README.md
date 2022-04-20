# ctcovidstop

Provides a database of all ClinicalTrials.gov NCT Numbers
corresponding to clinical trials that were "stopped" (had their
overall status changed to "Terminated," "Suspended," or "Withdrawn")
during the SARS-CoV-2 pandemic that began with human infections
starting in December 2019. This dataset indicates the date that a
trial was stopped, whether it was started again and on what date, and
the contents of the "why stopped?" field on the date the trial
stopped. This dataset also includes columns with manually coded data
for whether the "why stopped?" field explicitly indicates that the
reason for stopping included the SARS-CoV-2 pandemic.

## To install and use

Install from Github:

```
install.packages("devtools")
library(devtools)
install_github("bgcarlisle/ctcovidstop")
```

After installation:

```
library(ctcovidstop)
data(c19stoppedtrials)
```

This package provides a data frame, `c19stoppedtrials`, which can be loaded
via the *R* package with `data(c19stoppedtrials)`. The same data frame is
also provided as a CSV in this repository as
`inst/extdata/c19stoppedtrials.csv`.

`c19stoppedtrials` contains 8 columns:

| `nctid` | `stop_date` | `stop_status` | `restart_date` | `restart_status` | `why_stopped` | `covid19_explicit` | `restart_expected` |
|---------|-------------|---------------|----------------|------------------|---------------|--------------------|--------------------|

Each row in this data frame contains an NCT Number from
ClinicalTrials.gov (`nctid` column) and a date on which the
corresponding clinical trial record's overall status was changed to
"Terminated", "Suspended" or "Withdrawn" (`stop_date`). The status
that the trial was changed to is indicated in the `stop_status`
column.

If the trial was started again (overall status changed from
"Terminated", "Suspended" or "Withdrawn" to anything else) by the
search date, the date this occurred is recorded under `restart_date`,
otherwise this column contains NA. The status that the trial was
changed to is indicated in the `restart_status` column.

The reason that the trial was stopped as reported on
ClinicalTrials.gov is recorded in the `why_stopped` field. If no
reason is given, this column contains NA.

If `why_stopped` cites Covid-19 explicitly as a reason why the trial
was stopped, the `covid19_explicit` column is TRUE, otherwise
FALSE. In the case that there is no value for `why_stopped`, this
column is NA. This data point was manually rated by BGC.

If `covid19_explicit` is TRUE, and there is a stated expectation that
the trial will start again, `restart_expected` is TRUE, otherwise
FALSE. If `covid19_explicit` is FALSE or NA, `restart_expected` is NA.
This data point was manually rated by BGC.

## Citing `ctcovidstop`

These data are provided under a Creative Commons by-attribution
licence.

Here is a BibTeX entry for `ctcovidstop`:

```
@Manual{ctcovidstop-carlisle,
  Title          = {ctcovidstop},
  Author         = {Carlisle, Benjamin Gregory},
  Organization   = {The Grey Literature},
  Address        = {Berlin, Germany},
  url            = {https://github.com/bgcarlisle/ctcovidstop},
  year           = 2022
}
```

If you use this data set and you found it useful, I would take it as a
kindness if you cited it.

Best,

Benjamin Gregory Carlisle PhD

