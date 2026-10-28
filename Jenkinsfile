def notifyBuild() {
  def details = """<h1>${env.JOB_NAME} - Build #${env.BUILD_NUMBER} - ${currentBuild.currentResult}</h1>
                   <p>Check console output at <a href="${env.BUILD_URL}/display/redirect">${env.JOB_BASE_NAME} - #${env.BUILD_NUMBER}</a></p>
                """
  emailext(
  subject: '$DEFAULT_SUBJECT',
  body: details,
  attachLog: true,
  compressLog: true,
  to: 'eea-edw-c-team-alerts@googlegroups.com',
  recipientProviders: [[$class: 'DevelopersRecipientProvider'], [$class: 'CulpritsRecipientProvider']]
  )
}

pipeline {
  agent {
    node { label 'docker-host' }
  }

  options {
    disableConcurrentBuilds()
    timeout(time: 90, unit: 'MINUTES')
    buildDiscarder(logRotator(numToKeepStr: '20'))
  }

  environment {
    // per-build docker config, so the dhi.io login is not written to the agent's shared ~/.docker
    DOCKER_CONFIG = "${WORKSPACE}/.docker"
    // BUILD_TAG has %2f for a / in the branch name, keep only what docker accepts in tags and names
    SAFE_BUILD_TAG = "${env.BUILD_TAG.toLowerCase().replaceAll('[^a-z0-9_.-]', '-')}"
    GIT_NAME = "eea.docker.reportek.base-dr-instance"
    GIT_USER = "eea-jenkins"
    DOCKERHUB_REPO = "eeacms/reportek-base-dr"
    // a release is a tag in this form: <Zope minor>-<N>, ex: 5.14-3
    TAG_PATTERN = '^[0-9]+[.][0-9]+-[0-9]+$'
    // pinned, the scan results should not change because the scanner did
    TRIVY_IMAGE = "aquasec/trivy:0.76.0"
    TEST_IMAGE = "base-dr-testing:${SAFE_BUILD_TAG}"
    TEST_CONTAINER = "${SAFE_BUILD_TAG}-tests"
  }

  // How a release happens:
  //  1. a commit on testing is built and tested
  //  2. Promote to master copies requirements.txt to master and creates the GitHub release (and its tag)
  //  3. the tag is built and tested again, then Release publishes <zope>-<N> and latest to Docker Hub
  //  4. Bump dependents points cdr and bdr to the new image, and releases them the same way
  // Commits made directly on master are built and tested, but not released until they are tagged.
  // Tags that are not a release (ex: the old z5-*) are ignored.
  stages {

    stage('Build image') {
      when {
        expression { !env.TAG_NAME || env.TAG_NAME ==~ env.TAG_PATTERN }
      }
      steps {
        withCredentials([usernamePassword(credentialsId: 'jekinsdockerhub', usernameVariable: 'DOCKERHUB_USERNAME', passwordVariable: 'DOCKERHUB_PASSWORD')]) {
          script {
            try {
              // the Dockerfile pulls its base images from dhi.io (Docker Hardened Images)
              sh '''
                printf '%s' "$DOCKERHUB_PASSWORD" | docker login dhi.io -u "$DOCKERHUB_USERNAME" --password-stdin
                docker build --no-cache --platform=linux/amd64 --label "org.opencontainers.image.revision=$GIT_COMMIT" --label "org.opencontainers.image.source=https://github.com/eea/$GIT_NAME" --label "org.opencontainers.image.version=${TAG_NAME:-$BRANCH_NAME}" -t "$TEST_IMAGE" .
              '''
            } finally {
              sh '''docker logout dhi.io || true'''
            }
          }
        }
      }
    }

    // Do not use "docker-entrypoint.sh tests" as a gate: it loops over /opt/zope/src, which does not exist
    // in this image (products-reportek is installed from PyPI), and every run ends in "|| true",
    // so it always exits 0. Run the test runner directly against the installed package instead.

    stage('Tests') {
      when {
        expression { !env.TAG_NAME || env.TAG_NAME ==~ env.TAG_PATTERN }
      }
      steps {
        script {
          def rc = 1
          try {
            rc = sh(returnStatus: true, script: '''
              docker run --name "$TEST_CONTAINER" "$TEST_IMAGE" \
                /opt/zope/bin/zope-testrunner --test-path /opt/zope/lib/python3.12/site-packages -s Products.Reportek
            ''')
          } finally {
            sh(returnStatus: true, script: '''docker stop "$TEST_CONTAINER"''')
            sh(returnStatus: true, script: '''docker rm -v "$TEST_CONTAINER"''')
          }
          if (rc != 0) {
            error "Products.Reportek tests failed (exit code ${rc}), requirements.txt will not be promoted to master"
          }
        }
      }
    }

    // Start the image that was just built and check that it serves, before anything is published.
    stage('Smoke test') {
      when {
        expression { !env.TAG_NAME || env.TAG_NAME ==~ env.TAG_PATTERN }
      }
      steps {
        sh '''SMOKE_PLATFORM=linux/amd64 ./test/smoke.sh "$TEST_IMAGE" requirements.txt'''
      }
    }

    // Trivy, on the image that was just built. Fixable CRITICAL vulnerabilities fail the build, the HIGH ones are only
    // listed (some of them are not fixed upstream, and there are fixable ones today). Findings can be accepted in
    // a .trivyignore file in the root of the repository. When the scan cannot run (ex: the vulnerability database
    // cannot be downloaded) the build is marked unstable, a Docker Hub or ghcr.io outage should not block a release.
    // The image is scanned from a tar file, so the Docker socket is not given to the scanner.
    stage('Scan image') {
      when {
        expression { !env.TAG_NAME || env.TAG_NAME ==~ env.TAG_PATTERN }
      }
      options {
        timeout(time: 15, unit: 'MINUTES')
      }
      steps {
        script {
          def rc = 1
          try {
            rc = sh(returnStatus: true, script: '''
              docker save -o image.tar "$TEST_IMAGE"
              # no bind mount: the agent runs in a container, so its workspace path does not exist for the docker daemon
              scan() {
                cid=$(docker create -v trivy-cache:/root/.cache "$TRIVY_IMAGE" image --quiet --input /tmp/image.tar --scanners vuln "$@" --table-mode detailed)
                docker cp image.tar "$cid:/tmp/image.tar"
                rc=0
                docker start -a "$cid" || rc=$?
                docker rm -v "$cid" > /dev/null
                return $rc
              }
              scan --severity HIGH,CRITICAL --ignore-unfixed
              scan --severity CRITICAL --ignore-unfixed --exit-code 10
            ''')
          } finally {
            sh(returnStatus: true, script: '''rm -f image.tar''')
          }
          if (rc == 10) {
            error "Trivy found fixable CRITICAL vulnerabilities in the image, see the list above"
          } else if (rc != 0) {
            unstable "Trivy could not scan the image (exit code ${rc})"
          }
        }
      }
    }

    // Promote only what the tests above verified: requirements.txt. The release created here is what
    // starts the tag build that publishes the image.
    stage('Promote to master') {
      when {
        branch 'testing'
      }
      steps {
        withCredentials([string(credentialsId: 'eea-jenkins-token', variable: 'GITHUB_TOKEN')]) {
          sh '''
            set -e
            set +x
            rm -f "$WORKSPACE/.promoted-version"
            rm -rf promote
            git clone --branch master "https://$GIT_USER:$GITHUB_TOKEN@github.com/eea/$GIT_NAME.git" promote
            cp requirements.txt promote/requirements.txt
            cd promote
            if git diff --quiet -- requirements.txt; then
              if [ -n "$(git tag --points-at HEAD)" ]; then
                echo "master already has this requirements.txt and is released, nothing to promote"
                exit 0
              fi
              # a previous run pushed the commit but did not get to create the release
              echo "master already has this requirements.txt but its latest commit is not released yet"
            else
              git add requirements.txt
              git commit -m "Updated requirements.txt"
            fi
            PREVIOUS=$(git tag | grep -E "$TAG_PATTERN" | sort -V | tail -n 1 || true)
            VERSION=$(./src/docker/calculate_next_release.sh)
            git push origin HEAD:master
            "$WORKSPACE/src/docker/create_release.sh" "$GIT_NAME" "$VERSION" "$(git rev-parse HEAD)" "$PREVIOUS"
            echo "$VERSION" > "$WORKSPACE/.promoted-version"
          '''
        }
      }
    }

    // The tag build publishes the image, nothing else tells that it did not happen (ex: Jenkins did not notice the
    // tag). Wait for the image, so a release that never gets published turns this build red.
    stage('Wait for the release') {
      when {
        allOf {
          branch 'testing'
          expression { fileExists('.promoted-version') }
        }
      }
      options {
        timeout(time: 35, unit: 'MINUTES')
      }
      steps {
        sh '''
          VERSION=$(cat .promoted-version)
          echo "Waiting for $DOCKERHUB_REPO:$VERSION to be published by the build of the tag $VERSION"
          for i in $(seq 60); do
            if [ "$(curl -s -o /dev/null -w '%{http_code}' "https://hub.docker.com/v2/repositories/$DOCKERHUB_REPO/tags/$VERSION")" = "200" ]; then
              echo "$DOCKERHUB_REPO:$VERSION is published"
              exit 0
            fi
            sleep 30
          done
          echo "$DOCKERHUB_REPO:$VERSION was not published in 30 minutes, check the build of the tag $VERSION in Jenkins" >&2
          exit 1
        '''
      }
    }

    // Publish the image that was just built and tested from the tag. latest only moves to the newest release,
    // so rebuilding an old tag does not take it backwards. The GitHub release already exists, it was created with the tag.
    stage('Release') {
      when {
        expression { (env.TAG_NAME ?: '') ==~ env.TAG_PATTERN }
      }
      steps {
        withCredentials([usernamePassword(credentialsId: 'jekinsdockerhub', usernameVariable: 'DOCKERHUB_USER', passwordVariable: 'DOCKERHUB_PASS')]) {
          script {
            try {
              sh '''
                set -e
                VERSION="$TAG_NAME"
                git fetch -q --force "https://github.com/eea/$GIT_NAME.git" "refs/tags/*:refs/tags/*"
                # a tag only releases what is on master, anybody with write access can push a tag
                if [ "$(git rev-parse --is-shallow-repository)" = "true" ]; then git fetch -q --unshallow "https://github.com/eea/$GIT_NAME.git" master; else git fetch -q "https://github.com/eea/$GIT_NAME.git" master; fi
                if ! git merge-base --is-ancestor HEAD FETCH_HEAD; then
                  echo "The commit tagged $VERSION is not on master, not releasing it"
                  exit 1
                fi
                echo "Releasing $DOCKERHUB_REPO:$VERSION"
                printf '%s' "$DOCKERHUB_PASS" | docker login -u "$DOCKERHUB_USER" --password-stdin
                docker tag "$TEST_IMAGE" "$DOCKERHUB_REPO:$VERSION"
                docker push "$DOCKERHUB_REPO:$VERSION"
                NEWEST=$(git tag | grep -E "$TAG_PATTERN" | sort -V | tail -n 1)
                if [ "$NEWEST" = "$VERSION" ]; then
                  docker tag "$TEST_IMAGE" "$DOCKERHUB_REPO:latest"
                  docker push "$DOCKERHUB_REPO:latest"
                else
                  echo "$VERSION is not the newest release ($NEWEST), latest is left alone"
                fi
              '''
            } finally {
              sh '''docker logout || true'''
            }
          }
        }
      }
    }

    // cdr and bdr follow the base image: point their Dockerfile to the version that was just released and
    // create their release, their own tag build then publishes them. Only runs for the newest release, an old tag
    // being rebuilt must not take them backwards.
    stage('Bump dependents') {
      when {
        expression { (env.TAG_NAME ?: '') ==~ env.TAG_PATTERN }
      }
      steps {
        withCredentials([string(credentialsId: 'eea-jenkins-token', variable: 'GITHUB_TOKEN')]) {
          sh '''
            set -e
            set +x
            VERSION="$TAG_NAME"
            git fetch -q --force "https://github.com/eea/$GIT_NAME.git" "refs/tags/*:refs/tags/*"
            NEWEST=$(git tag | grep -E "$TAG_PATTERN" | sort -V | tail -n 1)
            if [ "$NEWEST" != "$VERSION" ]; then
              echo "$VERSION is not the newest release ($NEWEST), the dependents are left alone"
              exit 0
            fi
            for repo in eea.docker.reportek.cdr-instance eea.docker.reportek.bdr-instance; do
              rm -rf "dependent-$repo"
              git clone --branch master "https://$GIT_USER:$GITHUB_TOKEN@github.com/eea/$repo.git" "dependent-$repo"
              cd "dependent-$repo"
              sed -i -E "/^FROM .*eeacms[/]reportek-base-dr:/ s#eeacms/reportek-base-dr:[^ ]+#eeacms/reportek-base-dr:$VERSION#" Dockerfile
              if git diff --quiet -- Dockerfile; then
                if [ -n "$(git tag --points-at HEAD)" ]; then
                  echo "$repo already uses $VERSION and is released, nothing to bump"
                  cd ..
                  continue
                fi
                echo "$repo already uses $VERSION but its latest commit is not released yet"
              else
                git add Dockerfile
                git commit -m "Bump the base image to $VERSION"
              fi
              PREVIOUS=$(git tag | grep -E "$TAG_PATTERN" | sort -V | tail -n 1 || true)
              NEXT=$(./src/docker/calculate_next_release.sh)
              git push origin HEAD:master
              "$WORKSPACE/src/docker/create_release.sh" "$repo" "$NEXT" "$(git rev-parse HEAD)" "$PREVIOUS"
              cd ..
            done
          '''
        }
      }
    }

  }

  post {
    always {
      // the images built here are not needed once the build is over
      sh '''
        docker rmi "$TEST_IMAGE" > /dev/null 2>&1 || true
        if [ -n "${TAG_NAME:-}" ]; then
          docker rmi "$DOCKERHUB_REPO:$TAG_NAME" > /dev/null 2>&1 || true
          docker rmi "$DOCKERHUB_REPO:latest" > /dev/null 2>&1 || true
        fi
      '''
      cleanWs(cleanWhenAborted: true, cleanWhenFailure: true, cleanWhenNotBuilt: true, cleanWhenSuccess: true, cleanWhenUnstable: true, deleteDirs: true)
    }
    // a new tag is a new job without a previous build, so report every failure instead of only the changes
    failure {
      script { notifyBuild() }
    }
    unstable {
      script { notifyBuild() }
    }
    fixed {
      script { notifyBuild() }
    }
  }
}
