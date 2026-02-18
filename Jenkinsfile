pipeline {
    agent any

    environment {
        // Replace with your Docker Hub username
        DOCKER_HUB_USER = 'your-username'
        IMAGE_NAME = "python-flask-app"
        DOCKER_IMAGE = 'python-flask-app'
        DOCKER_HUB_CREDS = credentials('docker-hub-credentials')
    }

    stages {
        stage('Checkout') {
            steps {
                // Cloning the specific branch
                git branch: 'main', url: 'https://github.com/mouradn81/demo-jenkins-python.git'
            }
        }

        stage('Build & Test') {
            steps {
                script {
                    // Using a python docker container to keep the Jenkins agent clean
                    docker.image('python:3.9-slim').inside {
                        sh '''
                            pip install flask pytest
                            pytest
                        '''
                    }
                }
            }
        }

        stage('Build Docker Image') {
            when {
                expression { currentBuild.result == null || currentBuild.result == 'SUCCESS' }
            }
            steps {
                script {
                    // Builds the image using the Dockerfile in your repo
                    appImage = docker.build("${DOCKER_HUB_USER}/${IMAGE_NAME}:${env.BUILD_NUMBER}")
                    appImage.push()
                    appImage.push('latest')
                }
            }
        }

        stage('Push to Docker Hub') {
            steps {
                script {
                    docker.withRegistry('https://index.docker.io/v1/', 'docker-hub-credentials') {
                        appImage.push()
                        appImage.push('latest')
                    }
                }
            }
        }
    }

    post {
        always {
            cleanWs()
        }
        failure {
            echo "Pipeline failed. Check the test logs or Docker credentials."
        }
    }
}
