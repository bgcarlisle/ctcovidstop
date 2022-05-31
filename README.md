# ctcovidstop: Clinical trials that stopped during the Covid-19 pandemic

**Last updated on 2022-05-30**

Provides a database of all ClinicalTrials.gov NCT Numbers
corresponding to clinical trials that were "stopped" (had their
overall status changed to "Terminated," "Suspended," or "Withdrawn")
after 2019-12-01. This dataset indicates the date that a trial was
stopped, whether it was started again and on what date, and the
contents of the "why stopped?"  field on the date the trial
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

`c19stoppedtrials` contains 8 columns. See below for example rows:

| `nctid`     | `stop_date` | `stop_status` | `restart_date` | `restart_status` | `why_stopped`                                | `covid19_explicit` | `restart_expected` |
|-------------|-------------|---------------|----------------|------------------|----------------------------------------------|--------------------|--------------------|
| NCT04007003 | 2019-12-02  | Terminated    | NA             | NA               | Sponsor decision                             | FALSE              | NA                 |
| NCT03693833 | 2020-03-16  | Suspended     | 2020-06-15     | Recruiting       | COVID-19                                     | TRUE               | FALSE              |
| NCT04161976 | 2020-04-20  | Suspended     | 2020-06-03     | Recruiting       | Enrollment on hold due to COVID-19 pandemic. | TRUE               | TRUE               |

Each row in this data frame contains an NCT Number from
ClinicalTrials.gov (`nctid` column) and a date on which the
corresponding clinical trial record's overall status was first changed
to "Terminated", "Suspended" or "Withdrawn" from any other overall
status after 2019-12-01 (`stop_date` column). The status that the
trial was changed to on that date is indicated in the `stop_status`
column.

A trial is only included if the study's overall status changed to
"Terminated", "Suspended" or "Withdrawn" from any other overall status
after 2019-12-01. If a trial's overall status was already
"Terminated", "Suspended" or "Withdrawn" prior to 2019-12-01 and it
never became active and then stopped after 2019-12-01, it would not be
included, even if the "why stopped?" field was updated to include a
reference to Covid-19
(e.g. [NCT03365921](https://clinicaltrials.gov/ct2/history/NCT03365921
"NCT03365921")).

If the trial started again (overall status changed from "Terminated",
"Suspended" or "Withdrawn" to any other overall status) after being
"stopped" according to the definition above by the date that this data
set was last updated, the date that the trial restarted is recorded
under `restart_date`; otherwise this column contains NA. The status
that the stopped trial was changed to is indicated in the
`restart_status` column.

The reason that the trial was stopped, as reported on the first
stopped historical version of the clinical trial registry entry on
ClinicalTrials.gov, is recorded in the `why_stopped` field. If no
reason is given, this column contains NA.

If `why_stopped` cites Covid-19 explicitly as a reason why the trial
was stopped, the `covid19_explicit` column is TRUE, otherwise
FALSE. In the case that there is no value for `why_stopped`,
`covid19_explicit` is FALSE. This data point was manually rated by
BGC.

Trials that cite waning levels of Covid-19 infections, etc. as their
rationale for stopping were not considered to be stopped because of
Covid-19, and so `covid19_explicit` would be FALSE
(e.g. [NCT04390191](https://clinicaltrials.gov/ct2/history/NCT04390191
"NCT04390191")).

The `stop_date`, `stop_status` and `why_stopped` will reflect only the
first time the trial was stopped after 2019-12-01. In cases where a
trial stops after 2019-12-01 without citing Covid-19 in the
`why_stopped` field, starts again, and then stops a second time,
citing Covid-19 as a reason why the study stopped
(e.g. [NCT03728504](https://clinicaltrials.gov/ct2/history/NCT03728504
"NCT03728504")), the trial's `covid19_explicit` column is FALSE.

In cases where a trial was stopped with no rationale reported in the
version of the trial history where it was stopped, and then in a later
version, the `why_stopped` field was updated to include a rationale,
the updated rationale for stopping would not be included in this data
set.

If `covid19_explicit` is FALSE, `restart_expected` is NA. If
`covid19_explicit` is TRUE, and there is also a stated expectation
that the trial will start again in `why_stopped`, `restart_expected`
is TRUE, otherwise FALSE. Trials that mention the study is "on hold"
or "expected to resume" or that the stop was "temporary", etc. were
included. This data point was manually rated by BGC.

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

