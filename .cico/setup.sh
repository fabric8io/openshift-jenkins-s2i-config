#!/bin/bash
#
# Build script for CI builds on CentOS CI
#
# This is automatically updated by fabric8-jenkins/jenkins-openshift-base
# at merge time via a PR but you can always modify it manually for fun and giggles.
BASE_IMAGE_VERSION="v95933d9"

set -ex

function get_s2i_latest_release() {
    repo=openshift/source-to-image
    curl -Ls $(curl -s https://api.github.com/repos/${repo}/releases/latest|grep -E -oh -- "https://.*-linux-amd64.tar.gz") \ |
        tar -v -x -f- -z -C /usr/local/bin ./s2i
}

function setup() {
    if [ -f jenkins-env.json ]; then
        eval "$(./env-toolkit load -f jenkins-env.json \
                FABRIC8_HUB_TOKEN \
                FABRIC8_DOCKERIO_CFG \
                ghprbActualCommit \
                ghprbPullAuthorLogin \
                ghprbGhRepository \
                ghprbPullId \
                GIT_COMMIT \
                BUILD_ID)"

        mkdir -p ${HOME}/.docker
        echo ${FABRIC8_DOCKERIO_CFG}|base64 --decode > ${HOME}/.docker/config.json
    fi

    # We need to disable selinux for now, XXX
    /usr/sbin/setenforce 0 || :

    yum -y install docker make golang git
    service docker start

    get_s2i_latest_release

    echo 'CICO: Build environment created.'
}

function addCommentToPullRequest() {
    message="$1"
    pr="$2"
    project="$3"
    url="https://api.github.com/repos/${project}/issues/${pr}/comments"

    set +x
    echo curl -X POST -s -L -H "Authorization: XXXX|base64 --decode)" ${url} -d "{\"body\": \"${message}\"}"
    curl -X POST -s -L -H "Authorization: token $(echo ${FABRIC8_HUB_TOKEN}|base64 --decode)" ${url} -d "{\"body\": \"${message}\"}"
    set -x
}


function build() {
    local snapshotImageName="fabric8/jenkins-openshift:SNAPSHOT-PR-${ghprbPullId}-${BUILD_ID}"
    local message="Good news @${ghprbPullAuthorLogin} snapshot Jenkins image is available. \`docker pull ${snapshotImageName}\`"

    s2i build . fabric8/jenkins-openshift-base:${BASE_IMAGE_VERSION} ${snapshotImageName} --copy

    docker push ${snapshotImageName}

    addCommentToPullRequest "${message}" "${ghprbPullId}" "${ghprbGhRepository}"
}

function deploy() {
    local newVersion="v$(git rev-parse --short ${GIT_COMMIT})"
    s2i build . fabric8/jenkins-openshift-base:${BASE_IMAGE_VERSION} \
        fabric8/jenkins-openshift:${newVersion} --copy

    docker push fabric8/jenkins-openshift:${newVersion}
    docker tag fabric8/jenkins-openshift:${newVersion} fabric8/jenkins-openshift:latest
    docker push fabric8/jenkins-openshift:latest

    updateDownstreamRepos ${newVersion}
}

function updateDownstreamRepos() {
    local newVersion=${1}
    local message="Update Jenkins image version to ${newVersion}"
    local uid=$(python -c 'import uuid;print uuid.uuid4()')
    local branch="versionUpdate${uid}"

    git config --global user.name "FABRIC8 CD autobot"
    git config --global user.email fabric8cd@gmail.com

    set +x
    echo git clone https://XXXX@github.com/fabric8-services/fabric8-tenant.git --depth=1 /tmp/fabric8-tenant
    git clone https://$(echo ${FABRIC8_HUB_TOKEN}|base64 --decode)@github.com/fabric8-services/fabric8-tenant.git --depth=1 /tmp/fabric8-tenant
    set -x

    cd /tmp/fabric8-tenant
    git checkout -b ${branch}
    sed -i "/- name: JENKINS_OPENSHIFT_VERSION/!b;n;c\ \ value: ${newVersion}" environment/templates/fabric8-tenant-jenkins.yml

    git commit environment/templates/fabric8-tenant-jenkins.yml -m "${message}"
    git push -q -u origin ${branch}

    set +x
    curl -s -X POST -L -H "Authorization: token $(echo ${FABRIC8_HUB_TOKEN}|base64 --decode)" \
         -d "{\"title\": \"${message}\", \"base\":\"master\", \"head\":\"${branch}\"}" \
         https://api.github.com/repos/fabric8-services/fabric8-tenant/pulls
    set -x
}
