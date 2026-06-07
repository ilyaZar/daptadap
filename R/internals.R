#' daptadap
#'
#' Debug Adapter Protocol helper internals for R console workflows.
#'
#' @keywords internal
#' @importFrom jsonlite fromJSON toJSON
#' @importFrom later later
#' @importFrom utils capture.output getSrcFilename getSrcLocation str
"_PACKAGE"

`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}

.state <- new.env(parent = emptyenv())

reset_session_state <- function() {
  .state$server <- NULL
  .state$con <- NULL
  .state$host <- "127.0.0.1"
  .state$port <- NULL
  .state$seq <- 1L
  .state$running <- FALSE
  .state$stopped <- FALSE
  .state$stop_reason <- NULL
  .state$stop_generation <- 0L
  .state$frames <- list()
  .state$frame_envs <- list()
  .state$frame_formals <- list()
  .state$vars <- list()
  .state$next_var_ref <- 1L
  .state$breakpoints <- list()
  .state$path_connection <- NULL
  .state$path_workspace <- getwd()
  .state$pending_console_input <- NULL
  .state$terminated <- FALSE
}

reset_session_state()

as_path_key <- function(path_input) {
  if (is.null(path_input) || !nzchar(path_input)) {
    return("")
  }
  normalizePath(path_input, winslash = "/", mustWork = FALSE)
}

next_seq <- function() {
  seq <- .state$seq
  .state$seq <- seq + 1L
  seq
}

drop_nulls <- function(x) {
  if (!is.list(x)) {
    return(x)
  }
  for (name in rev(names(x))) {
    if (is.null(x[[name]])) {
      x[[name]] <- NULL
    } else {
      x[[name]] <- drop_nulls(x[[name]])
    }
  }
  x
}

write_dap <- function(message) {
  con <- .state$con
  if (is.null(con) || !isOpen(con)) {
    return(FALSE)
  }

  json <- jsonlite::toJSON(drop_nulls(message), auto_unbox = TRUE, null = "null")
  json <- enc2utf8(as.character(json))
  header <- sprintf("Content-Length: %d\r\n\r\n", nchar(json, type = "bytes"))
  cat(header, json, file = con, sep = "")
  flush(con)
  TRUE
}

send_response <- function(request, body = NULL, success = TRUE,
                          message = NULL) {
  response <- list(
    type = "response",
    seq = next_seq(),
    request_seq = request$seq,
    success = success,
    command = request$command,
    message = message,
    body = body
  )
  write_dap(response)
}

send_event <- function(event, body = NULL) {
  write_dap(list(
    type = "event",
    seq = next_seq(),
    event = event,
    body = body
  ))
}

read_exact <- function(con, bytes, timeout = 1) {
  out <- character()
  start <- proc.time()[["elapsed"]]
  while (nchar(paste0(out, collapse = ""), type = "bytes") < bytes) {
    chunk <- suppressWarnings(readChar(
      con,
      nchars = bytes - nchar(paste0(out, collapse = ""), type = "bytes"),
      useBytes = TRUE
    ))
    if (length(chunk) > 0L && nzchar(chunk)) {
      out <- c(out, chunk)
      next
    }
    if ((proc.time()[["elapsed"]] - start) > timeout) {
      return(NULL)
    }
    Sys.sleep(0.001)
  }
  paste0(out, collapse = "")
}

read_dap_message <- function(timeout = 0) {
  con <- .state$con
  if (is.null(con) || !isOpen(con)) {
    return(NULL)
  }
  if (!isTRUE(socketSelect(list(con), timeout = timeout))) {
    return(NULL)
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
      if ((proc.time()[["elapsed"]] - start) > 1) {
        return(NULL)
      }
      Sys.sleep(0.001)
    }
  }

  header_text <- paste0(header, collapse = "")
  match <- regexec("Content-Length: *([0-9]+)", header_text, ignore.case = TRUE)
  parts <- regmatches(header_text, match)[[1]]
  if (length(parts) < 2L) {
    return(NULL)
  }

  body <- read_exact(con, as.integer(parts[[2]]))
  if (is.null(body)) {
    return(NULL)
  }

  jsonlite::fromJSON(body, simplifyVector = FALSE)
}

open_server <- function(host, port) {
  if (is.null(port) || port <= 0L) {
    candidates <- sample(seq.int(18721L, 28721L), 200L)
  } else {
    candidates <- as.integer(port)
  }

  last_error <- NULL
  for (candidate in candidates) {
    server <- tryCatch(serverSocket(candidate), error = identity)
    if (!inherits(server, "error")) {
      return(list(server = server, port = candidate))
    }
    last_error <- server
  }

  base::stop(
    "failed to open daptadap DAP server: ",
    conditionMessage(last_error)
  )
}

accept_client <- function() {
  if (is.null(.state$server) || !is.null(.state$con)) {
    return(invisible(FALSE))
  }
  if (!isTRUE(socketSelect(list(.state$server), timeout = 0))) {
    return(invisible(FALSE))
  }

  con <- suppressWarnings(socketAccept(
    .state$server,
    blocking = FALSE,
    open = "r+b",
    timeout = 1
  ))
  socketTimeout(con, 1)
  .state$con <- con
  invisible(TRUE)
}

close_client <- function() {
  if (!is.null(.state$con)) {
    try(close(.state$con), silent = TRUE)
  }
  .state$con <- NULL
}

clear_stop_state <- function() {
  .state$stopped <- FALSE
  .state$stop_reason <- NULL
  .state$frames <- list()
  .state$frame_envs <- list()
  .state$frame_formals <- list()
  .state$vars <- list()
  .state$next_var_ref <- 1L
}

new_var_ref <- function(value, kind = "value", fields = list()) {
  ref <- .state$next_var_ref
  .state$next_var_ref <- ref + 1L
  .state$vars[[as.character(ref)]] <- c(list(kind = kind, value = value), fields)
  ref
}

src_info <- function(srcref) {
  if (is.null(srcref)) {
    return(list(path_source = NULL, line = 1L, column = 1L))
  }

  path_source <- tryCatch(
    getSrcFilename(srcref, full.names = TRUE),
    error = function(e) NULL
  )
  if (length(path_source) == 0L || !nzchar(path_source[[1]])) {
    path_source <- NULL
  } else {
    path_source <- as_path_key(path_source[[1]])
  }

  line <- tryCatch(getSrcLocation(srcref, "line"), error = function(e) 1L)
  column <- tryCatch(getSrcLocation(srcref, "column"), error = function(e) 1L)
  list(path_source = path_source, line = as.integer(line %||% 1L),
       column = as.integer(column %||% 1L))
}

call_name <- function(call) {
  if (length(call) == 0L) {
    return("<unknown>")
  }
  head <- call[[1L]]
  if (is.symbol(head)) {
    return(as.character(head))
  }
  paste(deparse(call, nlines = 1L), collapse = " ")
}

is_daptadap_pump_call <- function(call) {
  text <- paste(deparse(call, nlines = 1L), collapse = " ")
  grepl("dap_pump", text, fixed = TRUE) ||
    grepl("daptadap::dap_pump", text, fixed = TRUE)
}

is_stack_wrapper_call <- function(call) {
  name <- call_name(call)
  name %in% c("eval", "source", "withVisible", "local")
}

breakpoint_lines_for <- function(path_source) {
  key <- as_path_key(path_source)
  .state$breakpoints[[key]] %||% integer()
}

capture_stop_state <- function(fallback_reason = "browser") {
  calls <- sys.calls()
  frames <- sys.frames()
  pump_call_indices <- which(vapply(calls, is_daptadap_pump_call, logical(1)))
  pump_call_index <- if (length(pump_call_indices)) {
    max(pump_call_indices)
  } else {
    length(calls)
  }
  last_user_call <- max(1L, pump_call_index - 1L)

  stop_srcref <- attr(calls[[pump_call_index]], "srcref", exact = TRUE) %||%
    attr(calls[[last_user_call]], "srcref", exact = TRUE)
  stop_location <- src_info(stop_srcref)

  .state$stop_generation <- .state$stop_generation + 1L
  .state$frames <- list()
  .state$frame_envs <- list()
  .state$frame_formals <- list()
  .state$vars <- list()
  .state$next_var_ref <- 1L

  frame_id <- 1L
  for (index in rev(seq_len(last_user_call))) {
    call <- calls[[index]]
    if (is_stack_wrapper_call(call)) {
      next
    }

    info <- src_info(attr(call, "srcref", exact = TRUE))
    if (frame_id == 1L) {
      info <- stop_location
    }

    source <- if (!is.null(info$path_source)) {
      list(name = basename(info$path_source), path = info$path_source)
    } else {
      list(name = "<R>")
    }

    id <- .state$stop_generation * 1000L + frame_id
    .state$frames[[frame_id]] <- list(
      id = id,
      name = call_name(call),
      source = source,
      line = info$line,
      column = info$column
    )
    .state$frame_envs[[as.character(id)]] <- frames[[index]]
    .state$frame_formals[[as.character(id)]] <- tryCatch(
      names(formals(sys.function(index))),
      error = function(e) character()
    )
    frame_id <- frame_id + 1L
  }

  if (!length(.state$frames)) {
    id <- .state$stop_generation * 1000L + 1L
    .state$frames[[1L]] <- list(
      id = id,
      name = "Global Workspace",
      line = 1L,
      column = 1L,
      source = list(name = "<R>")
    )
    .state$frame_envs[[as.character(id)]] <- .GlobalEnv
    .state$frame_formals[[as.character(id)]] <- character()
  }

  top <- .state$frames[[1L]]
  path_source <- top$source$path %||% ""
  lines <- breakpoint_lines_for(path_source)
  .state$stop_reason <- if (top$line %in% lines) "breakpoint" else fallback_reason
  .state$stopped <- TRUE
}

preview_value <- function(value) {
  if (is.null(value)) {
    return(list(value = "NULL", type = "NULL", expandable = FALSE))
  }
  if (is.function(value)) {
    return(list(value = "<function>", type = "function", expandable = FALSE))
  }
  if (is.environment(value)) {
    return(list(value = "<environment>", type = "environment", expandable = FALSE))
  }
  if (is.data.frame(value)) {
    return(list(
      value = sprintf("data.frame [%d x %d]", nrow(value), ncol(value)),
      type = "data.frame",
      expandable = ncol(value) > 0L
    ))
  }
  if (is.list(value)) {
    return(list(
      value = sprintf("list [%d]", length(value)),
      type = "list",
      expandable = length(value) > 0L
    ))
  }
  if (is.atomic(value)) {
    shown <- utils::head(value, 5L)
    text <- paste(format(shown), collapse = ", ")
    if (length(value) > length(shown)) {
      text <- paste0(text, ", ...")
    }
    return(list(
      value = text,
      type = paste(class(value), collapse = "/"),
      expandable = FALSE
    ))
  }
  list(
    value = paste(capture.output(str(value, max.level = 0L)), collapse = " "),
    type = paste(class(value), collapse = "/"),
    expandable = FALSE
  )
}

variable_from_value <- function(name, value) {
  preview <- preview_value(value)
  ref <- 0L
  if (preview$expandable) {
    ref <- new_var_ref(value, kind = "children")
  }
  list(
    name = name,
    value = preview$value,
    type = preview$type,
    variablesReference = ref
  )
}

variables_from_env <- function(env, formals = character()) {
  names <- sort(ls(env, all.names = TRUE))
  lapply(names, function(name) {
    if (bindingIsActive(name, env)) {
      return(list(
        name = name,
        value = "<active binding>",
        type = "active binding",
        variablesReference = 0L
      ))
    }
    if (name %in% formals) {
      return(list(
        name = name,
        value = "<promise>",
        type = "promise",
        variablesReference = 0L
      ))
    }
    value <- tryCatch(get(name, envir = env, inherits = FALSE), error = identity)
    if (inherits(value, "error")) {
      return(list(
        name = name,
        value = paste0("<error: ", conditionMessage(value), ">"),
        type = "error",
        variablesReference = 0L
      ))
    }
    variable_from_value(name, value)
  })
}

variables_from_children <- function(value) {
  names <- names(value)
  if (is.null(names)) {
    names <- as.character(seq_along(value))
  }
  lapply(seq_along(value), function(index) {
    variable_from_value(names[[index]], value[[index]])
  })
}

handle_initialize <- function(request) {
  send_response(request, list(
    supportsConfigurationDoneRequest = TRUE,
    supportsEvaluateForHovers = TRUE,
    supportsStepBack = FALSE,
    supportsSetVariable = FALSE,
    supportsConditionalBreakpoints = FALSE,
    supportsHitConditionalBreakpoints = FALSE,
    supportsLogPoints = FALSE,
    exceptionBreakpointFilters = list()
  ))
  send_event("initialized")
}

handle_set_breakpoints <- function(request) {
  args <- request$arguments %||% list()
  source <- args$source %||% list()
  path_source <- as_path_key(source$path %||% "")
  breakpoints <- args$breakpoints %||% list()
  if (is.null(breakpoints) || !length(breakpoints)) {
    lines <- integer()
  } else {
    lines <- vapply(breakpoints, function(bp) as.integer(bp$line), integer(1))
  }

  .state$breakpoints[[path_source]] <- lines
  body <- list(breakpoints = lapply(seq_along(lines), function(index) {
    list(
      id = index,
      verified = TRUE,
      line = lines[[index]],
      source = list(name = basename(path_source), path = path_source)
    )
  }))
  send_response(request, body)
}

handle_stack_trace <- function(request) {
  frames <- .state$frames
  send_response(request, list(
    stackFrames = frames,
    totalFrames = length(frames)
  ))
}

handle_scopes <- function(request) {
  frame_id <- as.character(request$arguments$frameId)
  env <- .state$frame_envs[[frame_id]]
  if (is.null(env)) {
    send_response(request, list(scopes = list()))
    return()
  }

  ref <- new_var_ref(env, kind = "env", fields = list(frame_id = frame_id))
  send_response(request, list(scopes = list(list(
    name = "Locals",
    variablesReference = ref,
    expensive = FALSE
  ))))
}

handle_variables <- function(request) {
  ref <- as.character(request$arguments$variablesReference)
  entry <- .state$vars[[ref]]
  if (is.null(entry)) {
    send_response(request, list(variables = list()))
    return()
  }

  if (entry$kind == "env") {
    variables <- variables_from_env(
      entry$value,
      .state$frame_formals[[entry$frame_id]] %||% character()
    )
  } else {
    variables <- variables_from_children(entry$value)
  }
  send_response(request, list(variables = variables))
}

handle_evaluate <- function(request) {
  args <- request$arguments %||% list()
  frame_id <- as.character(args$frameId %||% "")
  env <- .state$frame_envs[[frame_id]] %||% .GlobalEnv
  result <- tryCatch(
    eval(parse(text = args$expression %||% ""), envir = env),
    error = identity
  )
  if (inherits(result, "error")) {
    send_response(request, success = FALSE, message = conditionMessage(result))
    return()
  }

  preview <- preview_value(result)
  ref <- if (preview$expandable) new_var_ref(result, kind = "children") else 0L
  send_response(request, list(
    result = preview$value,
    type = preview$type,
    variablesReference = ref
  ))
}

request_console_input <- function(request, browser_command) {
  if (!isTRUE(.state$stopped)) {
    send_response(request, success = FALSE, message = "R is not stopped")
    return()
  }
  if (!is.null(.state$pending_console_input)) {
    send_response(request, success = FALSE, message = "console input is pending")
    return()
  }

  id <- next_seq()
  .state$pending_console_input <- list(
    id = id,
    request = request,
    browser_command = browser_command,
    prompt = "browser",
    generation = .state$stop_generation
  )
  send_event("r_console_input", list(
    id = id,
    text = browser_command,
    newline = TRUE,
    prompt = "browser",
    generation = .state$stop_generation
  ))
}

handle_console_input_ack <- function(request) {
  success <- isTRUE((request$arguments %||% list())$success)
  pending <- .state$pending_console_input
  send_response(request)
  if (is.null(pending)) {
    return()
  }

  .state$pending_console_input <- NULL
  if (success) {
    send_response(pending$request, list(allThreadsContinued = TRUE))
    send_event("continued", list(threadId = 1L, allThreadsContinued = TRUE))
    clear_stop_state()
  } else {
    send_response(
      pending$request,
      success = FALSE,
      message = "failed to enqueue console input"
    )
  }
}

handle_disconnect <- function(request) {
  send_response(request)
  send_event("terminated")
  .state$terminated <- TRUE
  .state$pending_console_input <- NULL
  clear_stop_state()
  close_client()
}

dispatch_request <- function(request) {
  command <- request$command
  switch(command,
    initialize = handle_initialize(request),
    attach = send_response(request),
    configurationDone = send_response(request),
    setBreakpoints = handle_set_breakpoints(request),
    setExceptionBreakpoints = send_response(request, list(breakpoints = list())),
    threads = send_response(request, list(threads = list(list(id = 1L, name = "R")))),
    stackTrace = handle_stack_trace(request),
    scopes = handle_scopes(request),
    variables = handle_variables(request),
    evaluate = handle_evaluate(request),
    continue = request_console_input(request, "c"),
    `next` = request_console_input(request, "n"),
    stepIn = request_console_input(request, "s"),
    stepOut = request_console_input(request, "f"),
    rConsoleInputAck = handle_console_input_ack(request),
    disconnect = handle_disconnect(request),
    terminate = handle_disconnect(request),
    send_response(request, success = FALSE,
                  message = paste("unsupported request:", command))
  )
}

process_requests <- function(timeout = 0, limit = 50L) {
  accept_client()
  for (i in seq_len(limit)) {
    request <- tryCatch(read_dap_message(timeout = timeout), error = identity)
    if (inherits(request, "error")) {
      close_client()
      return(FALSE)
    }
    if (is.null(request)) {
      return(TRUE)
    }
    if (identical(request$type, "request")) {
      dispatch_request(request)
    }
    timeout <- 0
  }
  TRUE
}

schedule_poll <- function() {
  if (!isTRUE(.state$running)) {
    return()
  }
  later::later(function() {
    if (isTRUE(.state$running) && !isTRUE(.state$stopped)) {
      try(process_requests(timeout = 0), silent = TRUE)
      schedule_poll()
    }
  }, delay = 0.05)
}

write_metadata <- function() {
  metadata <- list(
    metadata_version = 1L,
    protocol_version = 1L,
    backend = "classic",
    pid = Sys.getpid(),
    host = .state$host,
    port = .state$port,
    path_workspace = .state$path_workspace,
    started_at = as.numeric(Sys.time())
  )
  jsonlite::write_json(metadata, .state$path_connection, auto_unbox = TRUE)
  metadata
}

insert_browser_breakpoints <- function(path_source, lines) {
  breakpoints <- breakpoint_lines_for(path_source)
  if (!length(breakpoints)) {
    return(lines)
  }
  for (line in breakpoints) {
    if (line >= 1L && line <= length(lines)) {
      lines[[line]] <- paste0("browser(); ", lines[[line]])
    }
  }
  lines
}
