test_that("Only C19-explicit trials were rated for expecting restart", {
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
            dplyr::select(nctid, covid19_explicit, restart_expected)

        ratings <- ratings %>%
            dplyr::bind_rows(newrows)
        
    }
    
    rated_non_c19 <- ratings %>%
        dplyr::filter(! covid19_explicit) %>%
        dplyr::filter(! is.na(restart_expected)) %>%
        nrow()
    
    expect_equal(
        rated_non_c19,
        0
    )
    
})
