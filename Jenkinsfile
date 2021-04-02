#!groovy

def slackChannel = '#devops-framework'

pipeline {
    options {
        timeout(time: 2, unit: 'HOURS')
    }

    agent {
        label 'hamlet-latest'
    }

    environment {
        HAMLET_CLONE_ROOT       = '/tmp/hamlet-latest'
        GENERATION_BASE_DIR     = '/tmp/hamlet-latest/executor'
        GENERATION_DIR          = '/tmp/hamlet-latest/executor/cli'
        GENERATION_PLUGIN_DIRS  = ''
    }


    stages {

        stage('Setup') {
            steps {
                sh '''#!/usr/bin/env bash
                    curl -L https://raw.githubusercontent.com/hamlet-io/hamlet-bootstrap/master/install.sh | bash
                    pip install hamlet-cli
                '''
            }
        }

        stage('Run AWS Template Tests') {
            environment {
                GENERATION_PLUGIN_DIRS="${WORKSPACE}"
                TEST_OUTPUT_DIR='./hamlet_tests'
            }
            steps {
                sh '''#!/usr/bin/env bash
                    ./test/run_aws_template_tests.sh
                '''
            }
            post {
                always {
                    junit 'hamlet_tests/junit.xml'
                }
            }
        }

        stage('Trigger Docker Build') {
            when {
                branch 'master'
            }

            steps {
                build (
                    job: '../docker-hamlet/master',
                    wait: false
                )
            }
        }
    }

    post {
        failure {
            slackSend (
                message: "*Failure* | <${BUILD_URL}|${JOB_NAME}>",
                channel: "${slackChannel}",
                color: "#D20F2A"
            )
        }
    }
}
