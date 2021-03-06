#' Main Cross-Validation Function
#'
#' Applies \code{cvfun} to the folds using \code{future_lapply} and combines the
#' results across folds using \code{combine_results}.
#'
#' @param cv_fun a function that takes a 'fold' as it's first argument and
#'        returns a list of results from that fold.
#' @param folds a list of folds to loop over generated using
#'        \code{\link{make_folds}}.
#' @param ... other arguments passed to \code{cvfun}.
#' @param .combine (logical) - should \code{\link{combine_results}} be called.
#' @param .combine_control (list) - arguments to \code{\link{combine_results}}.
#' @param .old_results (list) - the returned result from a previous call to
#'        This function. Will be combined with the current results. This is
#'        useful for adding additional CV folds to a results object.
#'
#' @importFrom future future values future_lapply plan sequential multicore multisession
#' @importFrom listenv listenv
#'
#' @return A list of results, combined across folds.
#'
#' @export
#'
#' @example /inst/examples/cv_simple_example.R
#'
#' @example /inst/examples/cv_parallel_example.R
#'
cross_validate <- function(cv_fun,
                           folds,
                           ...,
                           .combine = TRUE,
                           .combine_control = list(),
                           .old_results = NULL) {

    #catch and return errors if they occur
    wrapped_fun <- wrap_in_try(cv_fun)

    # main loop
    results <- future_lapply(folds, wrapped_fun, ...)

    # remove error results
    error_idx <- which(sapply(results, inherits, "try-error"))
    error_results <- list(index = error_idx, error = results[error_idx])
    good_results <- setdiff(seq_along(folds), error_idx)
    results <- results[good_results]

    if(length(results) > 0) {
        # verify that the folds returned similar results
        if (length(unique(lapply(results, length))) > 1)
            stop("lists returned from folds are not the same length")
        if (length(unique(lapply(results, names))) > 1)
            stop("names returned from folds are not consistent")

        # invert results - go from a list containing one list per fold to a list
        # containing one list per result returned by cv_fun
        results <- apply(do.call(rbind, results), 2, as.list)

        # combine results
        if (.combine) {
            results <- do.call(combine_results,
                               c(list(results = results),
                               .combine_control))
        }
    } else {
        warning("All iterations resulted in errors")
    }

    results$errors <- error_results

    if (!is.null(.old_results)) {
        # invert results - go from a list containing one list per fold to a list
        # containing one list per result returned by cv_fun
        new_and_old <- list(results, .old_results)
        new_and_old <- apply(do.call(rbind, new_and_old), 2, as.list)
        results <- combine_results(results = new_and_old)
    }
    return(results)
}
