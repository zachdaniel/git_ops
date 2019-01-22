# Change Log

All notable changes to this project will be documented in this file.
See [Conventional Commits](Https://conventionalcommits.org) for commit guidelines.

<!-- changelog -->

## [v0.6.0](https://github.com/zachdaniel/git_ops/compare/0.5.0...v0.6.0) (2019-1-22)




### Features:

* test: add tests for version_tag_prefix

* dry_run release option

### Bug Fixes:

* allow no prfexix

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
