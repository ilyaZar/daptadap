<h1 align="center">daptadap</h1>

<p align="center">
  <a href="https://github.com/ilyaZar/daptadap/actions/workflows/R-CMD-check.yaml"><img src="https://img.shields.io/github/actions/workflow/status/ilyaZar/daptadap/R-CMD-check.yaml?branch=master&style=flat-square&logo=github&logoColor=white&label=CI&labelColor=2a7e3b&color=1b5e2a" alt="CI"></a>
  <a href="https://codecov.io/gh/ilyaZar/daptadap"><img src="https://img.shields.io/codecov/c/github/ilyaZar/daptadap/master?style=flat-square&logo=codecov&logoColor=white&labelColor=6b3fa0&color=4b2d73" alt="code coverage"></a>
  <a href="https://github.com/ilyaZar/daptadap"><img src="https://img.shields.io/github/r-package/v/ilyaZar/daptadap/master?filename=DESCRIPTION&style=flat-square&label=version&labelColor=4a999d&color=346c6e" alt="package version"></a>
  <a href="https://www.r-project.org"><img src="https://img.shields.io/badge/R-package-264a6e?style=flat-square&logo=r&logoColor=white&labelColor=276DC3" alt="R package"></a>
  <a href="https://github.com/ilyaZar/daptadap/blob/master/LICENSE.md"><img src="https://img.shields.io/badge/license-MIT-446a30?style=flat-square&logo=data:image/svg%2bxml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAxNiAxNiI+PHBhdGggZmlsbD0id2hpdGUiIGQ9Ik04Ljc1Ljc1VjJoLjk4NWMuMzA0IDAgLjYwMy4wOC44NjcuMjMxbDEuMjkuNzM2Yy4wMzguMDIyLjA4LjAzMy4xMjQuMDMzaDIuMjM0YS43NS43NSAwIDAgMSAwIDEuNWgtLjQyN2wyLjExMSA0LjY5MmEuNzUuNzUgMCAwIDEtLjE1NC44MzhsLS41My0uNTMuNTI5LjUzMS0uMDAxLjAwMi0uMDAyLjAwMi0uMDA2LjAwNi0uMDA2LjAwNS0uMDEuMDEtLjA0NS4wNGMtLjIxLjE3Ni0uNDQxLjMyNy0uNjg2LjQ1QzE0LjU1NiAxMC43OCAxMy44OCAxMSAxMyAxMWE0LjQ5OCA0LjQ5OCAwIDAgMS0yLjAyMy0uNDU0IDMuNTQ0IDMuNTQ0IDAgMCAxLS42ODYtLjQ1bC0uMDQ1LS4wNC0uMDE2LS4wMTUtLjAwNi0uMDA2LS4wMDQtLjAwNHYtLjAwMWEuNzUuNzUgMCAwIDEtLjE1NC0uODM4TDEyLjE3OCA0LjVoLS4xNjJjLS4zMDUgMC0uNjA0LS4wNzktLjg2OC0uMjMxbC0xLjI5LS43MzZhLjI0NS4yNDUgMCAwIDAtLjEyNC0uMDMzSDguNzVWMTNoMi41YS43NS43NSAwIDAgMSAwIDEuNWgtNi41YS43NS43NSAwIDAgMSAwLTEuNWgyLjVWMy41aC0uOTg0YS4yNDUuMjQ1IDAgMCAwLS4xMjQuMDMzbC0xLjI4OS43MzdjLS4yNjUuMTUtLjU2NC4yMy0uODY5LjIzaC0uMTYybDIuMTEyIDQuNjkyYS43NS43NSAwIDAgMS0uMTU0LjgzOGwtLjUzLS41My41MjkuNTMxLS4wMDEuMDAyLS4wMDIuMDAyLS4wMDYuMDA2LS4wMTYuMDE1LS4wNDUuMDRjLS4yMS4xNzYtLjQ0MS4zMjctLjY4Ni40NUM0LjU1NiAxMC43OCAzLjg4IDExIDMgMTFhNC40OTggNC40OTggMCAwIDEtMi4wMjMtLjQ1NCAzLjU0NCAzLjU0NCAwIDAgMS0uNjg2LS40NWwtLjA0NS0uMDQtLjAxNi0uMDE1LS4wMDYtLjAwNi0uMDA0LS4wMDR2LS4wMDFhLjc1Ljc1IDAgMCAxLS4xNTQtLjgzOEwyLjE3OCA0LjVIMS43NWEuNzUuNzUgMCAwIDEgMC0xLjVoMi4yMzRhLjI0OS4yNDkgMCAwIDAgLjEyNS0uMDMzbDEuMjg4LS43MzdjLjI2NS0uMTUuNTY0LS4yMy44NjktLjIzaC45ODRWLjc1YS43NS43NSAwIDAgMSAxLjUgMFptMi45NDUgOC40NzdjLjI4NS4xMzUuNzE4LjI3MyAxLjMwNS4yNzNzMS4wMi0uMTM4IDEuMzA1LS4yNzNMMTMgNi4zMjdabS0xMCAwYy4yODUuMTM1LjcxOC4yNzMgMS4zMDUuMjczczEuMDItLjEzOCAxLjMwNS0uMjczTDMgNi4zMjdaIi8+PC9zdmc+&labelColor=629944" alt="license MIT"></a>
</p>

A small Debug Adapter Protocol helper for neovim-driven R console debugging.

`daptadap` runs inside an interactive R process and exposes DAP behavior for
the Neovim debugging workflow built around
[`R.nvim`](https://github.com/R-nvim/R.nvim) and
[`nvim-dap-r`](https://github.com/ilyaZar/nvim-dap-r). It lets Neovim drive
breakpoints, stack frames, locals, evaluation, and stepping through R's
`browser()` machinery.

## Scope

This package is intentionally narrow. The current target is the classic
[`R.nvim`](https://github.com/R-nvim/R.nvim) console workflow used by
[`nvim-dap-r`](https://github.com/ilyaZar/nvim-dap-r).

The package owns the R-side helper:

- starts a local DAP socket from the R process
- writes connection metadata for the Neovim-side DAP client
- records DAP breakpoints
- sources R files with injected `browser()` stops
- reports stack frames, scopes, variables, and evaluated expressions
- forwards DAP stepping requests to the active R browser prompt

## Installation

```r
remotes::install_github("ilyaZar/daptadap")
```

For local development, install the checkout instead:

```r
pak::pak(".")
```

## Basic Flow

In normal use, `nvim-dap-r` calls these functions from Neovim. A minimal manual
session looks like this:

```r
library(daptadap)

metadata <- dap_start()
metadata

dap_debug_source("path/to/script.R")
dap_stop()
```

`dap_start()` writes connection metadata so Neovim can attach a DAP client.
`dap_debug_source()` then sources a file while honoring breakpoints registered
from Neovim.

## Public API

| Function             | Purpose                                      |
|:---------------------|:---------------------------------------------|
| `dap_start()`        | Start the in-process DAP helper              |
| `dap_stop()`         | Stop the helper and remove connection state   |
| `dap_pump()`         | Process DAP requests at an R browser stop    |
| `dap_debug_source()` | Source an R file with DAP breakpoints active |


## Status

`daptadap` is early-stage infrastructure for R debugging UX experiments. The
current behavior is roughly tested with fake DAP clients and interactive Neovim
workflows, but the DAP surface is deliberately limited to the features needed
by the current Neovim integration.

## License

MIT. See [LICENSE.md](LICENSE.md).
