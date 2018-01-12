# openshift-jenkins-s2i-config

The Jenkins image for OISO Tenants and https://jenkins.cd.test.fabric8.io.

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
- [Prerequisites](#prerequisites)
- [Run](#run)
- [List of plugin installed](#list-of-plugin-installed)
  - [Required:](#required)
  - [Optional but recommend:](#optional-but-recommend)
  - [Optional but not recommended](#optional-but-not-recommended)
- [Note](#note)
- [TODO](#todo)
<!-- END doctoc generated TOC please keep comment here to allow auto update -->

## Prerequisites
  - Get the latest [s2i](https://github.com/openshift/source-to-image/releases)
  - Run the following in the default namespace as explained in the todo below

## Run

Run the following steps to build and deploy this customised OpenShift Jenkins
Pipeline image..

    # modify the existing OpenShift Jenkins image adding Pipeline plugins and configuration
    s2i build https://github.com/fabric8io/openshift-jenkins-s2i-config.git openshift/jenkins-1-centos7 fabric8/jenkins-openshift-pipeline:latest

    oc new-app -f https://raw.githubusercontent.com/rawlingsj/openshift-jenkins-s2i-config/master/jenkins-template.yml -p JENKINS_PASSWORD=admin

    # expose the Jenkins service as you would normally e.g.
    oc expose service jenkins --hostname=jenkins.vagrant.f8

Access Jenkins via your OpenShift route, `admin/admin` to log in.

You will have an example pipeline job already created that you can run.  Also the configuration for kubernetes-plugin will have been setup automatically.  You can see in the Job configuration which it references a [Jenkinsfile in another repo](https://github.com/rawlingsj/basic-jenkinsfile), this is the recommended approach where a Jenkinsfile lives with the source code.  The Jenkinsfile uses the `agent` node label which requests a new Kubernetes Pod to be scheduled to run our basic stages.

Example basic Jenkinsfile..

    node('agent'){
      stage 'first'
      echo 'worked'

      stage 'second'
      echo 'again'
    }


## List of plugin installed

### Required:
1. [Pipeline plugin](https://wiki.jenkins-ci.org/display/JENKINS/Pipeline+Plugin)
ability to run Jenkinsfile

2. [Pipeine stage view plugin](https://wiki.jenkins-ci.org/display/JENKINS/Pipeline+Stage+View+Plugin)
useful visualisations

3. [Kubernetes plugin](https://wiki.jenkins-ci.org/display/JENKINS/Kubernetes+Plugin)
dynamically create Jenkins Agents on demand

4. [Remote loader](https://wiki.jenkins-ci.org/display/JENKINS/Pipeline+Remote+Loader+Plugin)
allows loading Pipeline scripts from remote locations.  Note until global library is versioned this is what we're suggesting users use to ensure reusable functions are versioned.

### Optional but recommend:
1. [Pipeline Utility Steps Plugin](https://wiki.jenkins-ci.org/display/JENKINS/Pipeline+Utility+Steps+Plugin)
useful library for working with Jenkinsfiles

2. [Mercurial](https://wiki.jenkins-ci.org/display/JENKINS/Mercurial+Plugin)
to support mercurial but we've not tested this

### Optional but not recommended
1. [Github branch source plugin](https://wiki.jenkins-ci.org/display/JENKINS/CloudBees+GitHub+Branch+Source+Plugin)
still not too sure about this one, it sounds good but its usability is a little raw.  For example, it will automatically trigger any new job that gets created after a repo scan which is a little scary.

2. [Simple build pipeline](https://github.com/jenkinsci/simple-build-for-pipeline-plugin)
it didn't work for me but it looks promising in the future

## Note
You'll need to [expose the Jenkins JNLP port](https://github.com/rawlingsj/openshift-jenkins-s2i-config/blob/master/configuration/config.xml#L80) and create a separate agent service like [this example](https://github.com/rawlingsj/openshift-jenkins-s2i-config/blob/master/jenkins-template.yml#L26-L43)

## TODO
1. This example is currently hard coded to run in the default namespace at the moment.  I had a go at using a `KUBERNETES_NAMESPACE` env var as per the [fabric8 version](https://github.com/fabric8io/jenkins-docker/blob/master/config/config.xml#L159) which is [set](https://github.com/rawlingsj/openshift-jenkins-s2i-config/blob/master/jenkins-template.yml#L65) and available in the container but I ran into an issue starting the agent pod, so it needs to be looked at again.
2. Add the SNAPSHOT [openshift-jenkins-sync-plugin](https://github.com/fabric8io/openshift-jenkins-sync-plugin) to this project


DO NOT MERGE - 01
