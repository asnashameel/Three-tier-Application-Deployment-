#!/bin/bash



# EKS Cluster Kubectl Configuration and Troubleshooting Script

# This script helps fix the common kubectl connection issues with EKS



set -e



echo "🔧 EKS Kubectl Configuration and Troubleshooting Script"

echo "======================================================="



# Variables - Update these with your specific values

CLUSTER_NAME="my-eks-cluster"

REGION="us-east-1" # Change to your AWS region



echo "📋 Cluster Name: $CLUSTER_NAME"

echo "📋 Region: $REGION"

echo ""



# Step 1: Check AWS CLI configuration

echo "1️⃣ Checking AWS CLI configuration..."

if ! command -v aws &> /dev/null; then

  echo "❌ AWS CLI is not installed. Please install it first."

  exit 1

fi



echo "✅ AWS CLI is installed"

echo "Current AWS configuration:"

aws sts get-caller-identity || {

  echo "❌ AWS credentials not configured. Please run 'aws configure'"

  exit 1

}

echo ""



# Step 2: Check kubectl installation

echo "2️⃣ Checking kubectl installation..."

if ! command -v kubectl &> /dev/null; then

  echo "❌ kubectl is not installed. Installing kubectl..."

  curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/darwin/amd64/kubectl"

  chmod +x kubectl

  sudo mv kubectl /usr/local/bin/

  echo "✅ kubectl installed"

else

  echo "✅ kubectl is already installed"

  kubectl version --client

fi

echo ""



# Step 3: Check if cluster exists

echo "3️⃣ Checking if EKS cluster exists..."

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

  exit 1

fi

echo ""



# Step 4: Update kubeconfig

echo "4️⃣ Updating kubeconfig for EKS cluster..."

aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME



# Check if kubeconfig was updated successfully

if [ $? -eq 0 ]; then

  echo "✅ Kubeconfig updated successfully"

else

  echo "❌ Failed to update kubeconfig"

  exit 1

fi

echo ""



# Step 5: Check current context

echo "5️⃣ Checking kubectl context..."

echo "Current context:"

kubectl config current-context

echo ""



# Step 6: Test cluster connectivity

echo "6️⃣ Testing cluster connectivity..."

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

fi

echo ""



# Step 7: Check nodes

echo "7️⃣ Checking cluster nodes..."

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

  NODE_GROUPS=$(aws eks list-nodegroups --cluster-name $CLUSTER_NAME --region $REGION --query 'nodegroups' --output text)



  if [ -n "$NODE_GROUPS" ]; then

    for NODE_GROUP in $NODE_GROUPS; do

      echo " Checking node group: $NODE_GROUP"

      NODE_GROUP_STATUS=$(aws eks describe-nodegroup --cluster-name $CLUSTER_NAME --nodegroup-name $NODE_GROUP --region $REGION --query 'nodegroup.status' --output text)

      echo " Status: $NODE_GROUP_STATUS"



      if [ "$NODE_GROUP_STATUS" != "ACTIVE" ]; then

        echo " ⚠️ Node group is not ACTIVE. Current status: $NODE_GROUP_STATUS"

      fi

    done

  else

    echo " ❌ No node groups found"

  fi

fi

echo ""



# Step 8: Additional troubleshooting information

echo "8️⃣ Additional troubleshooting information..."

echo "If you're still having issues, try the following:"

echo ""

echo "🔍 Check IAM permissions:"

echo " - Ensure your AWS user/role has the necessary EKS permissions"

echo " - Check if you have 'eks:DescribeCluster' permission"

echo " - Verify that the EKS cluster role has the correct policies attached"

echo ""

echo "🔍 Check security groups:"

echo " - Ensure the cluster security group allows necessary traffic"

echo " - Check if your IP is allowed to access the cluster endpoint"

echo ""

echo "🔍 Check network connectivity:"

echo " - Verify that the cluster endpoint is publicly accessible"

echo " - Check if there are any network ACLs blocking traffic"

echo ""

echo "🔍 Useful commands for debugging:"

echo " aws eks describe-cluster --name $CLUSTER_NAME --region $REGION"

echo " kubectl config view"

echo " kubectl get pods --all-namespaces"

echo " kubectl logs -n kube-system <pod-name>"

echo ""



echo "✅ Script completed. If nodes are still not showing, please check the troubleshooting steps above."



