#!groovy

pipeline {
    options {
        timestamps()
        quietPeriod(30)
    }

    agent {
        label 'hamlet-latest'
    }

    stages {
        stage('Run AWS Template Tests') {
            agent {
                label 'hamlet-latest'
            }
            environment {
                GENERATION_PLUGIN_DIRS="${WORKSPACE}"
            }
            steps {
                sh '''#!/usr/bin/env bash
                    ./test/run_aws_template_tests.sh
                '''
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
}
