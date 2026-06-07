#' Start the daptadap DAP helper
#'
#' Start a single-process Debug Adapter Protocol helper for an interactive R
#' console. Write the connection metadata needed by a DAP client.
#'
#' `dap_start()` first stops any running daptadap server. It then opens a local
#' socket server, records the selected port, writes metadata,
#' and schedules non-blocking polling for DAP requests while R is running.
#'
#' @param host Character scalar. Host interface for the DAP server socket.
#' @param port Integer scalar. Port for the DAP server socket, or `0` to choose
#'   an available local port.
#' @param path_connection Character scalar or `NULL`. Path where connection
#'   metadata should be written. When `NULL`, daptadap writes `daptadap.json`
#'   below `RNVIM_TMPDIR` or `tempdir()`.
#' @param path_workspace Character scalar. Workspace folder reported to DAP
#'   clients.
#'
#' @return Invisibly returns a metadata list with the selected host, port,
#'   workspace path, process id, and protocol fields.
#' @export
dap_start <- function(host = "127.0.0.1", port = 0L,
                  path_connection = NULL, path_workspace = getwd()) {
  dap_stop()

  opened <- open_server(host, as.integer(port %||% 0L))
  .state$server <- opened$server
  .state$host <- host
  .state$port <- opened$port
  .state$path_connection <- path_connection %||%
    file.path(Sys.getenv("RNVIM_TMPDIR", tempdir()), "daptadap.json")
  .state$path_workspace <- path_workspace
  .state$running <- TRUE
  .state$terminated <- FALSE

  metadata <- write_metadata()
  schedule_poll()
  invisible(metadata)
}

#' Stop the daptadap DAP helper
#'
#' Stop the active daptadap helper owned by this R process.
#'
#' `dap_stop()` closes any accepted DAP client connection, closes the listening
#' server socket, removes the helper metadata file, and resets package-private
#' debugger state.
#'
#' @return Invisibly returns `NULL`.
#' @export
dap_stop <- function() {
  close_client()
  if (!is.null(.state$server)) {
    try(close(.state$server), silent = TRUE)
  }
  if (!is.null(.state$path_connection) && nzchar(.state$path_connection)) {
    try(unlink(.state$path_connection), silent = TRUE)
  }
  reset_session_state()
  invisible(NULL)
}

#' Pump DAP requests at an R browser stop
#'
#' Process pending Debug Adapter Protocol requests while R is stopped at a
#' browser prompt.
#'
#' `dap_pump()` is intended to be sent by the editor integration when the R
#' console reaches `Browse[n]>`. On the first pump for a stop, it captures stack
#' frames and variables, emits a DAP `stopped` event, and then processes DAP
#' requests until execution continues or the session terminates.
#'
#' @param fallback_reason Character scalar. Stop label used when the current DAP
#'   stop reason cannot be inferred from the active breakpoint set.
#'
#' @return Invisibly returns `TRUE` when a pump ran. Returns `FALSE` when the
#'   helper is not running or no DAP client is connected.
#' @export
dap_pump <- function(fallback_reason = "browser") {
  if (!isTRUE(.state$running)) {
    return(invisible(FALSE))
  }
  accept_client()
  if (is.null(.state$con)) {
    return(invisible(FALSE))
  }
  if (!isTRUE(.state$stopped)) {
    capture_stop_state(fallback_reason)
    send_event("stopped", list(
      reason = .state$stop_reason %||% fallback_reason,
      threadId = 1L,
      allThreadsStopped = TRUE
    ))
  }

  repeat {
    process_requests(timeout = 0.05, limit = 20L)
    if (!isTRUE(.state$stopped) || isTRUE(.state$terminated)) {
      break
    }
    Sys.sleep(0.005)
  }
  invisible(TRUE)
}

#' Source an R file with DAP breakpoints
#'
#' Source an R script after inserting browser stops for breakpoints registered
#' by the active DAP client.
#'
#' Use `dap_debug_source()` to source a file through daptadap. It reads the
#' target file, injects `browser()` calls on breakpoint lines known to daptadap,
#' parses the transformed source with source references preserved, and evaluates
#' it in the requested environment.
#'
#' @param path_source Character scalar. Path to the R file to source.
#' @param local Logical scalar. If `TRUE`, evaluate in a new environment whose
#'   parent is the global environment. If `FALSE`, evaluate in `.GlobalEnv`.
#' @param encoding Character scalar. Encoding passed to `readLines()`.
#'
#' @return Invisibly returns `TRUE` after evaluation completes.
#' @export
dap_debug_source <- function(path_source, local = FALSE, encoding = "unknown") {
  path_source <- normalizePath(path_source, winslash = "/", mustWork = TRUE)
  lines <- readLines(path_source, warn = FALSE, encoding = encoding)
  lines <- insert_browser_breakpoints(path_source, lines)
  srcfile <- srcfilecopy(path_source, lines, isFile = FALSE)
  exprs <- parse(text = lines, srcfile = srcfile, keep.source = TRUE)
  env <- if (isTRUE(local)) new.env(parent = .GlobalEnv) else .GlobalEnv
  eval(exprs, envir = env)
  invisible(TRUE)
}
