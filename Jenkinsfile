pipeline {
  agent {
    node { label 'docker-host' }
  }

  options {
    disableConcurrentBuilds()
  }

  environment {
    // per-build docker config, so the dhi.io login is not written to the agent's shared ~/.docker
    DOCKER_CONFIG = "${WORKSPACE}/.docker"
    // BUILD_TAG has %2f for a / in the branch name, keep only what docker accepts in tags and names
    SAFE_BUILD_TAG = "${env.BUILD_TAG.toLowerCase().replaceAll('[^a-z0-9_.-]', '-')}"
    GIT_NAME = "eea.docker.reportek.base-dr-instance"
    GIT_USER = "eea-jenkins"
    DOCKERHUB_REPO = "eeacms/reportek-base-dr"
    GITFLOW_CONTAINER = "${SAFE_BUILD_TAG}-gitflow"
    TEST_IMAGE = "base-dr-testing:${SAFE_BUILD_TAG}"
    TEST_CONTAINER = "${SAFE_BUILD_TAG}-tests"
  }

  stages {

    stage('Build image') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'jekinsdockerhub', usernameVariable: 'DOCKERHUB_USERNAME', passwordVariable: 'DOCKERHUB_PASSWORD')]) {
          script {
            try {
              // the Dockerfile pulls its base images from dhi.io (Docker Hardened Images)
              sh '''
                printf '%s' "$DOCKERHUB_PASSWORD" | docker login dhi.io -u "$DOCKERHUB_USERNAME" --password-stdin
                docker build --no-cache --platform=linux/amd64 -t "$TEST_IMAGE" .
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

    // Promote only what the tests above verified: requirements.txt. The push to master
    // triggers the normal master build (release, tag and image).
    stage('Promote to master') {
      when {
        branch 'testing'
      }
      steps {
        withCredentials([string(credentialsId: 'eea-jenkins-token', variable: 'GITHUB_TOKEN')]) {
          sh '''
            set -e
            set +x
            rm -rf promote
            git clone --branch master "https://$GIT_USER:$GITHUB_TOKEN@github.com/eea/$GIT_NAME.git" promote
            cp requirements.txt promote/requirements.txt
            cd promote
            if git diff --quiet -- requirements.txt; then
              echo "master already has this requirements.txt, nothing to promote"
              exit 0
            fi
            git add requirements.txt
            git commit -m "Updated requirements.txt"
            git push origin HEAD:master
          '''
        }
      }
    }

    // Publish the image that was just built and tested, then let gitflow tag it and create the
    // GitHub release. The image has to be on Docker Hub first, gitflow only waits for it (TAG_ONLY).
    stage('Release') {
      when {
        branch 'master'
      }
      steps {
        withCredentials([string(credentialsId: 'eea-jenkins-token', variable: 'GIT_TOKEN'), usernamePassword(credentialsId: 'jekinsdockerhub', usernameVariable: 'DOCKERHUB_USER', passwordVariable: 'DOCKERHUB_PASS')]) {
          script {
            try {
              sh '''
                set -e
                git fetch --tags --force -q
                if [ -n "$(git tag --points-at HEAD)" ]; then
                  echo "This commit is already released as $(git tag --points-at HEAD | head -n 1), nothing to do"
                  exit 0
                fi
                VERSION=$(./src/docker/calculate_next_release.sh)
                echo "Releasing $DOCKERHUB_REPO:$VERSION"
                printf '%s' "$DOCKERHUB_PASS" | docker login -u "$DOCKERHUB_USER" --password-stdin
                docker tag "$TEST_IMAGE" "$DOCKERHUB_REPO:$VERSION"
                docker tag "$TEST_IMAGE" "$DOCKERHUB_REPO:latest"
                docker push "$DOCKERHUB_REPO:$VERSION"
                docker push "$DOCKERHUB_REPO:latest"
                docker pull eeacms/gitflow
                docker run -i --rm --name="$GITFLOW_CONTAINER" -e GIT_BRANCH="master" -e GIT_NAME="$GIT_NAME" -e DOCKERHUB_REPO="$DOCKERHUB_REPO" -e GIT_TOKEN -e DOCKERHUB_USER -e DOCKERHUB_PASS -e GITFLOW_BEHAVIOR="TAG_ONLY" eeacms/gitflow
              '''
            } finally {
              sh '''docker logout || true'''
            }
          }
        }
      }
    }

  }

  post {
    always {
      cleanWs(cleanWhenAborted: true, cleanWhenFailure: true, cleanWhenNotBuilt: true, cleanWhenSuccess: true, cleanWhenUnstable: true, deleteDirs: true)
    }
    changed {
      script {
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
    }
  }
}
