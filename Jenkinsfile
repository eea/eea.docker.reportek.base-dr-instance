pipeline {
  agent {    node { label "docker-host" }    }

  environment {
    IMAGE_NAME = "base-dr-testing"
    GIT_USER = "eea-jenkins"
    GIT_NAME = "eea.docker.reportek.base-dr-instance"
    dockerhubrepo = "eeacms/reportek-base-dr"
    DEPENDENT_DOCKERFILE_URL="eea/eea.docker.reportek.mdr-instance/blob/master/Dockerfile eea/eea.docker.reportek.cdr-instance/blob/master/Dockerfile eea/eea.docker.reportek.bdr-instance/blob/master/Dockerfile"
  }
  
  stages {
 
    stage('Testing') {
      when { 
         branch 'testing'
      }
      steps {
        parallel(
          
          "Coverage": {
            node(label: 'docker') {
              script {
                catchError(buildResult: 'SUCCESS', stageResult: 'UNSTABLE') {
                  try {
                  sh '''git clone $GIT_SRC'''
                  sh '''git build -t ${IMAGE_NAME}'''  
                  sh '''docker run -i --rm --name="$BUILD_TAG-devel" -e GIT_SRC="$GIT_SRC" -e GIT_NAME="$GIT_NAME" -e GIT_BRANCH="$BRANCH_NAME" -e GIT_CHANGE_ID="$CHANGE_ID" $IMAGE_NAME coverage'''                    
               }  finally {
                  sh script: "docker rm -v ${IMAGE_NAME}", returnStatus: true
                  sh script: "docker rmi ${IMAGE_NAME}", returnStatus: true
               }  
               }
              }
            }
          },

          "Coverage": {
            node(label: 'docker') {
              script {
                catchError(buildResult: 'SUCCESS', stageResult: 'UNSTABLE') {
                  try {
                  sh '''git clone $GIT_SRC'''
                  sh '''git build -t ${IMAGE_NAME}'''  
                  sh '''docker run -i --rm --name="$BUILD_TAG-devel" -e GIT_SRC="$GIT_SRC" -e GIT_NAME="$GIT_NAME" -e GIT_BRANCH="$BRANCH_NAME" -e GIT_CHANGE_ID="$CHANGE_ID" $IMAGE_NAME tests'''                    
               }  finally {
                  sh script: "docker rm -v ${IMAGE_NAME}", returnStatus: true
                  sh script: "docker rmi ${IMAGE_NAME}", returnStatus: true
               }  
               }
              }
            }
          },
        )
      }
    }  

     stage('Commit on master') {
      steps {
        node(label: 'docker') {
          withCredentials([string(credentialsId: 'eea-jenkins-token', variable: 'GITHUB_TOKEN')]) {
           sh ''' rm -rf .git *'''
           sh ''' git clone https://$GIT_USER:$GITHUB_TOKEN@github.com/eea/${GIT_NAME}.git ./$GIT_NAME; cd ./$GIT_NAME; curl https://raw.githubusercontent.com/eea/$GIT_NAME/testing/src/versions.cfg --output src/versions.cfg; git add src/versions.cfg; git commit -m "Updated versions.cfg"; sed -i "s/null:null/$GIT_USER:$GITHUB_TOKEN/" .git/config; git push'''
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
