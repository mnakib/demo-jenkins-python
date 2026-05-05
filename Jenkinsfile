pipeline {
    agent any
    environment {
        // The DOCKER_HUB instructuion replaces both DOCKER_HUB_USER and REGISTRY_CREDENTIALS_ID
        DOCKER_HUB = credentials('docker-hub-creds')
        IMAGE_NAME = "python-jenkins-demo"
        // Define the ID here so you can reuse it easily
        REGISTRY_ID = 'docker-hub-creds'
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
                sh "docker build -t ${DOCKER_HUB_USER}/${IMAGE_NAME}:latest ."
                sh "echo $DOCKER_HUB_PSW | docker login -u $DOCKER_HUB_USER --password-stdin"
                sh "docker push ${DOCKER_HUB_USER}/${IMAGE_NAME}:latest"
            }
        }
    }
}
