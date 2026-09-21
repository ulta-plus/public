pipeline {
    agent {
        label 'ci-build-deploy'
    }

    options {
        disableConcurrentBuilds()
        skipDefaultCheckout()
        ansiColor('xterm')
    }

    environment {
        DOCKER_REGISTRY = 'registry.digitalocean.com/vpnn-infra'
        APP_NAME        = 'staticfiles'
    }

    stages {
        stage('Checkout') {
            steps {
                script {
                    def branchName = env.gitRef.replaceAll('^refs/heads/', '')
                    env.BRANCH_NAME = branchName
                    env.SHOULD_RUN = 'true'

                    if (!['main', 'test'].contains(branchName)) {
                        echo "Skipping build for branch: ${branchName}"
                        env.SHOULD_RUN = 'false'
                        return
                    }

                    if (env.newRevisionId == '0000000000000000000000000000000000000000') {
                        echo "Someone deleted branch from Github UI. Skip build"
                        env.SHOULD_RUN = 'false'
                        return
                    }

                    def publicBranch = env.repoName == 'pac-generator' ? 'main' : branchName
                    def generatorBranch = env.repoName == 'pac-generator' ? branchName : 'main'

                    checkout scm
                    sh "git checkout -f remotes/origin/${publicBranch} && git clean -fdx"
                    dir('.pac-generator') {
                        git url: 'https://github.com/ulta-plus/pac-generator.git', credentialsId: 'jenkins-git-token', branch: generatorBranch
                    }
                    sh 'scripts/mtimes.sh'

                    env.PUBLIC_SHA = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
                    env.PAC_GENERATOR_SHA = sh(script: 'git -C .pac-generator rev-parse --short HEAD', returnStdout: true).trim()
                    env.PAC_SOURCE_DATE = sh(script: 'git -C .pac-generator log -1 --format=%cI', returnStdout: true).trim()
                    env.IMAGE_TAG = "${env.PUBLIC_SHA}-${env.PAC_GENERATOR_SHA}"
                    env.HELM_IMAGE_TAG = env.IMAGE_TAG

                    currentBuild.displayName = "${env.BUILD_ID}-${APP_NAME}-${branchName}"
                    currentBuild.description = "Build and deploy to ${branchName}: ${APP_NAME}:${env.IMAGE_TAG}"
                }
            }
        }

        stage('Build') {
            when { expression { env.SHOULD_RUN == 'true' } }
            steps {
                container('buildah') {
                    withCredentials([
                        usernamePassword(credentialsId: 'do-registry-creds', usernameVariable: 'DO_USER', passwordVariable: 'DO_PASS'),
                    ]) {
                        sh '''
                            echo "$DO_PASS" | buildah --storage-driver=vfs login --username "$DO_USER" --password-stdin registry.digitalocean.com
                            buildah bud --storage-driver=vfs --no-cache --target prod \
                                --build-arg PUBLIC_SHA="$PUBLIC_SHA" \
                                --build-arg PAC_GENERATOR_SHA="$PAC_GENERATOR_SHA" \
                                --build-arg PAC_SOURCE_DATE="$PAC_SOURCE_DATE" \
                                -f ./Dockerfile -t "$DOCKER_REGISTRY/$APP_NAME:$IMAGE_TAG" .
                        '''
                    }
                }
            }
        }

        stage('Push') {
            when { expression { env.SHOULD_RUN == 'true' } }
            steps {
                container('buildah') {
                    sh '''
                        buildah push --storage-driver=vfs "$DOCKER_REGISTRY/$APP_NAME:$IMAGE_TAG"
                        buildah rmi --storage-driver=vfs "$DOCKER_REGISTRY/$APP_NAME:$IMAGE_TAG"
                    '''
                }
            }
        }

        stage('Deploy') {
            when { expression { env.SHOULD_RUN == 'true' } }
            steps {
                container('deploy') {
                    dir("helm/${env.BRANCH_NAME}") {
                        script {
                            try {
                                sh '''
                                    set -eu
                                    unset KUBECONFIG
                                    helmwave up --build --kubedog --show-secret=false -t new-cluster
                                '''
                            } catch (Exception e) {
                                echo "Deploy ${APP_NAME}/${env.BRANCH_NAME} failed. Performing rollback."
                                sh '''
                                    unset KUBECONFIG
                                    helmwave rollback -t new-cluster || echo "WARNING: rollback failed"
                                '''
                                throw e
                            }
                        }
                    }
                }
            }
        }
    }

    post {
        failure {
            script {
                if (env.BRANCH_NAME == 'main' && env.SHOULD_RUN == 'true') {
                    withCredentials([
                        string(credentialsId: 'ci_telegram_bot_token', variable: 'TG_TOKEN'),
                        string(credentialsId: 'ci_telegram_chan_id',   variable: 'TG_CHAN'),
                    ]) {
                        sh """curl --data "parse_mode=HTML" --data "chat_id=${TG_CHAN}" --data "text=<b>${JOB_NAME}-${env.BRANCH_NAME}</b>%0Adeploy failed! (╯°□°)╯︵┻━┻%0A${BUILD_URL}" -X POST "https://api.telegram.org/${TG_TOKEN}/sendMessage" """
                    }
                }
            }
        }
        success {
            script {
                if (env.BRANCH_NAME == 'main' && env.SHOULD_RUN == 'true') {
                    withCredentials([
                        string(credentialsId: 'ci_telegram_bot_token', variable: 'TG_TOKEN'),
                        string(credentialsId: 'ci_telegram_chan_id',   variable: 'TG_CHAN'),
                    ]) {
                        sh """curl --data "parse_mode=HTML" --data "chat_id=${TG_CHAN}" --data "text=<b>${JOB_NAME}-${env.BRANCH_NAME}</b>%0Adeploy done%0A${BUILD_URL}" -X POST "https://api.telegram.org/${TG_TOKEN}/sendMessage" """
                    }
                }
            }
        }
    }
}
