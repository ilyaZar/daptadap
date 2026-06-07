<h1 align="center">daptadap</h1>

<p align="center">
  <a href="https://github.com/ilyaZar/daptadap/actions/workflows/R-CMD-check.yaml"><img src="https://img.shields.io/github/actions/workflow/status/ilyaZar/daptadap/R-CMD-check.yaml?branch=master&style=flat-square&logo=github&logoColor=white&label=CI&labelColor=2a7e3b&color=1b5e2a" alt="CI"></a>
  <a href="https://codecov.io/gh/ilyaZar/daptadap"><img src="https://img.shields.io/codecov/c/github/ilyaZar/daptadap/master?style=flat-square&logo=codecov&logoColor=white&labelColor=6b3fa0&color=4b2d73" alt="code coverage"></a>
  <a href="https://github.com/ilyaZar/daptadap"><img src="https://img.shields.io/github/r-package/v/ilyaZar/daptadap/master?filename=DESCRIPTION&style=flat-square&label=version&labelColor=4a999d&color=346c6e" alt="package version"></a>
  <a href="https://www.r-project.org"><img src="https://img.shields.io/badge/R-package-264a6e?style=flat-square&logo=r&logoColor=white&labelColor=276DC3" alt="R package"></a>
  <a href="https://github.com/ilyaZar/daptadap/blob/master/LICENSE.md"><img src="https://img.shields.io/badge/license-MIT-446a30?style=flat-square&logo=opensourceinitiative&logoColor=white&labelColor=629944" alt="license MIT"></a>
</p>

A small Debug Adapter Protocol helper for neovim-driven R console debugging.

`daptadap` runs inside an interactive R process and exposes enough DAP
behavior for a Neovim DAP client to drive breakpoints, stack frames, locals,
evaluation, and stepping through R's `browser()` machinery.

## Scope

This package is intentionally narrow. It is not a replacement for the full
VS Code R debugger stack, and it is not a standalone editor integration. The
current target is the classic `R.nvim` console workflow used by `nvim-dap-r`.

The package owns the R-side helper:

- starts a local DAP socket from the R process
- writes connection metadata for the editor-side DAP client
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

Editor integrations usually call these functions for you. A minimal manual
session looks like this:

```r
library(daptadap)

metadata <- dap_start()
metadata

dap_debug_source("path/to/script.R")
dap_stop()
```

`dap_start()` writes connection metadata so the editor can attach a DAP client.
`dap_debug_source()` then sources a file while honoring breakpoints registered
by that client.

## Public API

| Function             | Purpose                                      |
|:---------------------|:---------------------------------------------|
| `dap_start()`        | Start the in-process DAP helper              |
| `dap_stop()`         | Stop the helper and remove connection state   |
| `dap_pump()`         | Process DAP requests at an R browser stop    |
| `dap_debug_source()` | Source an R file with DAP breakpoints active |

## Development

Run the test suite:

```sh
Rscript -e 'testthat::test_dir("tests/testthat")'
```

Run a package check:

```sh
R CMD build .
R CMD check --no-manual --no-build-vignettes daptadap_0.0.1.tar.gz
```

Run local coverage:

```sh
Rscript -e 'covr::package_coverage()'
```

## Status

`daptadap` is early-stage infrastructure for R debugging UX experiments. The
current behavior is tested with fake DAP clients and interactive Neovim
workflows, but the DAP surface is deliberately limited to the features needed
by the current editor integration.

## License

MIT. See [LICENSE.md](LICENSE.md).
