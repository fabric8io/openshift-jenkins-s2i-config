#!/usr/bin/groovy
@Library('github.com/fabric8io/fabric8-pipeline-library@master')
def repo = 'openshift-jenkins-s2i-config'
def org = 'fabric8io'
def project = org + '/' + repo
def flow = new io.fabric8.Fabric8Commands()
def baseImageVerion = 'v3ad8ded'

dockerTemplate{
    s2iNode{
        checkout scm
        if (env.BRANCH_NAME.startsWith('PR-')) {
            echo 'Running CI pipeline'
            snapshot = true
            def snapshotImageName = "fabric8/jenkins-openshift:SNAPSHOT-${env.BRANCH_NAME}-${env.BUILD_NUMBER}"
            container('s2i') {
                sh "s2i build . fabric8/jenkins-openshift-base:${baseImageVerion} ${snapshotImageName} --copy"
            }

            stage "push snapshot to dockerhub"
            container('docker') {
                sh "docker push ${snapshotImageName}"
            }

            stage('notify'){
                def changeAuthor = env.CHANGE_AUTHOR
                if (!changeAuthor){
                    error "no commit author found so cannot comment on PR"
                }
                def pr = env.CHANGE_ID
                if (!pr){
                    error "no pull request number found so cannot comment on PR"
                }
                def message = "@${changeAuthor} snapshot Jenkins image is available for testing.  `docker pull ${snapshotImageName}`"
                container('docker'){
                    flow.addCommentToPullRequest(message, pr, project)
                }
            }

        } else if (env.BRANCH_NAME.equals('master')) {
            echo 'Running CD pipeline'
            def newVersion = getNewVersion {}

            stage 's2i build'
            container('s2i') {
                sh "s2i build . fabric8/jenkins-openshift-base:${baseImageVerion} fabric8/jenkins-openshift:latest --copy"
            }
            
            stage 'push to dockerhub'
            container('docker') {
                sh 'docker push fabric8/jenkins-openshift:latest'
                sh "docker tag fabric8/jenkins-openshift:latest fabric8/jenkins-openshift:${newVersion}"
                sh "docker push fabric8/jenkins-openshift:${newVersion}"
            }
            
            pushPomPropertyChangePR {
                propertyName = 'jenkins-openshift.version'
                projects = [
                        'fabric8-services/fabric8-tenant-jenkins'
                ]
                version = newVersion
                containerName = 's2i'
            }
        }
    }
}
