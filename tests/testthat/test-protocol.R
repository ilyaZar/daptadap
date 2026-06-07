test_that("fake DAP client can initialize", {
  path_connection <- tempfile()
  metadata <- daptadap::dap_start(path_connection = path_connection)
  on.exit(daptadap::dap_stop(), add = TRUE)

  con <- open_dap_client(metadata)
  on.exit(close(con), add = TRUE)

  response <- send_request(con, list(
    seq = 1L,
    type = "request",
    command = "initialize",
    arguments = list()
  ))
  event <- read_dap_message(con)

  expect_equal(response$type, "response")
  expect_true(response$success)
  expect_equal(response$command, "initialize")
  expect_equal(event$type, "event")
  expect_equal(event$event, "initialized")
})

test_that("fake DAP client can set breakpoints", {
  path <- tempfile(fileext = ".R")
  writeLines(c("x <- 1", "y <- x + 1", "y"), path)

  metadata <- daptadap::dap_start(path_connection = tempfile())
  on.exit(daptadap::dap_stop(), add = TRUE)

  con <- open_dap_client(metadata)
  on.exit(close(con), add = TRUE)

  send_request(con, list(
    seq = 1L,
    type = "request",
    command = "initialize",
    arguments = list()
  ))
  read_dap_message(con)

  response <- send_request(con, list(
    seq = 2L,
    type = "request",
    command = "setBreakpoints",
    arguments = list(
      source = list(path = path),
      breakpoints = list(list(line = 2L), list(line = 3L))
    )
  ))

  lines <- vapply(
    response$body$breakpoints,
    function(breakpoint) breakpoint$line,
    integer(1)
  )
  verified <- vapply(
    response$body$breakpoints,
    function(breakpoint) breakpoint$verified,
    logical(1)
  )

  expect_equal(response$type, "response")
  expect_true(response$success)
  expect_equal(response$command, "setBreakpoints")
  expect_equal(lines, c(2L, 3L))
  expect_true(all(verified))
})
