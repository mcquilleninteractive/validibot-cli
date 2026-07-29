# Releasing validibot-cli

Releases use a signed tag, GitHub Actions, and PyPI trusted publishing. No
maintainer should upload a distribution from a workstation or store a PyPI API
token in GitHub.

## Release guarantees

For every release, the workflow:

1. checks out the exact GitHub Release tag and verifies its SSH signature
   against [`.allowed_signers`](.allowed_signers);
2. requires an exact `vX.Y.Z` tag matching the version in `pyproject.toml`;
3. recreates the locked dependency environment and builds one wheel and one
   source distribution;
4. validates both distributions with Twine;
5. generates CycloneDX JSON and XML SBOMs and SHA-256 checksums;
6. creates a GitHub SBOM attestation covering both distributions;
7. attaches the SBOMs and checksums to the GitHub Release; and
8. publishes the same distributions through PyPI OIDC trusted publishing,
   which creates PyPI provenance attestations.

The `pypi` GitHub environment is restricted to version tags. Publishing is
therefore release-only: there is no manual-dispatch or TestPyPI route in the
production workflow.

## Maintainer procedure

1. Update `pyproject.toml`, `uv.lock`, and `CHANGELOG.md` in a pull request.
2. Merge the pull request after the required `ci` check passes.
3. Update local `main`, then run:

   ```console
   just release X.Y.Z
   ```

The recipe refuses dirty trees, non-`main` branches, and a local branch that
does not exactly match `origin/main`. It runs the local release gate, creates
and locally verifies a signed tag, pushes that tag, and publishes the GitHub
Release.

Do not move or replace a published version tag. If a release workflow fails
because its committed release code is defective, fix the pipeline and publish
the next patch version.

## Consumer verification

Verify a checked-out tag:

```console
git config gpg.format ssh
git config gpg.ssh.allowedSignersFile .allowed_signers
git verify-tag vX.Y.Z
```

Verify the hashes after downloading the release assets into one directory:

```console
sha256sum --check SHA256SUMS
```

Verify the GitHub-hosted SBOM attestation for a downloaded wheel:

```console
gh attestation verify validibot_cli-X.Y.Z-py3-none-any.whl \
  --repo mcquilleninteractive/validibot-cli \
  --predicate-type https://cyclonedx.org/bom
```

Verify PyPI's provenance attestation:

```console
uvx --from pypi-attestations pypi-attestations verify pypi \
  pypi:validibot_cli-X.Y.Z-py3-none-any.whl \
  --repository https://github.com/mcquilleninteractive/validibot-cli
```
