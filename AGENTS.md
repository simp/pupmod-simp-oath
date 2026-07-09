# AGENTS.md

This file provides guidance to AI agents when working with code in this repository.

## What this module does

`simp-oath` is a SIMP Puppet module that installs and configures OATH-based
one-time-password (TOTP/HOTP) support for PAM. It installs the `oathtool`
command-line utility unconditionally, and — when both PAM and OATH are enabled
— installs `liboath`/`pam_oath` and manages the `pam_oath.so` configuration
files under `/etc/liboath` (`users.oath`, `exclude_users.oath`,
`exclude_groups.oath`). Those files are assembled from Hiera data via `concat`
fragments, with the correct SELinux contexts applied so `pam_oath` can read
them (RPM ships no defaults) (`manifests/config.pp:1-19`).

The module is conservative about turning itself on. The main class installs
only `oathtool` unless **both** `$pam` and `$oath` are true; only then does it
pull in the package install and config classes (`manifests/init.pp:64-74`).
The intended enable path is the global catalyst `simp_options::oath: true` in
Hiera (`manifests/init.pp:57`).

### Business logic

- **`oath` (`manifests/init.pp:56-75`)** — Public entry class (not
  `assert_private()`'d; consumers `include 'oath'`). Parameters
  (`init.pp:56-63`):
  - `$oath` (`Boolean`) — master switch for the `pam_oath`/`liboath` side.
    Defaults to `simplib::lookup('simp_options::oath', { 'default_value' => false })`
    (`init.pp:57`).
  - `$pam` (`Boolean`) — whether PAM is configured on the system; `pam_oath` is
    only installed when this is true. Defaults to
    `simplib::lookup('simp_options::pam', { 'default_value' => true })`
    (`init.pp:58`). Docstring warns that forcing this true will pull in PAM as a
    dependency of `pam_oath` (`init.pp:17-18`).
  - `$package_ensure` (`Simplib::PackageEnsure`) — ensure value for every
    package. Defaults to
    `simplib::lookup('simp_options::package_ensure', { 'default_value' => 'present' })`
    (`init.pp:59`).
  - `$oath_users` (`Optional[Hash]`, default `undef`) — user→token map that
    drives `users.oath`; when `undef`, that file is not managed (`init.pp:60`).
  - `$oath_exclude_users` (`Optional[Array]`, default `undef`) — drives
    `exclude_users.oath` (`init.pp:61`).
  - `$oath_exclude_groups` (`Optional[Array]`, default `undef`) — drives
    `exclude_groups.oath` (`init.pp:62`).

  Control flow: always `include 'oath::oathtool_install'` (`init.pp:64`). If
  `$pam and $oath`, call `simplib::assert_metadata($module_name)`, then
  `include 'oath::install'` and `include 'oath::config'`, ordered
  `Class['oath::install'] -> Class['oath::config']` (`init.pp:66-74`).

- **`oath::oathtool_install` (`manifests/oathtool_install.pp:6-10`)** — private
  (`assert_private()`); `package { 'oathtool' }` at `$oath::package_ensure`.

- **`oath::install` (`manifests/install.pp:6-12`)** — private
  (`assert_private()`); `package { 'liboath' }` and `package { 'pam_oath' }` at
  `$oath::package_ensure`.

- **`oath::config` (`manifests/config.pp:9-103`)** — private
  (`assert_private()`). Creates `/etc/liboath` as a directory with
  `seluser => system_u`, `seltype => var_auth_t` (`config.pp:13-19`). For each
  of the three managed files it creates a `concat` container (mode `0600`,
  same SELinux context) and iterates the corresponding Hiera value to declare
  fragment defines; when a value is `undef` it emits a `warning()` that the file
  is **not** being managed rather than failing (`config.pp:21-102`). For
  `oath_users`, a `'defaults'` key in the hash is split out and applied as
  per-resource defaults to `oath::config::user` (`config.pp:76-98`).

- **`oath::config::user` (`manifests/config/user.pp:23-43`)** — public define.
  Validates `$user` (`Array[String[1]]`), `$token_type`
  (`Pattern[/^HOTP((\/T\d+)?(\/\d+)?)(\s+)?$/]`), `$pin`
  (`Variant[Enum['-','+'], Integer[0,99999999]]`), and `$secret_key`
  (`Pattern[/^(..)+(\s+)?$/]` — even-length) (`config/user.pp:24-27`). Emits a
  tab-separated `concat::fragment` into `/etc/liboath/users.oath`
  (`config/user.pp:37-42`). `include 'oath::config'` at the top
  (`config/user.pp:29`).

- **`oath::config::exclude_user` (`manifests/config/exclude_user.pp:6-20`)** and
  **`oath::config::exclude_group` (`manifests/config/exclude_group.pp:6-20`)** —
  public defines; each validates its single name arg with
  `Pattern[/^[a-zA-Z0-9\-_]+(\s+)?$/]`, strips it, and writes a one-line
  `concat::fragment` into the respective exclude file.

### Gotchas / non-obvious details

- **`oathtool` is always installed; `pam_oath`/`liboath` are gated.** Including
  `oath` with defaults installs only `oathtool` — the PAM side requires both
  `$pam` (default true) and `$oath` (default false) to be true
  (`init.pp:64-74`), so the effective default is "oathtool only." Set
  `simp_options::oath: true` to enable the rest.
- **Missing Hiera → a warning, not managed files.** If `oath_users`,
  `oath_exclude_users`, or `oath_exclude_groups` are `undef`, `oath::config`
  logs a `warning()` and does not manage that file (`config.pp:37-39,58-59,100-102`).
- **The shipped `data/common.yaml` contains EXAMPLE secrets.** It defines
  `oath::oath_users` for `root`/`simp` with placeholder `secret_key: '000001'`
  and excludes `root`/`simp` (`data/common.yaml:17-31`). The file itself warns
  these keys must be changed on a production system — do not treat them as real
  defaults.
- **`secret_key` must be even length.** The `Pattern[/^(..)+(\s+)?$/]` type on
  `oath::config::user` enforces even length; odd-length keys can break OTP
  generators (`config/user.pp:20-21,27`).
- **`'defaults'` is a reserved key in `oath_users`.** A `'defaults'` hash entry
  is not a user — it is stripped out and applied as resource defaults to the
  remaining users (`config.pp:76-98`).
- **`simp/simp_options` is NOT a declared dependency** in `metadata.json`, yet
  the manifest consumes the `simp_options::*` seam via `simplib::lookup`
  (provided by `simp/simplib`). There is no `simp.optional_dependencies` block.
- **Private classes are referenced with the legacy `$::oath::` top-scope
  syntax** in `install.pp`/`oathtool_install.pp` (`install.pp:9-10`,
  `oathtool_install.pp:9`) — match the surrounding style if editing there.
- **`.fixtures.yml` pulls `sshkeys_core`** as a fixture even though nothing in
  `manifests/` uses it (`.fixtures.yml`) — likely a baseline leftover; it is not
  a runtime dependency.

## The `simp_options` / `simplib::lookup` seam

This is the module's real business-logic seam (the natural target for a
lookup-path unit test). All calls are in `manifests/init.pp`:

| Line | Key | `default_value` |
|------|-----|-----------------|
| `init.pp:57` | `simp_options::oath` | `false` |
| `init.pp:58` | `simp_options::pam` | `true` |
| `init.pp:59` | `simp_options::package_ensure` | `'present'` |

Keep routing SIMP feature toggles through `simplib::lookup('simp_options::*', {
'default_value' => ... })` with an explicit default rather than assuming
`simp_options` is included.

## Dependencies

Module dependencies (from `metadata.json`):

- `puppetlabs/concat` `>= 6.4.0 < 10.0.0` (provides the `concat` / `concat::fragment`
  types that assemble the `/etc/liboath/*.oath` files)
- `simp/simplib` `>= 4.9.0 < 5.0.0` (provides `simplib::lookup`,
  `simplib::assert_metadata`, and the `Simplib::PackageEnsure` type)
- `puppetlabs/stdlib` `>= 8.0.0 < 10.0.0` (provides `strip()`)

There is **no** `simp.optional_dependencies` block in `metadata.json`.

Fixture-only dependencies (from `.fixtures.yml`, present for test compilation,
not runtime deps): `sshkeys_core` (plus the three runtime deps above are also
checked out as fixtures). Note `simp_options` is consumed via the
`simplib::lookup` seam but is not declared in `metadata.json` or `.fixtures.yml`.

Runtime requirement (from `metadata.json` `requirements`): `puppet
>= 7.0.0 < 9.0.0`. (SIMP is migrating Puppet → OpenVox; when
`metadata.json` switches this to `openvox`, update this line to match.)

Supported OS matrix (from `metadata.json`): CentOS 7/8/9; RedHat 7/8/9;
OracleLinux 7/8/9; Rocky 8/9; AlmaLinux 8/9.

## Repository layout

- `manifests/init.pp` — the `oath` public class (entry point / parameters).
- `manifests/oathtool_install.pp`, `manifests/install.pp` — private package
  install classes.
- `manifests/config.pp` — private config class (SELinux, concat containers,
  Hiera iteration).
- `manifests/config/user.pp`, `manifests/config/exclude_user.pp`,
  `manifests/config/exclude_group.pp` — public defines that emit `concat`
  fragments.
- `data/common.yaml` — example `oath_users` / exclude data (placeholder secrets).
- `hiera.yaml` — module data hierarchy (v5): `os/%{facts.os.family}.yaml` →
  `common.yaml`.
- `metadata.json` — deps, OS matrix, Puppet requirement.
- `spec/classes/00_init_spec.rb`, `spec/classes/10_config_check_spec.rb` —
  rspec-puppet unit tests.
- `spec/acceptance/suites/default/00_default_spec.rb` — beaker acceptance suite
  (applies `class { 'oath': }`, checks idempotency and that `oathtool` is
  installed); nodesets under `spec/acceptance/nodesets/`.
- `REFERENCE.md` — generated Puppet Strings reference.
- No `types/`, `lib/`, or `templates/` — this module has no custom data types,
  Ruby types/providers/functions/facts, or templates. Every custom type and
  function it uses comes from the dependencies above.
- **Acceptance is NOT wired into CI:** `.github/workflows/pr_tests.yml` has
  `puppet-syntax`, `puppet-style`, `ruby-style`, `file-checks`, `releng-checks`,
  and `spec-tests` (Puppet 7.x and 8.x) jobs, but **no `acceptance` job** — the
  beaker suite under `spec/acceptance/` runs only when invoked manually.

## Common commands

```sh
# Install dependencies
bundle install

# Run all unit tests
bundle exec rake spec

# Run a single class spec
bundle exec rspec spec/classes/00_init_spec.rb

# Puppet lint
bundle exec rake lint

# Ruby lint
bundle exec rake rubocop

# Regenerate REFERENCE.md from puppet-strings docstrings
puppet strings generate --format markdown --out REFERENCE.md

# Run the default beaker acceptance suite (not run in CI; needs a hypervisor)
bundle exec rake beaker:suites[default]
```

Relevant gem pins (from `Gemfile`): `puppetlabs_spec_helper ~> 8.0.0`,
`simp-rake-helpers ~> 5.24.0`, `simp-rspec-puppet-facts ~> 4.0.0`,
`simp-beaker-helpers ~> 2.0.0`. Rubocop is pinned to `~> 1.88.0`. The tested
Puppet range is `>= 7 < 9`. `spec/spec_helper.rb` uses
`require 'puppetlabs_spec_helper/module_spec_helper'`.

## Conventions

- Preserve the `@summary` / `@param` puppet-strings docstrings on the class and
  defines — they drive `REFERENCE.md`. Regenerate `REFERENCE.md` after changing
  docs or parameters.
- Keep private classes (`oath::install`, `oath::oathtool_install`,
  `oath::config`) guarded with `assert_private()`; do not `include` them
  directly from outside the module.
- Continue routing SIMP feature toggles through
  `simplib::lookup('simp_options::*', { 'default_value' => ... })` rather than
  assuming `simp_options` is included.
- Validate user-supplied config values with the existing `Pattern`/`Variant`
  data types on the `oath::config::*` defines rather than accepting free text.
- `Gemfile`, `spec/spec_helper.rb`, and `.github/workflows/pr_tests.yml` carry a
  **puppetsync** notice — they are baseline-managed and the next sync overwrites
  local edits. Push changes to those files upstream to the baseline, not here.
- Match the existing 2-space Puppet indentation and aligned-arrow parameter
  style used in `manifests/`.
