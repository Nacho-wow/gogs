pipeline {
    agent any

    triggers {
        githubPush()
    }

    environment {
        DB_NAME                 = 'gogs'
        DB_USER                 = credentials('DB_USER')
        DB_PASSWORD             = credentials('DB_PASSWORD')

        EC2_AMI                 = 'ami-04f167a56786e4b09'
        EC2_KEY_NAME            = 'flask_key'
        CONTROL_IP              = credentials('CONTROL_IP')

        AWS_ACCESS_KEY_ID       = credentials('AWS_ACCESS_KEY_ID')
        AWS_SECRET_ACCESS_KEY   = credentials('AWS_SECRET_ACCESS_KEY')

        // EMAIL_RECIPIENTS = credentials('EMAIL_RECIPIENTS')
    }

    stages {
        stage('Get Agent IP Address') {
            steps {
                script {
                    def agent_ip = sh(script: "curl -s https://checkip.amazonaws.com", returnStdout: true).trim()
                    env.AGENT_IP = agent_ip
                    echo "IP publica del agente: ${env.AGENT_IP}"
                }
            }
        }

        stage('Clone Repo') {
            steps {
                checkout scm
            }
        }

        stage('Build Docker Image') {
            steps {
                sh 'make docker-build'
            }
        }

        stage('Generate Terraform Variables') {
            when {
                branch 'main'
            }
            steps {
                sh '''
                    make generate-tfvars \
                        EC2_AMI=$EC2_AMI \
                        EC2_KEY_NAME=$EC2_KEY_NAME \
                        DB_USER=$DB_USER \
                        DB_PASSWORD=$DB_PASSWORD \
                        DB_NAME=$DB_NAME \
                        CONTROL_IP=$CONTROL_IP \
                        AGENT_IP=$AGENT_IP
                '''
            }
        }

        stage('Create Infrastructure') {
            when {
                branch 'main'
            }
            steps {
                sh 'make infra-aws'
            }
        }

        stage("Generate App Config File") {
            when {
                branch 'main'
            }
            steps {
                sh '''
                    make generate-app-config \
                        DB_USER=$DB_USER \
                        DB_PASSWORD=$DB_PASSWORD
                '''
            }
        }

        stage("Save Docker Image") {
            when {
                branch 'main'
            }
            steps {
                sh 'make save-docker-image'
            }
        }

        stage('Configure EC2 with Ansible') {
            when {
                branch 'main'
            }
            steps {
                withCredentials([sshUserPrivateKey(credentialsId: 'ec2_ssh_key', keyFileVariable: 'KEY')]) {
                    sh 'make configure KEY=$KEY'
                }
            }
        }
    }

    post {
        always {
            echo 'Limpiando espacio'
            sh 'make clean'
        }
        failure {
            echo 'Todo mal unu'
            // emailext(
            //     to: "${env.EMAIL_RECIPIENTS}",
            //     subject: "❌ Build Fallida - ${env.JOB_NAME} #${env.BUILD_NUMBER}",
            //     body: """<p>🔴 La build falló :C</p>
            //             <p>Job: <b>${env.JOB_NAME}</b><br>
            //             Build: <b>#${env.BUILD_NUMBER}</b></p>
            //             <p><a href='${env.BUILD_URL}'>Ver Detalles</a></p>""",
            //     mimeType: 'text/html'
            // )
        }
        success {
            echo 'De pana'
            // emailext(
            //     to: "${env.EMAIL_RECIPIENTS}",
            //     subject: "✅ Build Exitosa - ${env.JOB_NAME} #${env.BUILD_NUMBER}",
            //     body: """<h3>🟢 La build fue exitosa :D</h3>
            //             <p>Job: <b>${env.JOB_NAME}</b><br>
            //             Build: <b>#${env.BUILD_NUMBER}</b></p>
            //             <p><a href='${env.BUILD_URL}'>Ver detalles</a></p>""",
            //     mimeType: 'text/html'
            // )
        }
    }
}
