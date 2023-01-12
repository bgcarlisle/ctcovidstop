library(tidyverse)
library(testthat)
library(lubridate)

comparator <- read_csv("data-raw/comparator-trials.csv") %>%
    filter(! is.na(stop_date)) %>%
    filter(stop_date >= as.Date("2016-12-01")) %>%
    filter(stop_date <= as.Date("2019-11-30")) %>%
    arrange(stop_date)
