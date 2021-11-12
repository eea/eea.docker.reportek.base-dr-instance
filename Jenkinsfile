pipeline {
  agent any

  environment {
    GIT_NAME = "eea.docker.reportek.base-dr-instance"
    dockerhubrepo = "eeacms/reportek-base-dr"
    DEPENDENT_DOCKERFILE_URL="eea/eea.docker.reportek.mdr-instance/blob/master/Dockerfile eea/eea.docker.reportek.cdr-instance/blob/master/Dockerfile eea/eea.docker.reportek.bdr-instance/blob/master/Dockerfile"
    UPDATE_MASTER_BRANCH="yes"
  }
  
  stages {
 
    stage('Release') {
      when {
         branch 'develop'
      }
      steps {
        node(label: 'docker') {
          withCredentials([string(credentialsId: 'eea-jenkins-token', variable: 'GITHUB_TOKEN'), usernamePassword(credentialsId: 'jekinsdockerhub', usernameVariable: 'DOCKERHUB_USER', passwordVariable: 'DOCKERHUB_PASS')]) {
            sh '''docker run -i --rm --name="$BUILD_TAG" -e GIT_BRANCH="develop" -e GIT_NAME="$GIT_NAME" -e DOCKERHUB_REPO="$dockerhubrepo" -e GIT_TOKEN="$GITHUB_TOKEN" -e DOCKERHUB_USER="$DOCKERHUB_USER" -e DOCKERHUB_PASS="$DOCKERHUB_PASS"  -e DEPENDENT_DOCKERFILE_URL="$DEPENDENT_DOCKERFILE_URL" -e GITFLOW_BEHAVIOR="TAG_ONLY" eeacms/gitflow'''
         }
       }
     }
   }

//    stage('Testing') {
//      when { 
//         branch 'develop'
//      }
//      steps {
//        parallel(
//          
//          "Coverage": {
//            node(label: 'docker') {
//              script {
//                catchError(buildResult: 'SUCCESS', stageResult: 'UNSTABLE') {
//                  sh '''docker run -i --rm --name="$BUILD_TAG-devel" -e GIT_SRC="$GIT_SRC" -e GIT_NAME="$GIT_NAME" -e GIT_BRANCH="$BRANCH_NAME" -e GIT_CHANGE_ID="$CHANGE_ID" eeacms/reportek-base-dr-develop coverage'''
//                }
//              }
//            }
//          },
//
//          "Tests": {
//            node(label: 'docker') {
//              script {
//                catchError(buildResult: 'SUCCESS', stageResult: 'UNSTABLE') {
//                  sh '''docker run -i --rm --name="$BUILD_TAG-devel" -e GIT_SRC="$GIT_SRC" -e GIT_NAME="$GIT_NAME" -e GIT_BRANCH="$BRANCH_NAME" -e GIT_CHANGE_ID="$CHANGE_ID" eeacms/reportek-base-dr-develop tests'''
//                }
//              }
//            }
//          }
//        )
//      }
//    }  

     stage('Commit on master') {
      steps {
        node(label: 'docker') {
          withCredentials([[$class: 'UsernamePasswordMultiBinding', credentialsId: 'eea-jenkins', usernameVariable: 'EGGREPO_USERNAME', passwordVariable: 'EGGREPO_PASSWORD'],string(credentialsId: 'eea-jenkins-token', variable: 'GITHUB_TOKEN'),[$class: 'UsernamePasswordMultiBinding', credentialsId: 'pypi-jenkins', usernameVariable: 'PYPI_USERNAME', passwordVariable: 'PYPI_PASSWORD']]) {
            sh '''docker pull eeacms/gitflow; docker run -i --rm --name="$BUILD_TAG-gitflow-master" -e GIT_BRANCH="$BRANCH_NAME" -e EGGREPO_USERNAME="$EGGREPO_USERNAME" -e EGGREPO_PASSWORD="$EGGREPO_PASSWORD" -e GIT_NAME="$GIT_NAME"  -e PYPI_USERNAME="$PYPI_USERNAME"  -e PYPI_PASSWORD="$PYPI_PASSWORD" -e GIT_ORG="$GIT_ORG" -e GIT_TOKEN="$GITHUB_TOKEN" -e UPDATE_MASTER_BRANCH="$UPDATE_MASTER_BRANCH" eeacms/gitflow'''
          }
        }
      }
    }
  }

  post {
    changed {
      script {
        def url = "${env.BUILD_URL}/display/redirect"
        def status = currentBuild.currentResult
        def subject = "${status}: Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]'"
        def summary = "${subject} (${url})"
        def details = """<h1>${env.JOB_NAME} - Build #${env.BUILD_NUMBER} - ${status}</h1>
                         <p>Check console output at <a href="${url}">${env.JOB_BASE_NAME} - #${env.BUILD_NUMBER}</a></p>
                      """

        def color = '#FFFF00'
        if (status == 'SUCCESS') {
          color = '#00FF00'
        } else if (status == 'FAILURE') {
          color = '#FF0000'
        }
      }
    }
  }
}
