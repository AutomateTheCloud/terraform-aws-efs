# Changelog

All notable changes to this module are listed here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the module uses [semantic versioning](https://semver.org/): a new major version means callers must change their code.

## [Unreleased]

## [1.0.1] - 2026-10-06

### Fixed

- `metadata.security_group` no longer has `ingress` and `egress`. They were read when the group was created, before the module's rules were attached, so the first plan after a create showed the output changing. The rules are in `metadata.vpc_security_group_ingress_rule`.

### Changed

- The copyright year in `NOTICE` and the file headers is now 2026, the year the module was rebuilt and released as 1.0.0.
- `CLAUDE.md`, the working rules shared by every Automate the Cloud module, adds the lessons learned while rebuilding the modules.

## [1.0.0] - 2026-10-05

Initial release.

### Added

- An EFS file system with secure defaults: always encrypted, TLS required for every client, and no network access until you allow a source.
- Mount targets keyed by names you choose, and a security group that allows NFS from IPv4 and IPv6 ranges, security groups and prefix lists.
- A file system policy that requires TLS, and your own statements through `policy.source_policy_documents`.
- Bursting, Elastic and Provisioned throughput, lifecycle transitions to Infrequent Access and Archive, and automatic backups with AWS Backup.
- `region`, to create the file system in a Region other than the provider's.
- A `metadata` output with everything the module created.
- Offline tests, and examples for a basic file system and most options together.

[Unreleased]: https://github.com/AutomateTheCloud/terraform-aws-efs/compare/v1.0.1...HEAD
[1.0.1]: https://github.com/AutomateTheCloud/terraform-aws-efs/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/AutomateTheCloud/terraform-aws-efs/releases/tag/v1.0.0
