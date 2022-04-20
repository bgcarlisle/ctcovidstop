test_that("There should be no double-ratings", {
    ## Read the ratings into memory.
    ratings <- tibble::tribble(
        ~nctid,
        ~covid19_explicit,
        ~restart_expected
    )

    ## Get all the ratings files
    ratings_files <- list.files("data-raw", "ratings\\.csv$")

    ## Then for each of those files, we read them in and select the
    ## relevant columns
    for (ratings_file in ratings_files) {
        newrows <- readr::read_csv(
            paste0("data-raw/", ratings_file),
            show_col_types = FALSE
        ) %>%
            select(nctid, covid19_explicit, restart_expected)

        ratings <- ratings %>%
            bind_rows(newrows)
        
    }
    
    expect_equal(
        length(unique(ratings$nctid)),
        length(ratings$nctid)
    )
})
