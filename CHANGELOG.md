# Change Log

All notable changes to this project will be documented in this file.
See [Conventional Commits](Https://conventionalcommits.org) for commit guidelines.

<!-- changelog -->

## [v2.4.1](https://github.com/zachdaniel/git_ops/compare/v2.4.0...v2.4.1) (2021-01-08)




### Bug Fixes:

* remove heading hashes

* escape headers in tag message

## [v2.4.0](https://github.com/zachdaniel/git_ops/compare/v2.3.0...v2.4.0) (2021-01-08)




### Features:

* Include changelog notes to release tag message (#44)

## [v2.3.0](https://github.com/zachdaniel/git_ops/compare/v2.2.0...v2.3.0) (2020-12-28)




### Features:

* project_info_dotenv_format: Add the `dotenv` format for project info output. (#42)

## [v2.2.0](https://github.com/zachdaniel/git_ops/compare/v2.1.0...v2.2.0) (2020-12-15)




### Features:

* project_info_task: Add `git_ops.project_info` task. (#41)

* yes: Add `--yes` flag to `mix get_ops.release` (#38)

## [v2.1.0](https://github.com/zachdaniel/git_ops/compare/v2.0.2...v2.1.0) (2020-11-21)




### Features:

* yes: Add `--yes` flag to `mix get_ops.release` (#38)

## [v2.0.2](https://github.com/zachdaniel/git_ops/compare/v2.0.1...v2.0.2) (2020-11-19)




### Bug Fixes:

* messaging, and changelog ranges

## [v2.0.1](https://github.com/zachdaniel/git_ops/compare/v2.0.0...v2.0.1) (2020-07-24)




### Bug Fixes:

* messaging, and changelog ranges

## [v2.0.0](https://github.com/zachdaniel/git_ops/compare/1.1.3...v2.0.0) (2020-03-25)
### Breaking Changes:

* parse multiple messages



## [v1.1.3](https://github.com/zachdaniel/git_ops/compare/1.1.2...v1.1.3) (2020-03-17)




### Bug Fixes:

* use prefix on initial version



### Bug Fixes:

# Skipped for operational reasons


### Bug Fixes:

* Move version tag parsing logic

* Fix tag order from git tag function.

### Performance Improvements:

* Save an iteration in the map+join (#29)

## [v1.1.0](https://github.com/zachdaniel/git_ops/compare/1.0.0...v1.1.0) (2020-02-06)




### Features:

* commit message validation

## [v1.0.0](https://github.com/zachdaniel/git_ops/compare/0.6.4...v1.0.0) (2019-12-4)
### Breaking Changes:

* fail on prefixed `!` and support postfixed `!` (#22)



## [v0.6.4](https://github.com/zachdaniel/git_ops/compare/0.6.3...v0.6.4) (2019-12-4)




### Bug Fixes:

* --initial --dry-run creates Changelog (#18) (#19)

## [v0.6.3](https://github.com/zachdaniel/git_ops/compare/0.6.2...v0.6.3) (2019-8-19)




### Bug Fixes:

* explicitly add changelog

## [v0.6.2](https://github.com/zachdaniel/git_ops/compare/0.6.1...v0.6.2) (2019-8-19)




### Bug Fixes:

* log less, and accept unicode

## [v0.6.1](https://github.com/zachdaniel/git_ops/compare/0.6.0...v0.6.1) (2019-7-12)




### Improvements:

* support additional commit types by default

## [v0.6.0](https://github.com/zachdaniel/git_ops/compare/0.5.0...v0.6.0) (2019-1-22)




### Features:

* dry_run release option

### Bug Fixes:

* allow no prefix

* initial mix project check (#6)

## [v0.5.0](https://github.com/zachdaniel/git_ops/compare/0.4.1...v0.5.0) (2018-11-20)




### Features:

* calculate new version from project instead of tags

## [v0.4.1](https://github.com/zachdaniel/git_ops/compare/0.4.0...v0.4.1) (2018-11-16)




### Bug Fixes:

* correctly handle already parsed versions

## [v0.4.0](https://github.com/zachdaniel/git_ops/compare/0.4.0...v0.4.0) (2018-11-16)




### Features:

* Allow configuring a version prefix

### Bug Fixes:

* messaging and tag prefix

* prefix is the *first* argument to `parse!/2`

* fix error when version struct not expected

* resolve issue with comparing invalid version

## [0.3.4](https://github.com/zachdaniel/git_ops/compare/0.3.3...0.3.4) (2018-10-15)



### Bug Fixes:

* Fail better when mix_project is not set

## [0.3.3](https://github.com/zachdaniel/git_ops/compare/0.3.2...0.3.3) (2018-10-11)




### Bug Fixes:

* don't fail on unparseable commit during init

## [0.3.2](https://github.com/zachdaniel/git_ops/compare/0.3.2...0.3.2) (2018-10-11)




### Bug Fixes:

* depend on correct version of nimble_parsec

## [0.3.2](https://github.com/zachdaniel/git_ops/compare/0.3.1...0.3.2) (2018-10-11)




### Bug Fixes:

* depend on correct version of nimble_parsec

## [0.3.1](https://github.com/zachdaniel/git_ops/compare/0.3.0...0.3.1) (2018-10-5)




### Bug Fixes:

* use annotated tags

## [0.3.0](https://github.com/zachdaniel/git_ops/compare/0.2.3...0.3.0) (2018-10-5)




### Features:

* Support elixir 1.6

## [0.2.3](https://github.com/zachdaniel/git_ops/compare/0.2.2...0.2.3) (2018-10-5)




### Bug Fixes:

* remove branch from changelog

## [0.2.2](https://github.com/zachdaniel/git_ops/compare/master@0.2.1...master@0.2.2) (2018-10-5)




### Bug Fixes:

* inform of a safer tag push

## [0.2.1](https://github.com/zachdaniel/git_ops/compare/master@0.2.0...master@0.2.1) (2018-10-5)




### Bug Fixes:

* Explain git tag pushing

## [0.2.0](https://github.com/zachdaniel/git_ops/compare/master@0.1.1...master@0.2.0) (2018-10-5)
### Breaking Changes:

* Commit and tag, instead of tag and commit



## [0.1.1](https://github.com/zachdaniel/git_ops/compare/master@0.1.1-rc0...master@0.1.1) (2018-10-5)




### Bug Fixes:

* Changelog: Spacing between beginning and body

* Split version and changelog commits

## [0.1.1-rc0](https://github.com/zachdaniel/git_ops/compare/master@0.1.0...master@0.1.1-rc0) (2018-10-5)




### Bug Fixes:

* Split version and changelog commits

## [0.1.0](https://github.com/zachdaniel/git_ops/compare/master@0.1.0...master@0.1.0) (2018-10-5)
### Breaking Changes:

* Parser: finalize initial parser

* Parser: Adding a basic commit parser

BREAKING CHANGE: This header serves as an example.

This footer serves as another example.



### Features:

* Version: rc and pre_release functionality

* Manage readme + mix.exs version numbers

* Changelog: Add version incrementing

* changelog: initial changelog writing

* CLI: Add basic release command (non-functional as of yet)

### Bug Fixes:

* Version: Get version from mix on init

* allow --initial again

* newline headings

* spacing in changelog

* Changelog: Correctly tag new versions

* Changelog: Don't show ! in the changelog

* Changelog: semicolons in scopeless commits

* Changelog: Fix changelog formatting

* parser: recognize exlamation points
