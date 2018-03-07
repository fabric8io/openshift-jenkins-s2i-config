#!/usr/bin/groovy
@Library('github.com/fabric8io/fabric8-pipeline-library@master')
def repo = 'openshift-jenkins-s2i-config'
def org = 'fabric8io'
def project = org + '/' + repo
def flow = new io.fabric8.Fabric8Commands()
def baseImageVerion = "v28b4986"
def deploySnapshot = false
def pipeline
def snapshotImageName

dockerTemplate{
    s2iNode{
        checkout scm
        if (env.BRANCH_NAME.startsWith('PR-')) {
            echo 'Running CI pipeline'
            snapshot = true
            snapshotImageName = "fabric8/jenkins-openshift:SNAPSHOT-${env.BRANCH_NAME}-${env.BUILD_NUMBER}"
            stage ('build'){
                container('s2i') {
                    sh "s2i build . fabric8/jenkins-openshift-base:${baseImageVerion} ${snapshotImageName} --copy"
                }
            }

            stage ('push snapshot to dockerhub'){
                container('docker') {
                    sh "docker push ${snapshotImageName}"
                }
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
                def message = "@${changeAuthor} snapshot Jenkins image is available.  `docker pull ${snapshotImageName}`"
                container('docker'){
                    flow.addCommentToPullRequest(message, pr, project)
                }
            }
                
            deploySnapshot = true


        } else if (env.BRANCH_NAME.equals('master')) {
            echo 'Running CD pipeline'
            def newVersion = getNewVersion {}

            stage ('s2i build'){
                container('s2i') {
                    sh "s2i build . fabric8/jenkins-openshift-base:${baseImageVerion} fabric8/jenkins-openshift:${newVersion} --copy"
                }
            }

            stage ('push to dockerhub'){
                container('docker') {
                    sh "docker push fabric8/jenkins-openshift:${newVersion}"
                    sh "docker tag fabric8/jenkins-openshift:${newVersion} fabric8/jenkins-openshift:latest"
                    sh 'docker push fabric8/jenkins-openshift:latest'
                }
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

if (deploySnapshot){
    stage ('deploy and test snapshot'){

        def namespace = 'jenkins-'+ env.BRANCH_NAME
        namespace = namespace.toLowerCase()

        parallel openshift: {
            def containerName = 'os'
            deployRemoteClusterNode(configSecretName: 'fabric8-intcluster-config', containerName: containerName,  label: "jen_os_${env.CHANGE_ID}_${env.BUILD_NUMBER}"){
                cleanWs()
                deployRemoteOpenShift()
            }
            
        }, kubernetes: {
            def containerName = 'k8s'
            
            deployRemoteClusterNode(configSecretName: 'tiger-config', containerName: containerName, label: "jen_k8s_${env.CHANGE_ID}_${env.BUILD_NUMBER}"){
                cleanWs()
                deployRemoteKubernetes(snapshotImageName, namespace)
            }
            

        },
        failFast: false
    }
}

def deployRemoteOpenShift(){
    container('os'){
        echo 'TODO run BDD tests on OpenShift'
        sh 'oc version'
    }
}

def deployRemoteKubernetes(snapshotImageName, deployNamespace){

    withCredentials([usernamePassword(credentialsId: 'test-user', passwordVariable: 'PASS', usernameVariable: 'USER')]) {
        withCredentials([usernamePassword(credentialsId: 'cd-github', passwordVariable: 'GH_PASS', usernameVariable: 'GH_USER')]) {


    def nexusServiceLink = """
apiVersion: v1
kind: List
items:
- kind: Service
  apiVersion: v1
  metadata:
    name: content-repository
  spec:
    type: ExternalName
    externalName: artifact-repository.shared
    ports:
    - port: 80
"""

def addCredsScript = """
{
  \"credentials\": {
    \"scope\": \"GLOBAL\",
    \"id\": \"cd-github\",
    \"username\": \"${GH_USER}\",
    \"password\": \"${GH_PASS}\",
    \"\$class\": \"com.cloudbees.plugins.credentials.impl.UsernamePasswordCredentialsImpl\"
  }
}
"""
            def map = [:]
            map["TEST_ADMIN_PASSWORD"] = PASS
            map["EXTERNAL_DOCKER_REGISTRY_URL"] = '10.7.240.40:80' // this is nexus in the shared ns on test cluster, find a nice way to look this up so it's not hardcoded.
    
            //swizzle the image name and deploy snashot
            ing = deployKubernetesSnapshot{
                mavenRepo = 'http://central.maven.org/maven2/io/fabric8/apps/jenkins'
                githubRepo = 'openshift-jenkins-s2i-config'
                originalImageName = 'fabric8/jenkins-openshift'
                newImageName = snapshotImageName
                namespace = deployNamespace
                appToDeploy = 'jenkins'
                project = 'fabric8io/openshift-jenkins-s2i-config'
                clusterName = 'tiger'
                clusterZone = 'europe-west1-b'
                extraYAML = nexusServiceLink
                templateParameters = map
            }
            map = null

            sh "curl -X POST 'http://${USER}:${PASS}@${ing}/credentials/store/system/domain/_/createCredentials' --data-urlencode 'json=${addCredsScript}'"

            try {
                def buildPath = '/go/src/github.com/fabric8-jenkins/godog-jenkins'
                container('k8s'){
                    sh 'chmod 600 /root/.ssh-git/ssh-key'
                    sh 'chmod 600 /root/.ssh-git/ssh-key.pub'
                    sh 'chmod 700 /root/.ssh-git'

                    sh "mkdir -p ${buildPath}"
                    sh "git clone https://github.com/fabric8-jenkins/godog-jenkins ${buildPath}"

                    sh 'ls -al'
                    sh "cd ${buildPath}/jenkins && GITHUB_USER=${GH_USER} GITHUB_PASSWORD=${GH_PASS} BDD_JENKINS_URL=http://${ing} BDD_JENKINS_USERNAME=admin BDD_JENKINS_TOKEN=${env.PASS} godog"
                }
            } finally {
                notify('k8s', ing)
            }
        }
    }
}

def notify(containerName, url){
    def flow = new io.fabric8.Fabric8Commands()
    def changeAuthor = env.CHANGE_AUTHOR
    if (!changeAuthor){
        error "no commit author found so cannot comment on PR"
    }
    def pr = env.CHANGE_ID
    if (!pr){
        error "no pull request number found so cannot comment on PR"
    }
    def message = "Snapshot Jenkins is deployed and running [HERE](http://${url})"
    container(containerName){
        flow.addCommentToPullRequest(message, pr, 'fabric8io/openshift-jenkins-s2i-config')
    }
}