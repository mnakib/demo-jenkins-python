Jenkins-Pipeline

This guide follows the "Pipeline as Code" philosophy, where your automation steps live inside your GitHub repository in a file called a Jenkinsfile.

## 0. Prepare the Prereq

### 0.1 Install Docker

Instructions for [installing Docker](https://docs.docker.com/engine/install/rhel/) are found [here](https://docs.docker.com/engine/install/rhel/)

```bash
sudo dnf remove docker \
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
sudo dnf -y install dnf-plugins-core
sudo dnf config-manager --add-repo https://download.docker.com/linux/rhel/docker-ce.repo
```
```bash
sudo dnf install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```
```bash
# Add the jenkins user to the docker group. This allows it to run Docker command without needins sudo
sudo usermod -aG docker jenkins

# Sometimes the socket itself needs a permissions nudge to recognize the new group membership immediately
sudo chmod 666 /var/run/docker.sock
```
```bash
# Enable and start docker service
sudo systemctl enable --now docker
```
```bash
# Run a test container
sudo docker run hello-world
```



### 0.2 Install Jenkins

__Add the Jenkins Repository 

Download the repo file

```bash
sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.rep
```

Import the GPG key

```bash
sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
```

__Install Java and Jenkins__


Install dependencies:

```bash
sudo dnf install fontconfig java-17-openjdk -y
```

Install Jenkins

```bash
sudo dnf install jenkins -y 
```

__Start and Enable Jenkins__

```bash
# Reload systemd
sudo systemctl daemon-reload

# Start and enable the service
sudo systemctl start jenkins
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
mkdir python-jenkins-demo && cd python-jenkins-demo
```

Initialize the local repository. Using `-b main` sets your default branch name to __"main"__

```bash
git init -b main
```

Stage and commit your files

```bash
git add .
git commit -m "Initial commit"
```


### 0.4 Create a new repository on GitHub and link the local repo to it

Create a new repository on GitHub. For instance, `python-jenkins-demo`.
__Do not__ initialize it with a README, license, or `.gitignore` file yet to avoid merge conflicts.

Link the local repo to GitHub

Copy the remote repository URL from GitHub's "Quick Setup" page and add it as a remote named __"origin"__.

```bash
git remote add origin https://github.com/USERNAME/REPOSITORY-NAME.git
```


### 0.5. Create the Python App (GitHub)


#### 0.5.1 The App `app.py` file

Create the Python application file, named `app.py`, containing a simple calculator script with a built-in test.

```bash
cat > app.py
```
```python
from flask import Flask

app = Flask(__name__)

@app.route("/")
def hello_world():
    return "<p>Hello, World!</p>"

if __name__ == "__main__":
    app.run(debug=True, host='0.0.0.0', port=5000)
```


#### 0.5.2 The Test `test.py` file
```bash
cat > test.py
```
```python
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
```

#### 0.5.3 The `requirements.txt` file

```bash
cat > requirements.txt
```
```text
Flask==2.2.3
pytest>=5.0.0
```

#### 0.5.4 The `Dockerfile`

```bash
cat > Dockerfile
```
```Dockerfile
FROM python:3.8
WORKDIR /app
COPY . /app
RUN pip install flask
EXPOSE 8080
ENTRYPOINT ["python"]
CMD ["app.py"]
```



### 0.6 Create the Pipeline `Jenkinsfile`

Create the Jenkins pipeline file. This file must be called `Jenkinsfile` and it defines the "DevOps steps": pulling code, setting up Python, and running tests.

```groovy
pipeline {
    agent any
    environment {
        IMAGE_NAME = "python-flask-app"
        DOCKER_HUB = credentials('docker-hub-credentials')
    }
    stages {
        stage('Checkout Source') {
            steps {
                // Pull the code from your repository
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
```

### 0.6 Commit and push to GitHub

Stage and commit your files

```bash
git add .
git commit -m "Initial commit"
```

Push to GitHub

```bash
git push -u origin main
```





## 3. Configure Jenkins

### 3.1 Authenticate Jenkins with GitHub

You must provide Jenkins with credentials to access your GitHub repositories, especially for private ones. 




### 3.2 Configure the Pipeline

1. **Open Jenkins:** Go to `http://localhost:8080` in your browser.
2. **Unlock:** Paste the password from the logs and select **"Install Suggested Plugins."**
3. **Create Job:** * Click **New Item**.
* Enter name: `Python-App-Pipeline`.
* Select **Pipeline** and click OK.
4. **Connect GitHub:**
* Scroll to the **Pipeline** section.
* Change "Definition" to **Pipeline script from SCM**.
* Select **Git**.
* Paste your **GitHub Repository URL**.
* Ensure the branch is correct (usually `*/main`).
* Click **Save**.


## 4. Run the Pipeline

Click **Build Now** on the left menu. Jenkins will:

1. **Clone** your code from GitHub.
2. **Execute** the `sh 'python3 app.py'` command defined in your `Jenkinsfile`.
3. **Report** success or failure in the **Stage View** dashboard.

---

## 5. What's the "Next Step" in the DevOps Lifecycle?

Right now, your app runs, tests itself, and then... nothing. It just stays inside the Jenkins workspace. In a real-world scenario, the "Deploy" stage would follow:

1. **Artifact Creation:** Jenkins zips up the code or builds a *new* Docker image of just the app.
2. **Deployment:** Jenkins pushes that image to a production server (like AWS, Azure, a Kubernetes or OpenShift clustre,  or another Podman container).

To showcase the progression of a DevOps pipeline, we will move from simply "testing" the code to "packaging" it and finally "deploying" it.

Fow now, let's define a pipeline that just creates an image artifact and pushes it to image registry. We're using _Docker Hub_ in this pipeline example.

But before, Jenkins must be able to 

**- 1 Build the image:** which will need to install the _Docker plugin_ in Jenkins.

**- 2 Connect to the image registry:** which in this case _Docker Hub_ to be able to push it after the build is done.


### Install the Docker plugin

Installing the Docker plugin allows to use the `docker.build()` syntax in the pipeline to build the image.

- Go to **Manage Jenkins > Plugins > Available Plugins.**
- Search for and install **Docker Pipeline** (also known as docker-workflow).
- **Restart Jenkins** after installation.


### Configure the image registry credentials in Jenkins

- **Create Credentials:** Go to **Manage Jenkins > Credentials > System > Global credentials**.
- **Add Your Details:** Click **Add Credentials**, select **Username with password**, and enter your Docker Hub username and password (or Access Token).
- **Define the ID:** In the ID field, type a name: `docker-hub-creds`.
- **Update Your Code:** Use that exact name in your pipeline. That is the  which is `DOCKER_HUB = credentials('docker-hub-creds')`

### Install the Docker plugin

Installing the Docker plugin allows to use the `docker.build()` syntax in the pipeline to 




```groovy
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
        stage('Build & Test') {
            steps {
                sh 'python3 app.py'
            }
        }
        stage('Create Docker Artifact') {
            steps {
                script {
                    // Force the full name into a variable to ensure consistency
                    def fullImageName = "${DOCKER_HUB_USR}/${IMAGE_NAME}:${env.BUILD_NUMBER}"

           
                    // USE --load to ensure the image is available in 'docker images'
                    // Use 'sh' to bypass the Docker Buildx "container" plugin's driver issues
                    sh "docker build --load -t ${fullImageName} ."

                    // Build the image
                    appImage = docker.build(fullImageName)

                // DEBUG: List images to ensure it actually exists in the local daemon
                sh "docker images | grep ${IMAGE_NAME}"
                }
            }
        }
        stage('Push to Registry') {
            steps {
                script {
                    // Use credentials stored in Jenkins to log in and push
                    docker.withRegistry('', 'docker-hub-creds') {
                        appImage.push()
                        appImage.push('latest')
                    }
                }
            }
        }
        stage('Deploy or Update') {
            steps {
                script {
                    // "cluster-name" should match the name defined in Jenkins -> Manage Jenkins -> Configure System
                    openshift.withCluster('my-cluster-name') {
                        openshift.withProject('my-namespace') {
                            
                            // 1. Apply the manifest (Creates if missing, updates if exists)
                            // This is equivalent to 'oc apply -f ...'
                            openshift.apply(readFile('k8s/deployment.yaml'))
                            
                            // 2. Set the new image tag
                            // This triggers a rolling update to the specific build version
                            def dc = openshift.selector('deployment', 'my-app')
                            dc.patch("{\"spec\":{\"template\":{\"spec\":{\"containers\":[{\"name\":\"my-app-container\",\"image\":\"${IMAGE_URL}:${BUILD_NUMBER}\"}]}}}}")
                            
                            // 3. Optional: Verify the rollout status
                            def latestRollout = dc.rollout()
                            latestRollout.status()
                        }
                    }
                }
            }
        }
        stage('Deploy or Update') {
            steps {
                script {
                    openshift.withCluster('my-cluster-name') {
                        // Check if project exists, create if it doesn't
                        def projectExists = openshift.raw("projects").out.contains("my-namespace")
                        
                        if (!projectExists) {
                            openshift.raw("new-project", "my-namespace", "--display-name='My App Project'")
                        }

                        openshift.withProject('my-namespace') {
                            // Apply your YAML
                            openshift.apply(readFile('k8s/deployment.yaml'))
                            
                            // Update the image
                            def dc = openshift.selector('deployment', 'my-app')
                            dc.patch("{\"spec\":{\"template\":{\"spec\":{\"containers\":[{\"name\":\"my-app-container\",\"image\":\"${IMAGE_URL}:${BUILD_NUMBER}\"}]}}}}")
                        }
                    }
                }
            }
        }
    }
    post {
        always {
            // Best practice to remove the build workspace and local docker images to save space
            cleanWs()
            sh "docker rmi ${DOCKER_HUB_USR}/${IMAGE_NAME}:${env.BUILD_NUMBER} || true"
        }
    }
}
```



To showcase the progression of a DevOps pipeline, we will move from simply "testing" the code to "packaging" it and finally "deploying" it.






## 2. Run Jenkins in Podman

Create a custom image Jenkins that includes Python and Docker. The reason being that the default jenkins image does not inlude Python not Docker. And because we are building a Python application and pushing it to an image registry, we will need both Python and Docker installed in the image.

cat > Containerfile

```dockerfile
# Start from the standard Jenkins LTS image
FROM jenkins/jenkins:lts

# Switch to root user to install software
USER root

# Install Python 3 and pip
RUN apt-get update && \
    apt-get install -y python3 python3-pip python3-venv docker.io zip && \
    rm -rf /var/lib/apt/lists/*

# Switch back to the standard jenkins user
USER jenkins
```

Create the image

```bash
podman build -t python-jenkins .
```

Run the container by mounting the Podman socket when you start Jenkins, using the `-v /run/user/$(id -u)/podman/podman.sock:/var/run/docker.sock` parameter

```bash
# This allows the Jenkins container to 'borrow' your computer's Podman engine
podman run -d \
  --name jenkins-python \
  -p 8080:8080 \
  -v /run/user/$(id -u)/podman/podman.sock:/var/run/docker.sock \
  -v jenkins_home:/var/jenkins_home \
  python-jenkins
```

Display the container logs and scroll down to get the Jenkins GUI Web console password

```bash
podman logs jenkins-python
```

```text
*************************************************************
Jenkins initial setup is required. An admin user has been created and a password generated.
Please use the following password to proceed to installation:

[32-CHARACTER-CODE-HERE]

This may also be found at: /var/jenkins_home/secrets/initialAdminPassword
*************************************************************
```


### Create Dockerfile.app (In GitHub)

Create "blueprint" for your application artifact.

### Create the Jenkinsfile

```groovy
pipeline {
    agent any
    environment {
        // Replace with your Docker Hub username
        DOCKER_HUB_USER = 'your-username'
        IMAGE_NAME = "python-jenkins-demo"
        REGISTRY_CREDENTIALS_ID = 'docker-hub-login' 
    }
    stages {
        stage('Build & Test') {
            steps {
                sh 'python3 app.py'
            }
        }
        stage('Create Docker Artifact') {
            steps {
                script {
                    // Build the image using the Dockerfile in the repo
                    appImage = docker.build("${DOCKER_HUB_USER}/${IMAGE_NAME}:${env.BUILD_NUMBER}")
                }
            }
        }
        stage('Push to Registry') {
            steps {
                script {
                    // Use credentials stored in Jenkins to log in and push
                    docker.withRegistry('', REGISTRY_CREDENTIALS_ID) {
                        appImage.push()
                        appImage.push('latest')
                    }
                }
            }
        }
    }
}
```















