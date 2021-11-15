pipeline {
  agent any

  environment {
    GIT_USER = "eea-jenkins"
    GIT_NAME = "eea.docker.reportek.base-dr-instance"
    dockerhubrepo = "eeacms/reportek-base-dr"
    DEPENDENT_DOCKERFILE_URL="eea/eea.docker.reportek.mdr-instance/blob/master/Dockerfile eea/eea.docker.reportek.cdr-instance/blob/master/Dockerfile eea/eea.docker.reportek.bdr-instance/blob/master/Dockerfile"
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
          withCredentials([string(credentialsId: 'eea-jenkins-token', variable: 'GITHUB_TOKEN')]) {
           sh ''' ls -la ./; rm -rf *; ls -la ./'''
           sh ''' git clone https://$GIT_USER:$GITHUB_TOKEN@github.com/eea/${GIT_NAME}.git ./$GIT_NAME; cd ./$GIT_NAME; git reset --hard origin/master'''
           sh ''' curl https://raw.githubusercontent.com/eea/$GIT_NAME/develop/src/versions.cfg --output src/versions.cfg'''
           sh ''' git add src/versions.cfg'''
           sh ''' git status; git commit -m "Updated versions.cfg"; sed -i "s/null:null/$GIT_USER:$GITHUB_TOKEN/" .git/config; git push'''
           sh ''' cd ..; rm -rf ./''' 
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
