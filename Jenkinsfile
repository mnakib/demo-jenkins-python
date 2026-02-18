pipeline {
    agent any
    environment {
        PATH = "/opt/homebrew/bin:/usr/local/bin:${env.PATH}"
        IMAGE_NAME = "python-flask-app"
        DOCKER_HUB = credentials('docker-hub-credentials')
    }
    stages {
        stage('Checkout Source') {
            steps {
                // 1. Pull the code from your repository
                git branch: 'main', url: 'https://github.com/mnakib/demo-jenkins-python.git'
            }
        }
        stage('Build & Test') {
            steps {
                // Instead of docker.inside, we run a container manually
                sh '''
                    docker run --rm -v $(pwd):/app -w /app python:3.9-slim bash -c "
                        pip install flask pytest && 
                        pytest
                    "
                '''
            }
        }
        stage('Build & Push') {
            steps {
                sh "docker build -t ${DOCKER_HUB_USR}/${IMAGE_NAME}:latest ."
                sh "echo $DOCKER_HUB_PSW | docker login -u $DOCKER_HUB_USR --password-stdin"
                sh "docker push ${DOCKER_HUB_USR}/${IMAGE_NAME}:latest"
            }
        }
    }
}
