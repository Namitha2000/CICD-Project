pipeline {
    agent any

    tools {
        jdk 'jdk17'
        maven 'maven3'
    }

    parameters {
        choice(
            name: 'BRANCH',
            choices: ['dev', 'UIT', 'master'],
            description: 'Select branch to build'
        )
        string(name: 'sonar_IP',        defaultValue: '13.63.34.172',                                               description: 'SonarQube Server IP')
        string(name: 'docker_build_IP', defaultValue: '<YOUR_BUILD_SERVER_IP>',                                      description: 'IP of server for Docker Build')
        string(name: 'deploy_IP',       defaultValue: '13.50.101.149',                                               description: 'IP of Final Deployment Server')
        string(name: 'ecr_repo_url',    defaultValue: '248877153012.dkr.ecr.eu-north-1.amazonaws.com/cicd-project', description: 'Full ECR URI')
        string(name: 'aws_region',      defaultValue: 'eu-north-1',                                                  description: 'AWS Region')
    }

    environment {
        SONARQUBE_URL   = "http://${params.sonar_IP}:9000"
        SONARQUBE_TOKEN = credentials('sonar-token')
        IMAGE_TAG       = ''
    }

    stages {

        stage('1. Checkout Code') {
            steps {
                git branch: "${params.BRANCH}",
                    credentialsId: 'jenkins-ssh-key',
                    url: 'git@github.com:Namitha2000/CICD-Project.git'

                script {
                    def commitShort = sh(script: "git rev-parse --short HEAD", returnStdout: true).trim()

                    def branch = params.BRANCH?.trim() ? params.BRANCH : 'master'
                    def ecrUrl = params.ecr_repo_url?.trim() ? params.ecr_repo_url : '248877153012.dkr.ecr.eu-north-1.amazonaws.com/cicd-project'

                    def ecrRegistry = ecrUrl.split('/')[0]

                    echo "DEBUG ecr_repo_url = '${params.ecr_repo_url}'"
                    echo "DEBUG branch = '${branch}'"
                    echo "DEBUG commit = '${commitShort}'"
                    echo "DEBUG build = '${BUILD_NUMBER}'"

                    env.IMAGE_TAG = "${ecrUrl}:${branch}-${commitShort}-${BUILD_NUMBER}"
                    env.ECR_REGISTRY = ecrRegistry

                    echo "✅ Image tag will be: ${env.IMAGE_TAG}"
                    echo "✅ ECR Registry: ${env.ECR_REGISTRY}"
                }
            }
        }

        stage('2. Sonarqube Analysis') {
            steps {
                dir('webapp') {
                    sh """
                    mvn sonar:sonar \
                    -Dsonar.projectKey=CICDProject \
                    -Dsonar.host.url=$SONARQUBE_URL \
                    -Dsonar.token=$SONARQUBE_TOKEN
                    """
                }
            }
        }

        stage('3. Docker Build & Push to ECR') {
            steps {
                sshagent(['docker-server']) {
                    sh """
                    set -e

                    # Prepare remote server
                    ssh -o StrictHostKeyChecking=no ubuntu@${params.docker_build_IP} 'mkdir -p ~/build_temp'

                    # Copy project
                    scp -o StrictHostKeyChecking=no -r ./* ubuntu@${params.docker_build_IP}:~/build_temp/

                    # Execute remotely
                    ssh -o StrictHostKeyChecking=no ubuntu@${params.docker_build_IP} << EOF
                        set -e
                        cd ~/build_temp

                        echo "Logging into ECR..."
                        aws ecr get-login-password --region ${params.aws_region} | \
                        docker login --username AWS --password-stdin ${env.ECR_REGISTRY}

                        echo "Building Docker image..."
                        docker build -t ${env.IMAGE_TAG} .

                        echo "Pushing Docker image..."
                        docker push ${env.IMAGE_TAG}

                        echo "Cleaning up..."
                        docker rmi ${env.IMAGE_TAG}
                        cd ~ && rm -rf ~/build_temp
EOF
                    """
                }
            }
        }

        stage('4. Deploy to Production EC2') {
            steps {
                sshagent(['docker-server']) {
                    sh """
                    set -e

                    ssh -o StrictHostKeyChecking=no ubuntu@${params.deploy_IP} << EOF
                        set -e

                        echo "Logging into ECR..."
                        aws ecr get-login-password --region ${params.aws_region} | \
                        docker login --username AWS --password-stdin ${env.ECR_REGISTRY}

                        echo "Stopping old container..."
                        docker stop webapp-container || true
                        docker rm webapp-container || true

                        echo "Pulling latest image..."
                        docker pull ${env.IMAGE_TAG}

                        echo "Running new container..."
                        docker run -d --name webapp-container -p 8080:8080 ${env.IMAGE_TAG}

                        echo "Cleaning unused images..."
                        docker image prune -af
EOF
                    """
                }
            }
        }
    }

    post {
        always {
            cleanWs()
        }
    }
}
