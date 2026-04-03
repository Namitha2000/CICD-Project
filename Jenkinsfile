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
        string(name: 'sonar_IP', defaultValue: '13.63.34.172', description: 'SonarQube Server IP')
        string(name: 'docker_build_IP', defaultValue: '<YOUR_BUILD_SERVER_IP>', description: 'IP of server for Docker Build')
        string(name: 'deploy_IP', defaultValue: '13.50.101.149', description: 'IP of Final Deployment Server')
        string(name: 'ecr_repo_url', defaultValue: '<AWS_ACCOUNT_ID>.dkr.ecr.eu-north-1.amazonaws.com/webapp-repo', description: 'Full ECR URI')
        string(name: 'aws_region', defaultValue: 'eu-north-1', description: 'AWS Region (Stockholm)')
    
    }

    environment {
        SONARQUBE_URL = "http://${params.sonar_IP}:9000"
        SONARQUBE_TOKEN = credentials('sonar-token')
        IMAGE_TAG = '' 
    }

    stages {
        stage('1. Checkout Code') {
            steps {
                git branch: "${params.BRANCH}",
                    credentialsId: 'jenkins-ssh-key', 
                    url: 'git@github.com:Namitha2000/CICD-Project.git'
             
                script {
    def commitShort = sh(script: "git rev-parse --short HEAD", returnStdout: true).trim()
    def ecrUrl = params.ecr_repo_url ?: '248877153012.dkr.ecr.eu-north-1.amazonaws.com/cicd-project'
    def branch = params.BRANCH ?: 'master'
    env.IMAGE_TAG = "${ecrUrl}:${branch}-${commitShort}-${BUILD_NUMBER}"
    echo "Image tag will be: ${env.IMAGE_TAG}"
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
                    -Dsonar.login=$SONARQUBE_TOKEN
                    """
                }
            }
        }

        stage('Docker Build & Push to ECR') {
            steps {
                sshagent(['docker-server']) { 
                    sh """
                    # Prepare build server workspace
                    ssh -o StrictHostKeyChecking=no ubuntu@${params.docker_build_IP} 'mkdir -p ~/build_temp'
                    scp -o StrictHostKeyChecking=no -r ./* ubuntu@${params.docker_build_IP}:~/build_temp/

                    # Remote Execution: Build and Push
                    ssh -o StrictHostKeyChecking=no ubuntu@${params.docker_build_IP} << 'EOF'
                        cd ~/build_temp
                        
                        # Login to ECR in Stockholm
                        aws ecr get-login-password --region ${params.aws_region} | \\
                        docker login --username AWS --password-stdin ${params.ecr_repo_url}

                        # Build the image
                        docker build -t ${env.IMAGE_TAG} .

                        # Push to Registry
                        docker push ${env.IMAGE_TAG}

                        # Cleanup to save disk space
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
                    ssh -o StrictHostKeyChecking=no ubuntu@${params.deploy_IP} << 'EOF'
                        # Login to ECR
                        aws ecr get-login-password --region ${params.aws_region} | \\
                        docker login --username AWS --password-stdin ${params.ecr_repo_url}

                        # Stop/Remove old container
                        docker stop webapp-container || true
                        docker rm webapp-container || true

                        # Pull and Run new version
                        docker pull ${env.IMAGE_TAG}
                        docker run -d --name webapp-container -p 8080:8080 ${env.IMAGE_TAG}

                        # Remove old unused images (Prevents 100% disk usage)
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
