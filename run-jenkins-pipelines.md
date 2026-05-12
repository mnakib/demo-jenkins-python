Jenkins-Pipeline

This guide follows the "Pipeline as Code" philosophy, where your automation steps live inside your GitHub repository in a file called a Jenkinsfile.

## 0. Prepare the Prereq

### 0.1 Install Docker

Instructions for [installing Docker](https://docs.docker.com/engine/install/rhel/) are found [here](https://docs.docker.com/engine/install/rhel/)

```bash
sudo dnf remove -y docker \
    docker-client \
    docker-client-latest \
    docker-common \
    docker-latest \
    docker-latest-logrotate \
    docker-logrotate \
    docker-engine \
    podman \
    runc
```
```bash
sudo dnf install -y dnf-plugins-core
sudo dnf config-manager --add-repo https://download.docker.com/linux/rhel/docker-ce.repo
```
```bash
sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```
```bash
# Add your user to the docker group. This allows you to run Docker command without needins sudo.
sudo usermod -aG docker $(whoami)

# Run the newgrp command to change the current active user group (effective GID) within a session.
newgrp docker
```
```bash
# Enable and start docker service
sudo systemctl enable --now docker
```
```bash
# Run a test container
docker run hello-world
```



### 0.2 Install Jenkins

__Add the Jenkins Repository__ 

Download the repo file

```bash
sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
```

Import the GPG key

```bash
sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
```

__Install Java and Jenkins__


Install dependencies:

```bash
sudo dnf install fontconfig java-21-openjdk -y
```

    > Run `java -version`. If it still shows an older version (like Java 11 or 17), you may need to update the system default by running the `sudo update-alternatives --config java` command and choose the appropriate version, which is in this case version 21.


Install Jenkins

```bash
sudo dnf install jenkins -y 
```

```bash
# Add the jenkins user to the docker group. This allows it to run Docker command without needins sudo.
sudo usermod -aG docker jenkins

# Run the newgrp command to change the current active user group (effective GID) within a session.
newgrp docker

# Sometimes the socket itself needs a permissions nudge to recognize the new group membership immediately
sudo chmod 666 /var/run/docker.sock
```


__Start and Enable Jenkins__

```bash
# Reload systemd
sudo systemctl daemon-reload

# Start and enable the service
sudo systemctl enable --now jenkins
```

__Configure Firewall__

```bash
# Add port
sudo firewall-cmd --permanent --add-port=8080/tcp
# Apply changes
sudo firewall-cmd --reload
```

__Complete Web Setup__

Retrieve the initial __administrator password__ from your terminal:

```bash
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

Access the web interface at `http://your_server_ip:8080`

Paste this password into the browser to unlock the setup. Select __"Install suggested plugins"__ and create your first __Admin User__.


### 0.3  Initialize a local repository

Create a working directory

```bash
WORKING_DIR=jenkins-demo
mkdir ${WORKING_DIR} && cd ${WORKING_DIR}
```

Initialize the local repository. Using `-b main` sets your default branch name to __"main"__

```bash
git init -b main
```

Check the current state of the repository

```bash
git status
```

Stage and commit your files

```bash
git add .
git commit -m "Initial commit"
```


### 0.4 Create a new repository on GitHub and link the local repo to it

__Create a new repository on GitHub__

On [GitHub](https://github.com/), create a new repo, for instance, `jenkins-demo` or any other name suitable for you.
__Do not__ initialize it with a README, license, or `.gitignore` file yet to avoid merge conflicts.

__Link the local repo to GitHub__

Copy the remote repository URL from GitHub's "Quick Setup" page and add it as a remote named __"origin"__.

On your terminal, initialize variables specific to your environment

```bash
# Initialize variables specific to your environment
GITHUB_USERNAME=<YOUR_GITHUB_USERNAME>
GITHUB_REPOSITORY_NAME=<YOUR_REPOSITORY_NAME>
```
```bash
git remote add origin \
  https://github.com/${GITHUB_USERNAME}/${GITHUB_REPOSITORY_NAME}.git
```


### 0.5. Create the Python App (GitHub)


#### 0.5.1 The App `app.py` file

Create the Python application file, named `app.py`, containing a simple calculator script with a built-in test.

```python
cat > app.py << EOF

from flask import Flask

app = Flask(__name__)

@app.route("/")
def hello_world():
    return "<p>Hello, World!</p>"

if __name__ == "__main__":
    app.run(debug=True, host='0.0.0.0', port=5000)

EOF
```


#### 0.5.2 The Test `test.py` file
```python
cat > _test.py << EOF

import pytest
from app import app

@pytest.fixture
def client():
    app.config['TESTING'] = True
    with app.test_client() as client:
        yield client


def test_app_is_working(client):
    response = client.get('/')
    assert response.status_code == 200
    assert b"Hello, World!" in response.data

EOF
```

#### 0.5.3 The `requirements.txt` file

```text
cat > requirements.txt << EOF

Flask==2.2.3
pytest>=5.0.0

EOF
```

#### 0.5.4 The `Dockerfile`

```Dockerfile
cat > Dockerfile << EOF

FROM python:3.8
WORKDIR /app
COPY . /app
RUN pip install flask
EXPOSE 8080
ENTRYPOINT ["python"]
CMD ["app.py"]

EOF
```


### 0.6 Create the Pipeline `Jenkinsfile`

Create the Jenkins pipeline file. This file must be called `Jenkinsfile` and it defines the "DevOps steps": pulling code, setting up Python, and running tests.

```groovy
pipeline {
    agent any
    environment {
        IMAGE_NAME = "python-flask-app"
        DOCKER_HUB = credentials('docker-hub-creds')
        // Change GITHUB_USERNAME & GITHUB_REPOSITORY_NAME values accordingly
        GITHUB_USERNAME="mnakib"
        GITHUB_REPOSITORY_NAME="jenkins-demo"
    }
    stages {
        stage('Checkout Source') {
            steps {
                // Pull the code from your repository
                git branch: 'main', url: "https://github.com/${GITHUB_USERNAME}/${GITHUB_REPOSITORY_NAME}.git"
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
                sh "echo ${DOCKER_HUB_PSW} | docker login -u ${DOCKER_HUB_USR} --password-stdin"
                sh "docker push ${DOCKER_HUB_USR}/${IMAGE_NAME}:latest"
            }
        }
    }
}
```

### 0.7 Commit and push to GitHub

Stage and commit your files

```bash
git add .
git commit -m "Required files added - app, test, requirements, Dockerfile, Jenkinsfile"
```

Push to GitHub

```bash
# Optional - Temporarily store your HTTPS credentials in memory - default timeout is 15 minutes. This can be be changed with the 'cache --timeout=3600' option
git config --global credential.helper cache

# Push your changes to the main branch
git push -u origin main
```





## 3. Configure Jenkins

### 3.1 Authenticate Jenkins with GitHub

You must provide Jenkins with credentials to access your GitHub repositories, especially for private ones. 

### 3.2 Configure Jenkins with Docker Hub Registry Credentials

So that Jenkins is able to push images to an image registry, like Docker Hub, Amazon ECR, or a private registry, you need to add the registry credentials of the specific registry you intend to use.

- Go to **Manage Jenkins > Credentials > System > Global credentials**.
- **Add Your Details:** Click **Add Credentials**, select **Username with password**, and enter your Docker Hub username and password (or Access Token).
- **Define the ID:** In the ID field, type a name: `docker-hub-creds`.
- **Update Your Code:** Use that exact name in your pipeline. That is the  which is `DOCKER_HUB = credentials('docker-hub-creds')`

### 3.2 Configure the Pipeline

1. **Open Jenkins:** Go to `http://localhost:8080` in your browser.
2. **Unlock:** Paste the password from the logs and select **"Install Suggested Plugins."**
3. **Create Job:** * Click **New Item**.
* Enter name: `Python-App-Pipeline`.
* Select **Pipeline** and click OK.
4. **Connect GitHub:**
* Scroll to the **Pipeline** section.
* Change **Definition** to **Pipeline script from SCM**.
* Change **SCM** to **Git**.
* Enter your GitHub URL in **Repository URL**.
* Ensure the branch is correct (usually `*/main`).
* Verify the Script Path field displays `Jenkinsfile`.
* Click **Save**.


## 4. Run the Pipeline

Click **Build Now** on the left menu. Jenkins will:

1. **Clone** your code from GitHub.
2. **Run** the `python:3.9-slim bash` container and install the `flask` and `pytest` packages.
3. **Execute** the `pytest` command for running the test against the running flask `app` application.
4. **Build** an image using the Dockerfile instructions, tagging it as docker.io/<IMAGE_REPOSITORY_USERNAME>/python-flask-app:latest
5. **Push** the resulting image to the Docker Hub image registry.
---


## 5. Check the image

Check that the image was pused successfully to the Docker Hub registry.

```bash
# Initialize the IMAGE_REPOSITORY_USERNAME variable
IMAGE_REPOSITORY_USERNAME=mouradn81

# Check the image existence in Docker Hub using the skopeo command
skopeo inspect docker://docker.io/${IMAGE_REPOSITORY_USERNAME}/python-flask-app:latest
```

Run a Docker container from the resulting image and verify it runs successully

```bash
docker run --name flask-app -d -p 5000:5000 docker.io/${IMAGE_REPOSITORY_USERNAME}/python-flask-app:latest
```

```bash
curl localhost:5000
```
```text
<p>Hello, World!</p>
```






Updated the Jenkinsfile to add a step to deploy the image to an OpenShift cluster. 

```groovy
        stage('Deploy to OpenShift') {
            steps {
                script {
                    // Define your target namespace and deployment name
                    def NAMESPACE_NAME = "default"
                    def DEPLOYMENT_NAME = "python-flask-app"
                    // Login, create the namespace if doesn't exist then swith to it
                    // create the app if it doesn't exist, or update the image if it does
                    sh """
                    oc login ${OCP_API} -u ${OCP_USER} -p ${OCP_PASS} --insecure-skip-tls-verify   
                    oc new-project ${NAMESPACE_NAME} || echo "Namespace already exists"
                    oc project ${NAMESPACE_NAME}
                    oc create deployment ${DEPLOYMENT_NAME} --image ${IMAGE_PATH} --namespace=${NAMESPACE_NAME} || oc patch deployment/${IMAGE_NAME} -p '{"spec":{"template":{"spec":{"containers":[{"name":"${IMAGE_NAME}","image":"${IMAGE_PATH}"}]}}}}'
                    # Expose the deployment
                    oc expose deployment ${DEPLOYMENT_NAME} --target-port 5000 --port 80 --namespace=${NAMESPACE_NAME}
                    # Expose the deployment
                    oc expose svc/${IMAGE_NAME} --namespace=${NAMESPACE_NAME} || echo "Route already exists" 
                    """
                }
            }
        }
```


The complete file would look like this

```groovy
pipeline {
    agent any
    environment {
        IMAGE_NAME = "python-flask-app"
        DOCKER_HUB = credentials('docker-hub-creds')
        // Change GITHUB_USERNAME & GITHUB_REPOSITORY_NAME values accordingly
        GITHUB_USERNAME="mnakib"
        GITHUB_REPOSITORY_NAME="jenkins-demo-bis"
        OCP_API = "https://api.ocp4.example.com:6443"
        OCP_USER = "admin"
        OCP_PASS = "redhatocp"
        IMAGE_PATH = "docker.io/mouradn81/python-flask-app:latest"
    }
    stages {
        stage('Checkout Source') {
            steps {
                // Pull the code from your repository
                git branch: 'main', url: "https://github.com/${GITHUB_USERNAME}/${GITHUB_REPOSITORY_NAME}.git"
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
                sh "echo ${DOCKER_HUB_PSW} | docker login -u ${DOCKER_HUB_USR} --password-stdin"
                sh "docker push ${DOCKER_HUB_USR}/${IMAGE_NAME}:latest"
            }
        }
        stage('Deploy to OpenShift') {
            steps {
                script {
                    // Define your target namespace and deployment name
                    def NAMESPACE_NAME = "default"
                    def DEPLOYMENT_NAME = "python-flask-app"
                    // Login, create the namespace if doesn't exist then swith to it
                    // create the app if it doesn't exist, or update the image if it does
                    sh """
                    oc login ${OCP_API} -u ${OCP_USER} -p ${OCP_PASS} --insecure-skip-tls-verify   
                    oc new-project ${NAMESPACE_NAME} || echo "Namespace already exists"
                    oc project ${NAMESPACE_NAME}
                    oc create deployment ${DEPLOYMENT_NAME} --image ${IMAGE_PATH} --namespace=${NAMESPACE_NAME} || oc patch deployment/${IMAGE_NAME} -p '{"spec":{"template":{"spec":{"containers":[{"name":"${IMAGE_NAME}","image":"${IMAGE_PATH}"}]}}}}'
                    # Expose the deployment
                    oc expose deployment ${DEPLOYMENT_NAME} --target-port 5000 --port 80 --namespace=${NAMESPACE_NAME}
                    # Expose the deployment
                    oc expose svc/${IMAGE_NAME} --namespace=${NAMESPACE_NAME} || echo "Route already exists" 
                    """
                }
            }
        }
    }
}
```








## DevSecOps Pipeline



### Integrate Jenkins with SonarQube

You need to authenticate Jenkins against SonarQube, by generating a token in SonarQube then adding it to Jenkins.

1. **Generate the Token in SonarQube:**
* Log into SonarQube (`localhost:9000`).
* Go to **My Account** > **Security**.
* Give the token a name (e.g., "Jenkins-Scanner") and click **Generate**.
* **Copy this token immediately** (you won't see it again).


2. **Add it to Jenkins:**
* Go to your Jenkins Dashboard.
* Click **Manage Jenkins** > **Credentials**.
* Click on the **(global)** domain.
* Click **Add Credentials** on the top right.
* **Kind:** Select **Secret text**.
* **Secret:** Paste the token you copied from SonarQube.
* **ID:** Enter `sonar-token` (This **must** match the name in your pipeline code).
* Click **Create**.




```groovy
pipeline {
    agent any
    environment {
        IMAGE_NAME = "python-flask-app"
        DOCKER_HUB = credentials('docker-hub-creds')
        // Change GITHUB_USERNAME & GITHUB_REPOSITORY_NAME values accordingly
        GITHUB_USERNAME="mnakib"
        GITHUB_REPOSITORY_NAME="jenkins-demo-bis"
        OCP_API = "https://api.ocp4.example.com:6443"
        OCP_USER = "admin"
        OCP_PASS = "redhatocp"
        IMAGE_PATH = "docker.io/mouradn81/python-flask-app:latest"
        // Security Tool Configs (Examples)
        SONAR_TOKEN = credentials('sonar-token')
        SONAR_HOST  = "http://your-sonar-server:9000"
    }
    stages {
        stage('Checkout Source') {
            steps {
                git branch: 'main', url: "https://github.com/${GITHUB_USERNAME}/${GITHUB_REPOSITORY_NAME}.git"
            }
        }

        // --- DEVSECOPS START: SAST & SCA ---
        stage('SAST & SCA Scans') {
            steps {
                script {
                    // 1. SAST (Static Code Analysis)
                    // If Sonar finds issues above your threshold, the 'exit 1' will fail the build
                    sh """
                        docker run --rm --network host \
                        -v \$(pwd):/usr/src sonarsource/sonar-scanner-cli \
                        -Dsonar.projectKey=${IMAGE_NAME} \
                        -Dsonar.sources=. \
                        -Dsonar.host.url=${SONAR_HOST} \
                        -Dsonar.login=${SONAR_TOKEN}
                    """

                    // 2. SCA (Software Composition Analysis)
                    // --failOnCVSS 7 ensures the build fails if a High/Critical vulnerability is found
                    sh """
                        docker run --rm -v \$(pwd):/src -v \$(pwd)/odc-reports:/report \
                        owasp/dependency-check --project "Flask-App" --scan /src \
                        --format "ALL" --out /report --failOnCVSS 7
                    """
                }
            }
        }
        // --- DEVSECOPS END ---

        stage('Build & Test') {
            steps {
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
        stage('Deploy to OpenShift') {
            steps {
                script {
                    def NAMESPACE_NAME = "python-flask-ns"
                    def DEPLOYMENT_NAME = "python-flask-app"
                    sh """
                    oc login ${OCP_API} -u ${OCP_USER} -p ${OCP_PASS} --insecure-skip-tls-verify   
                    oc new-project ${NAMESPACE_NAME} || echo "Namespace already exists"
                    oc project ${NAMESPACE_NAME}
                    oc create deployment ${DEPLOYMENT_NAME} --image ${IMAGE_PATH} --namespace=${NAMESPACE_NAME} || oc patch deployment/${IMAGE_NAME} -p '{"spec":{"template":{"spec":{"containers":[{"name":"${IMAGE_NAME}","image":"${IMAGE_PATH}"}]}}}}'
                    oc expose deployment ${DEPLOYMENT_NAME} --target-port 5000 --port 80 --namespace=${NAMESPACE_NAME}
                    oc expose svc/${IMAGE_NAME} --namespace=${NAMESPACE_NAME} || echo "Route already exists" 
                    """
                }
            }
        }

        // --- DEVSECOPS START: DAST ---
        stage('DAST Scan') {
            steps {
                script {
                    // We get the route URL from OpenShift to scan it
                    def APP_URL = sh(script: "oc get route ${IMAGE_NAME} -n python-flask-ns -o jsonpath='{.spec.host}'", returnStdout: true).trim()
                    
                    // Run OWASP ZAP Baseline scan. 
                    // The '-c' flag can point to a config file to fail the build on specific alerts.
                    sh "docker run --rm -t owasp/zap2docker-stable zap-baseline.py -t http://${APP_URL}"
                }
            }
        }
        // --- DEVSECOPS END ---
    }
}
```













