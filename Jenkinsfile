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
            description: 'Select branch'
        )
        string(
            name: 'sonar_IP',
            defaultValue: '13.48.131.179'
        )
        string(
            name: 'aws_region',
            defaultValue: 'eu-north-1'
        )
    }

    environment {
        SONARQUBE_URL   = "http://${params.sonar_IP}:30090"
        SONARQUBE_TOKEN = credentials('SonarToken')
        ECR_REGISTRY    = "513616569996.dkr.ecr.eu-north-1.amazonaws.com"
        ECR_REPO        = "cicd-repo"
        GITOPS_REPO     = "github.com/Namitha2000/CICD-Project.git"
    }

    stages {

        stage('1. Checkout Code') {
            steps {
                git branch: "${params.BRANCH}",
                    credentialsId: 'jenkins-git-ssh-key',
                    url: 'git@github.com:Namitha2000/CICD-Project.git'

                script {
                    def commitShort = sh(
                        script: "git rev-parse --short HEAD",
                        returnStdout: true
                    ).trim()

                    env.IMAGE_TAG = "${ECR_REGISTRY}/${ECR_REPO}:${params.BRANCH}-${commitShort}-${BUILD_NUMBER}"

                    echo "Docker Image = ${env.IMAGE_TAG}"
                }
            }
        }

        stage('2. SonarQube Analysis') {
            steps {
                withSonarQubeEnv('sonar-server') {
                    dir('webapp') {
                        sh """
                            mvn sonar:sonar \
                            -Dsonar.projectKey=CICDProject \
                            -Dsonar.host.url=${SONARQUBE_URL} \
                            -Dsonar.token=${SONARQUBE_TOKEN}
                        """
                    }
                }
            }
        }

        stage('3. Quality Gate') {
            steps {
                timeout(time: 5, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        stage('4. Docker Build') {
            steps {
                sh """
                    docker build -t ${env.IMAGE_TAG} .
                """
            }
        }

        stage('5. Push to AWS ECR') {
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-ecr-credentials'
                ]]) {
                    sh """
                        aws ecr get-login-password --region ${params.aws_region} | \
                        docker login --username AWS \
                        --password-stdin ${ECR_REGISTRY}

                        docker push ${env.IMAGE_TAG}

                        docker tag ${env.IMAGE_TAG} ${ECR_REGISTRY}/${ECR_REPO}:latest

                        docker push ${ECR_REGISTRY}/${ECR_REPO}:latest
                    """
                }
            }
        }

        stage('6. Update Kubernetes Manifest') {
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'github-gitops-credentials',
                        usernameVariable: 'GIT_USER',
                        passwordVariable: 'GIT_TOKEN'
                    )
                ]) {
                    sh """
                        git clone https://${GIT_USER}:${GIT_TOKEN}@${GITOPS_REPO} gitops

                        cd gitops

                        sed -i 's|image:.*|image: ${env.IMAGE_TAG}|g' deployment/deployment.yaml

                        git config user.email "jenkins@cicd.com"
                        git config user.name "Jenkins"
                        git add deployment/deployment.yaml
                        git commit -m "Updated image to ${env.IMAGE_TAG}"
                        git push origin HEAD:${params.BRANCH}
                    """
                }
            }
        }
    }

    post {
        always {
            cleanWs()
        }
        success {
            echo 'Pipeline SUCCESS! ArgoCD will deploy to Kubernetes.'
        }
        failure {
            echo 'Pipeline FAILED! Check logs above.'
        }
    }
}
