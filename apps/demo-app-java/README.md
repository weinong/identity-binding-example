# Azure Key Vault Demo App (Java)

This is a Java application that demonstrates accessing Azure Key Vault secrets using Azure Default Credential with Managed Identity.

## Features

- Uses Azure Default Credential for authentication (supports Managed Identity)
- Retrieves secrets from Azure Key Vault in a continuous loop
- Supports multiple authentication methods: pod-identity, workload-identity, and identity-binding
- Multi-stage Docker build for optimized image size

## Prerequisites

- Java 17 or later
- Maven 3.6 or later
- Docker (for containerized deployment)
- Azure Key Vault with appropriate access policies
- Managed Identity configured in Azure

## Building the Application

### Local Build

```bash
mvn clean package
```

### Docker Build

```bash
docker build -t demo-app-java:latest .
```

## Running the Application

### Locally

```bash
export AUTH_METHOD=workload-identity
export KEYVAULT_URL=https://your-keyvault.vault.azure.net/
export SECRET_NAME=demo-secret
export MANAGED_IDENTITY_CLIENT_ID=your-client-id
export REBUILD_CREDENTIALS=false

java -jar target/demo-app-java-1.0.0.jar
```

### Docker

```bash
docker run -e AUTH_METHOD=workload-identity \
           -e KEYVAULT_URL=https://your-keyvault.vault.azure.net/ \
           -e SECRET_NAME=demo-secret \
           -e MANAGED_IDENTITY_CLIENT_ID=your-client-id \
           -e REBUILD_CREDENTIALS=false \
           demo-app-java:latest
```

## Environment Variables

- `AUTH_METHOD` (required): Authentication method to use. Supported values: `pod-identity`, `workload-identity`, `identity-binding`
- `KEYVAULT_URL` (required): Azure Key Vault URL (e.g., `https://your-keyvault.vault.azure.net/`)
- `SECRET_NAME` (optional): Name of the secret to retrieve. Default: `demo-secret`
- `MANAGED_IDENTITY_CLIENT_ID` (required): Client ID of the managed identity to use
- `REBUILD_CREDENTIALS` (optional): Whether to rebuild credentials on each iteration. Default: `false`

## How It Works

1. The application initializes with configuration from environment variables
2. Creates an Azure Default Credential using the specified managed identity client ID
3. Establishes a connection to Azure Key Vault
4. Enters a loop that:
   - Retrieves the specified secret from Key Vault
   - Logs the secret value (for demo purposes)
   - Waits 30 seconds before the next iteration
5. If `REBUILD_CREDENTIALS` is set to `true`, credentials are recreated on each iteration

## Dependencies

- `azure-identity`: Azure authentication library
- `azure-security-keyvault-secrets`: Azure Key Vault secrets client library
- `slf4j-api` & `logback-classic`: Logging framework

## Notes

- The application uses DefaultAzureCredential which automatically handles managed identity authentication
- In Kubernetes environments with workload identity or identity binding, the necessary environment variables and token files are automatically injected
- The application logs are formatted for easy reading and debugging
