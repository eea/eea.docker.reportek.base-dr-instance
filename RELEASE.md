# Releasing the base image

`eeacms/reportek-base-dr` is released by Jenkins, a release is a tag `<zope minor>-<N>` (ex: `5.14-3`) and `latest`.
Docker Hub autobuilds are not used.

1. A new Products.Reportek release updates `requirements.txt` on the `testing` branch.
2. Jenkins builds `testing` and runs the Products.Reportek tests, a smoke test (the container starts and answers) and a
   Trivy scan.
3. If they pass, **Promote to master** copies `requirements.txt` to `master` and creates the GitHub release, which
   creates the tag. The version is `<Zope minor from requirements.txt>-<N>`, `N` being the next free number.
   **Wait for the release** then waits (up to 30 minutes) for the image on Docker Hub, so a release that was never
   published turns the build red.
4. The tag build repeats the build, tests, smoke test and scan, then **Release** pushes `<version>` and `latest`
   (`latest` only for the newest release).
5. **Bump dependents** points the Dockerfile of `eea.docker.reportek.cdr-instance` and
   `eea.docker.reportek.bdr-instance` to the new image and creates their release, they publish themselves the same way.

## Releasing something that was committed directly to `master`

A commit on `master` is built and tested, but not released. To release it, create the GitHub release for the next
version, which creates the tag, and Jenkins publishes the image:

```
VERSION=$(./src/docker/calculate_next_release.sh)
gh release create "$VERSION" --repo eea/eea.docker.reportek.base-dr-instance --target master --title "$VERSION" --notes "Release $VERSION"
```

Only tags like `<zope minor>-<N>` (ex: `5.14-3`) release anything, and only when the tagged commit is on `master`.
Tag creation should be restricted to the Jenkins user and the admins (GitHub ruleset), a tag is a release.

## When something fails

- **The tag build failed after the tag exists:** the tag has no image (or no helm chart update). Re-run the build of
  the tag in Jenkins, publishing is safe to repeat. Do not delete and recreate the tag.
- **A release was published but is bad:** `latest` is only moved by the newest release, so it has to be moved back by hand:
  ```
  docker pull eeacms/reportek-base-dr:<good version>
  docker tag eeacms/reportek-base-dr:<good version> eeacms/reportek-base-dr:latest
  docker push eeacms/reportek-base-dr:latest
  ```
  Then fix forward with a new release. cdr and bdr were already bumped to the bad base: revert the `FROM` line there and release them.
- **Trivy fails the build:** it lists the fixable HIGH and CRITICAL vulnerabilities, update the package (the ones without a fix upstream are ignored). A finding that is
  accepted (false positive, not reachable) can be listed in a `.trivyignore` file in the root of the repository, with
  a comment saying why. If Trivy cannot run (vulnerability database download), the build is marked unstable and
  continues.
- **No email for a tag?** A failed or unstable build is always reported, a successful one is not. Check the
  tag build in Jenkins if an expected image did not show up on Docker Hub.

## Images

Built for `linux/amd64` only. Every image has the `org.opencontainers.image.revision` (commit),
`org.opencontainers.image.version` and `org.opencontainers.image.source` labels:
`docker inspect --format '{{json .Config.Labels}}' eeacms/reportek-base-dr:<version>`.
