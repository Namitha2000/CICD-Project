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
        string(name: 'sonar_IP',        defaultValue: '13.63.34.172')
        string(name: 'docker_build_IP', defaultValue: '16.170.246.244')
        string(name: 'deploy_IP',       defaultValue: '13.50.101.149')
        string(name: 'ecr_repo_url',    defaultValue: '248877153012.dkr.ecr.eu-north-1.amazonaws.com/cicd-project')
        string(name: 'aws_region',      defaultValue: 'eu-north-1')
    }

    environment {
        SONARQUBE_URL   = "http://${params.sonar_IP}:9000"
        SONARQUBE_TOKEN = credentials('sonar-token')
    }

    stages {

        stage('1. Checkout Code') {
            steps {
                git branch: "${params.BRANCH}",
                    credentialsId: 'jenkins-ssh-key',
                    url: 'git@github.com:Namitha2000/CICD-Project.git'

                script {
                    def commitShort = sh(script: "git rev-parse --short HEAD", returnStdout: true).trim()
                    def ecrUrl = params.ecr_repo_url
                    def branch = params.BRANCH

                    IMAGE_TAG = "${ecrUrl}:${branch}-${commitShort}-${BUILD_NUMBER}"

                    // Export to env explicitly
                    env.IMAGE_TAG = IMAGE_TAG

                    echo "IMAGE_TAG = ${env.IMAGE_TAG}"
                }
            }
        }

        stage('2. Sonarqube Analysis') {
            steps {
                dir('webapp') {
                    sh '''
                    mvn sonar:sonar \
                    -Dsonar.projectKey=CICDProject \
                    -Dsonar.host.url=$SONARQUBE_URL \
                    -Dsonar.token=$SONARQUBE_TOKEN
                    '''
                }
            }
        }

        stage('3. Docker Build & Push to ECR') {
            steps {
                sshagent(['docker-server']) {
                    sh '''
                    set -e

                    echo "Using IMAGE_TAG=$IMAGE_TAG"

                    ssh -o StrictHostKeyChecking=no ubuntu@''' + params.docker_build_IP + ''' 'mkdir -p ~/build_temp'
                    
                    scp -o StrictHostKeyChecking=no -r ./* ubuntu@''' + params.docker_build_IP + ''':~/build_temp/

                    ssh -o StrictHostKeyChecking=no ubuntu@''' + params.docker_build_IP + ''' << EOF
                        set -e
                        cd ~/build_temp

                        echo "Logging into ECR..."
                        aws ecr get-login-password --region ''' + params.aws_region + ''' | \\
                        docker login --username AWS --password-stdin ''' + params.ecr_repo_url + '''

                        echo "Building Docker image..."
                        docker build -t ''' + '${IMAGE_TAG}' + ''' .

                        echo "Pushing Docker image..."
                        docker push ''' + '${IMAGE_TAG}' + '''

                        docker rmi ''' + '${IMAGE_TAG}' + '''
                        rm -rf ~/build_temp
EOF
                    '''
                }
            }
        }

        stage('4. Deploy to Production EC2') {
            steps {
                sshagent(['docker-server']) {
                    sh '''
                    ssh -o StrictHostKeyChecking=no ubuntu@''' + params.deploy_IP + ''' << EOF
                        set -e

                        aws ecr get-login-password --region ''' + params.aws_region + ''' | \\
                        docker login --username AWS --password-stdin ''' + params.ecr_repo_url + '''

                        docker stop webapp-container || true
                        docker rm webapp-container || true

                        docker pull ''' + '${IMAGE_TAG}' + '''

                        docker run -d --name webapp-container -p 8080:8080 ''' + '${IMAGE_TAG}' + '''

                        docker image prune -af
EOF
                    '''
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

