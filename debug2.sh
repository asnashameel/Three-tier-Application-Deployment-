#!/bin/bash



# EKS Kubectl Configuration Script for EC2 Instances

# This script installs AWS CLI if needed and configures kubectl for EKS



set -e



echo "🔧 EKS Kubectl Configuration Script for EC2"

echo "============================================="



# Variables - Update these with your specific values

CLUSTER_NAME="my-eks-cluster"

REGION="us-east-1" # Change to your AWS region



echo "📋 Cluster Name: $CLUSTER_NAME"

echo "📋 Region: $REGION"

echo ""



# Detect OS type

if [ -f /etc/os-release ]; then

  . /etc/os-release

  OS=$NAME

  VERSION=$VERSION_ID

fi



echo "🖥️ Detected OS: $OS"

echo ""



# Step 1: Install AWS CLI if not present

echo "1️⃣ Checking and installing AWS CLI..."

if ! command -v aws &> /dev/null; then

  echo "❌ AWS CLI is not installed. Installing AWS CLI v2..."



  if [[ "$OS" == *"Amazon Linux"* ]]; then

    # Amazon Linux

    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"

    unzip awscliv2.zip

    sudo ./aws/install

    rm -rf awscliv2.zip aws/

  elif [[ "$OS" == *"Ubuntu"* ]] || [[ "$OS" == *"Debian"* ]]; then

    # Ubuntu/Debian

    sudo apt update

    sudo apt install awscli unzip curl -y

  elif [[ "$OS" == *"CentOS"* ]] || [[ "$OS" == *"Red Hat"* ]]; then

    # CentOS/RHEL

    sudo yum install awscli unzip curl -y

  else

    echo "⚠️ Unknown OS. Trying generic installation..."

    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"

    unzip awscliv2.zip

    sudo ./aws/install

    rm -rf awscliv2.zip aws/

  fi



  # Refresh PATH

  export PATH=$PATH:/usr/local/bin

  echo "✅ AWS CLI installed"

else

  echo "✅ AWS CLI is already installed"

fi



# Display AWS CLI version

aws --version

echo ""



# Step 2: Check AWS configuration

echo "2️⃣ Checking AWS configuration..."

if aws sts get-caller-identity &> /dev/null; then

  echo "✅ AWS credentials are configured"

  aws sts get-caller-identity

else

  echo "❌ AWS credentials not configured"

  echo "Options:"

  echo " 1. If this EC2 has an IAM role with EKS permissions, the script should work"

  echo " 2. If not, you need to configure credentials:"

  echo " aws configure"

  echo ""

  read -p "Do you want to configure AWS credentials now? (y/n): " -n 1 -r

  echo

  if [[ $REPLY =~ ^[Yy]$ ]]; then

    aws configure

  else

    echo "Please ensure your EC2 instance has proper IAM role or configure credentials manually"

    exit 1

  fi

fi

echo ""



# Step 3: Install kubectl if not present

echo "3️⃣ Checking and installing kubectl..."

if ! command -v kubectl &> /dev/null; then

  echo "❌ kubectl is not installed. Installing kubectl..."

  curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

  chmod +x kubectl

  sudo mv kubectl /usr/local/bin/

  echo "✅ kubectl installed"

else

  echo "✅ kubectl is already installed"

fi



kubectl version --client

echo ""



# Step 4: Check if cluster exists

echo "4️⃣ Checking if EKS cluster exists..."

if aws eks describe-cluster --name $CLUSTER_NAME --region $REGION &> /dev/null; then

  echo "✅ EKS cluster '$CLUSTER_NAME' exists in region '$REGION'"



  # Get cluster status

  CLUSTER_STATUS=$(aws eks describe-cluster --name $CLUSTER_NAME --region $REGION --query 'cluster.status' --output text)

  echo " Cluster Status: $CLUSTER_STATUS"



  if [ "$CLUSTER_STATUS" != "ACTIVE" ]; then

    echo "⚠️ Cluster is not in ACTIVE state. Current state: $CLUSTER_STATUS"

    echo " Please wait for the cluster to become ACTIVE before proceeding."

    exit 1

  fi

else

  echo "❌ EKS cluster '$CLUSTER_NAME' not found in region '$REGION'"

  echo " Please check your cluster name and region."

  echo " Available clusters in region $REGION:"

  aws eks list-clusters --region $REGION --query 'clusters' --output table 2>/dev/null || echo " Cannot list clusters - check permissions"

  exit 1

fi

echo ""



# Step 5: Update kubeconfig

echo "5️⃣ Updating kubeconfig for EKS cluster..."

aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME



# Check if kubeconfig was updated successfully

if [ $? -eq 0 ]; then

  echo "✅ Kubeconfig updated successfully"

else

  echo "❌ Failed to update kubeconfig"

  exit 1

fi

echo ""



# Step 6: Check current context

echo "6️⃣ Checking kubectl context..."

echo "Current context:"

kubectl config current-context

echo ""



# Step 7: Test cluster connectivity

echo "7️⃣ Testing cluster connectivity..."

echo "Attempting to connect to the cluster..."



if kubectl cluster-info &> /dev/null; then

  echo "✅ Successfully connected to the cluster"

  kubectl cluster-info

else

  echo "❌ Failed to connect to the cluster"

  echo "This could be due to:"

  echo " - Network connectivity issues"

  echo " - IAM permissions issues"

  echo " - Security group restrictions"

  echo " - EC2 instance cannot reach EKS endpoint"

fi

echo ""



# Step 8: Check nodes

echo "8️⃣ Checking cluster nodes..."

echo "Attempting to get nodes..."



if kubectl get nodes &> /dev/null; then

  echo "✅ Successfully retrieved nodes:"

  kubectl get nodes -o wide

else

  echo "❌ Failed to get nodes. This could be due to:"

  echo " - Node group not ready yet"

  echo " - IAM roles not properly configured"

  echo " - Network connectivity issues"

  echo ""

  echo "Let's check the node group status..."



  # Check node group status

  NODE_GROUPS=$(aws eks list-nodegroups --cluster-name $CLUSTER_NAME --region $REGION --query 'nodegroups' --output text 2>/dev/null)



  if [ -n "$NODE_GROUPS" ]; then

    for NODE_GROUP in $NODE_GROUPS; do

      echo " Checking node group: $NODE_GROUP"

      NODE_GROUP_STATUS=$(aws eks describe-nodegroup --cluster-name $CLUSTER_NAME --nodegroup-name $NODE_GROUP --region $REGION --query 'nodegroup.status' --output text 2>/dev/null)

      echo " Status: $NODE_GROUP_STATUS"



      if [ "$NODE_GROUP_STATUS" != "ACTIVE" ]; then

        echo " ⚠️ Node group is not ACTIVE. Current status: $NODE_GROUP_STATUS"

      fi

    done

  else

    echo " ❌ No node groups found or cannot access node groups"

  fi

fi

echo ""



# Step 9: Additional EC2-specific troubleshooting

echo "9️⃣ EC2-specific troubleshooting information..."

echo "If you're still having issues from EC2, check the following:"

echo ""

echo "🔍 EC2 IAM Role:"

echo " - Ensure your EC2 instance has an IAM role attached"

echo " - The role should have EKS permissions (eks:DescribeCluster, etc.)"

echo " - Check: curl http://169.254.169.254/latest/meta-data/iam/security-credentials/"

echo ""

echo "🔍 Security Groups:"

echo " - EC2 security group should allow outbound HTTPS (port 443)"

echo " - Check connectivity: curl -I https://eks.$REGION.amazonaws.com"

echo ""

echo "🔍 Network connectivity:"

echo " - Ensure EC2 can reach the internet (for public endpoints)"

echo " - Check route tables and NACLs"

echo ""



echo "✅ Script completed!"

echo ""

echo "🚀 Quick test - Try running these commands:"

echo " kubectl get nodes"

echo " kubectl get pods --all-namespaces"

