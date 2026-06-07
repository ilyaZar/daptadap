test_that("public API is scoped to DAP helpers", {
  exports <- getNamespaceExports("daptadap")

  expect_setequal(
    exports,
    c("dap_start", "dap_stop", "dap_pump", "dap_debug_source")
  )
  expect_false("start" %in% exports)
  expect_false("stop" %in% exports)
  expect_false("debug_source" %in% exports)
})

test_that("dap_start writes metadata and dap_stop cleans up", {
  path_connection <- tempfile()
  path_workspace <- tempdir()

  metadata <- daptadap::dap_start(
    path_connection = path_connection,
    path_workspace = path_workspace
  )
  on.exit(daptadap::dap_stop(), add = TRUE)

  expect_true(file.exists(path_connection))
  expect_equal(metadata$backend, "classic")
  expect_equal(metadata$host, "127.0.0.1")
  expect_true(is.numeric(metadata$port))
  expect_gt(metadata$port, 0)

  decoded <- jsonlite::fromJSON(path_connection)
  expect_equal(decoded$backend, "classic")
  expect_equal(decoded$host, metadata$host)
  expect_equal(decoded$port, metadata$port)
  expect_equal(decoded$path_workspace, path_workspace)

  daptadap::dap_stop()
  expect_false(file.exists(path_connection))
})

test_that("dap_pump is inert without a running helper", {
  daptadap::dap_stop()

  expect_false(daptadap::dap_pump())
})

test_that("breakpoint transformation inserts browser calls", {
  ns <- asNamespace("daptadap")
  reset <- get("reset_session_state", envir = ns)
  state <- get(".state", envir = ns)
  as_path_key <- get("as_path_key", envir = ns)
  insert_browser_breakpoints <- get("insert_browser_breakpoints", envir = ns)

  reset()
  on.exit(reset(), add = TRUE)

  path <- tempfile(fileext = ".R")
  key <- as_path_key(path)
  state$breakpoints[[key]] <- 2L

  lines <- c("x <- 1", "y <- x + 1")
  transformed <- insert_browser_breakpoints(path, lines)

  expect_equal(transformed[[1]], "x <- 1")
  expect_equal(transformed[[2]], "browser(); y <- x + 1")
})
