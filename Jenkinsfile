#!groovy

pipeline {
    options {
        timestamps()
        disableConcurrentBuilds()
        quietPeriod(30)
    }

    agent none

    stages {
        stage('Run AWS Template Tests') {
            agent {
                label 'codeontaplatest'
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
                beforeAgent true
            }
            agent none
            steps {
                build (
                    job: '../docker-gen3/master'
                )
            }
        }
    }
}
