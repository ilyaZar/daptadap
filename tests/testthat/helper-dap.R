write_dap_message <- function(con, message) {
  body <- jsonlite::toJSON(message, auto_unbox = TRUE, null = "null")
  body <- enc2utf8(as.character(body))
  header <- sprintf("Content-Length: %d\r\n\r\n", nchar(body, type = "bytes"))
  cat(header, body, file = con, sep = "")
  flush(con)
  invisible(message)
}

read_dap_message <- function(con, timeout = 1) {
  if (!isTRUE(socketSelect(list(con), timeout = timeout))) {
    stop("timed out waiting for DAP message", call. = FALSE)
  }

  header <- character()
  start <- proc.time()[["elapsed"]]
  repeat {
    char <- suppressWarnings(readChar(con, nchars = 1L, useBytes = TRUE))
    if (length(char) > 0L && nzchar(char)) {
      header <- c(header, char)
      text <- paste0(header, collapse = "")
      if (grepl("\r\n\r\n$", text) || grepl("\n\n$", text)) {
        break
      }
    } else {
      if ((proc.time()[["elapsed"]] - start) > timeout) {
        stop("timed out reading DAP header", call. = FALSE)
      }
      Sys.sleep(0.001)
    }
  }

  header_text <- paste0(header, collapse = "")
  match <- regexec("Content-Length: *([0-9]+)", header_text, ignore.case = TRUE)
  parts <- regmatches(header_text, match)[[1]]
  if (length(parts) < 2L) {
    stop("DAP message is missing Content-Length", call. = FALSE)
  }

  body <- readChar(con, nchars = as.integer(parts[[2]]), useBytes = TRUE)
  jsonlite::fromJSON(body, simplifyVector = FALSE)
}

send_request <- function(con, request, limit = 10L) {
  write_dap_message(con, request)
  daptadap:::process_requests(timeout = 0.05, limit = limit)
  read_dap_message(con)
}

open_dap_client <- function(metadata) {
  socketConnection(
    host = metadata$host,
    port = metadata$port,
    open = "r+b",
    blocking = TRUE,
    timeout = 2
  )
}
