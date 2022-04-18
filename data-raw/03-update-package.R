library(tidyverse)

trials <- read_csv("2022-04-13-trials.csv") %>%
    filter(! is.na(stop_date))

wa_ratings <- read_csv("2022-04-14-webapp-ratings.csv")

m_ratings <- read_csv("2022-04-14-manual-ratings.csv") %>%
    select(!why_stopped)

ratings <- wa_ratings %>%
    bind_rows(m_ratings)

trials <- trials %>%
    left_join(ratings)

## How many trials cite C19 explicitly?
trials %>%
    filter(covid19_explicit) %>%
    nrow()

trials %>%
    write_csv("2022-04-14-c19-stopped-export.csv")
