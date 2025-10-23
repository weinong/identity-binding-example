#!/bin/bash

# Java Demo App Deployment Configuration Script
# This script helps configure the Java demo app deployment with the correct values

set -e

echo "Java Demo App Deployment Configuration"
echo "======================================"

# Check if resource group is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <resource-group-name> [container-registry]"
    echo "Example: $0 ib-demo-rg myregistry.azurecr.io"
    echo ""
    echo "If container-registry is not provided, you'll need to build and push the image manually."
    exit 1
fi

RESOURCE_GROUP="$1"
CONTAINER_REGISTRY="${2:-}"

echo "Resource Group: $RESOURCE_GROUP"
if [ -n "$CONTAINER_REGISTRY" ]; then
    echo "Container Registry: $CONTAINER_REGISTRY"
fi
echo ""
echo "Retrieving Azure resources..."

# Check if resource group exists
if ! az group show --name "$RESOURCE_GROUP" &>/dev/null; then
    echo "Error: Resource group '$RESOURCE_GROUP' not found"
    exit 1
fi

# Get managed identity
echo "- Finding managed identity..."
MANAGED_IDENTITIES=$(az identity list --resource-group "$RESOURCE_GROUP" --query "[].{name:name,clientId:clientId,resourceId:id}" -o json)

if [ "$(echo "$MANAGED_IDENTITIES" | jq length)" -lt 1 ]; then
    echo "Error: No managed identities found in resource group '$RESOURCE_GROUP'"
    exit 1
fi

# Get the first managed identity (sorted by name)
MANAGED_IDENTITY_CLIENT_ID=$(echo "$MANAGED_IDENTITIES" | jq -r 'sort_by(.name)[0].clientId')
MANAGED_IDENTITY_NAME=$(echo "$MANAGED_IDENTITIES" | jq -r 'sort_by(.name)[0].name')
MANAGED_IDENTITY_RESOURCE_ID=$(echo "$MANAGED_IDENTITIES" | jq -r 'sort_by(.name)[0].resourceId')

# Get Key Vault
echo "- Finding Key Vault..."
KEYVAULT_NAME=$(az keyvault list --resource-group "$RESOURCE_GROUP" --query "[0].name" -o tsv)

if [ -z "$KEYVAULT_NAME" ]; then
    echo "Error: No Key Vault found in resource group '$RESOURCE_GROUP'"
    exit 1
fi

KEYVAULT_URL=$(az keyvault show --name "$KEYVAULT_NAME" --resource-group "$RESOURCE_GROUP" --query "properties.vaultUri" -o tsv)

# Get AKS cluster and OIDC issuer URL
echo "- Finding AKS cluster..."
AKS_CLUSTER_NAME=$(az aks list --resource-group "$RESOURCE_GROUP" --query "[0].name" -o tsv)

if [ -z "$AKS_CLUSTER_NAME" ]; then
    echo "Error: No AKS cluster found in resource group '$RESOURCE_GROUP'"
    exit 1
fi

AKS_OIDC_ISSUER_URL=$(az aks show --name "$AKS_CLUSTER_NAME" --resource-group "$RESOURCE_GROUP" --query "oidcIssuerProfile.issuerUrl" -o tsv)

if [ -z "$AKS_OIDC_ISSUER_URL" ]; then
    echo "Error: AKS cluster '$AKS_CLUSTER_NAME' does not have OIDC issuer enabled"
    exit 1
fi

echo ""
echo "Configuration values:"
echo "- Managed Identity Name: $MANAGED_IDENTITY_NAME"
echo "- Managed Identity Client ID: $MANAGED_IDENTITY_CLIENT_ID"
echo "- AKS OIDC Issuer URL: $AKS_OIDC_ISSUER_URL"
echo "- Key Vault URL: $KEYVAULT_URL"
echo ""

# Set default container registry if not provided
if [ -z "$CONTAINER_REGISTRY" ]; then
    CONTAINER_REGISTRY="YOUR_REGISTRY.azurecr.io"
    echo "⚠️  Warning: No container registry provided. Using placeholder: $CONTAINER_REGISTRY"
    echo "   You'll need to build and push the image manually before deploying."
    echo ""
fi

# Create federated identity credential for workload identity
echo "Creating federated identity credential..."
FEDERATED_IDENTITY_NAME="demo-app-java-federated-identity"

# Delete existing federated identity if it exists
if az identity federated-credential show \
    --name "$FEDERATED_IDENTITY_NAME" \
    --identity-name "$MANAGED_IDENTITY_NAME" \
    --resource-group "$RESOURCE_GROUP" &>/dev/null; then
    echo "- Deleting existing federated identity credential..."
    az identity federated-credential delete \
        --name "$FEDERATED_IDENTITY_NAME" \
        --identity-name "$MANAGED_IDENTITY_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --yes
fi

# Create new federated identity credential
echo "- Creating federated identity credential for workload identity..."
az identity federated-credential create \
    --name "$FEDERATED_IDENTITY_NAME" \
    --identity-name "$MANAGED_IDENTITY_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --issuer "$AKS_OIDC_ISSUER_URL" \
    --subject "system:serviceaccount:demo-app-java:demo-app-java-sa" \
    --audience "api://AzureADTokenExchange"

echo "✅ Federated identity credential created successfully"
echo ""

# Create configured deployment file
echo "Generating configured deployment file..."

sed -e "s|\${MANAGED_IDENTITY_CLIENT_ID}|$MANAGED_IDENTITY_CLIENT_ID|g" \
    -e "s|\${KEYVAULT_URL}|$KEYVAULT_URL|g" \
    -e "s|\${CONTAINER_REGISTRY}|$CONTAINER_REGISTRY|g" \
    deployment.yaml > deployment-configured.yaml

echo "✅ Configured deployment file created: deployment-configured.yaml"
echo ""

# Get kubeconfig to local file
KUBECONFIG_FILE="./kubeconfig-${RESOURCE_GROUP}-${AKS_CLUSTER_NAME}"
echo "Getting AKS cluster credentials..."
az aks get-credentials --resource-group "$RESOURCE_GROUP" --name "$AKS_CLUSTER_NAME" --file "$KUBECONFIG_FILE" --overwrite-existing

echo "✅ Kubeconfig saved to: $KUBECONFIG_FILE"
echo ""

# # Build and push Docker image if registry is provided and not a placeholder
# if [ -n "$CONTAINER_REGISTRY" ] && [ "$CONTAINER_REGISTRY" != "YOUR_REGISTRY.azurecr.io" ]; then
#     echo "Building and pushing Docker image..."
#     echo "- Building image..."
#     docker build -t "$CONTAINER_REGISTRY/demo-app-java:latest" .
    
#     echo "- Pushing image to registry..."
#     docker push "$CONTAINER_REGISTRY/demo-app-java:latest"
    
#     echo "✅ Docker image built and pushed successfully"
#     echo ""
# else
#     echo "⚠️  Skipping Docker build and push (no valid registry provided)"
#     echo ""
#     echo "To build and push manually:"
#     echo "  docker build -t <your-registry>/demo-app-java:latest ."
#     echo "  docker push <your-registry>/demo-app-java:latest"
#     echo ""
#     echo "Then update deployment-configured.yaml with the correct image reference."
#     echo ""
#fi

# Deploy the application
echo "Deploying Java demo application..."
export KUBECONFIG="$KUBECONFIG_FILE"

kubectl apply -f deployment-configured.yaml

echo ""
echo "✅ Java demo app deployed successfully!"
echo ""
echo "📋 Configuration Summary:"
echo "- Using Azure Workload Identity with DefaultAzureCredential"
echo "- Service Account: demo-app-java-sa"
echo "- Namespace: demo-app-java"
echo "- Managed Identity: $MANAGED_IDENTITY_NAME"
echo "- Federated Identity Credential: $FEDERATED_IDENTITY_NAME"
echo ""
echo "To monitor the deployment:"
echo "1. Check pod status: KUBECONFIG=$KUBECONFIG_FILE kubectl get pods -n demo-app-java"
echo "2. View logs: KUBECONFIG=$KUBECONFIG_FILE kubectl logs -f -l app=demo-app-java -n demo-app-java"
echo "3. Describe pod: KUBECONFIG=$KUBECONFIG_FILE kubectl describe pod -l app=demo-app-java -n demo-app-java"
echo "4. Check service account: KUBECONFIG=$KUBECONFIG_FILE kubectl get sa demo-app-java-sa -n demo-app-java -o yaml"
echo ""
echo "Note: The app uses Azure DefaultAzureCredential which automatically detects"
echo "and uses Workload Identity when running in an AKS cluster with the appropriate"
echo "annotations and federated identity credentials configured."
