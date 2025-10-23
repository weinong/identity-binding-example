package com.azure.demo;

import com.azure.core.credential.TokenCredential;
import com.azure.identity.DefaultAzureCredential;
import com.azure.identity.DefaultAzureCredentialBuilder;
import com.azure.security.keyvault.secrets.SecretClient;
import com.azure.security.keyvault.secrets.SecretClientBuilder;
import com.azure.security.keyvault.secrets.models.KeyVaultSecret;

import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;

public class KeyVaultDemoApp {
    private static final DateTimeFormatter DATE_FORMATTER = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");

    private static void log(String message) {
        System.out.println(LocalDateTime.now().format(DATE_FORMATTER) + " - " + message);
        System.out.flush();
    }

    public static void main(String[] args) {
        log("=== Application Starting ===");
        
        SecretClient secretClient = null;
        String secretName = "demo-secret";
        
        try {
            log("Starting Azure Key Vault demo application...");

            // Get Key Vault URL from environment variable
            String keyVaultUrl = System.getenv("KEYVAULT_URL");
            log("KEYVAULT_URL: " + keyVaultUrl);
            if (keyVaultUrl == null || keyVaultUrl.isEmpty()) {
                log("ERROR: KEYVAULT_URL environment variable is not set");
                System.exit(1);
            }

            // Get secret name from environment variable (default to "demo-secret")
            secretName = System.getenv("SECRET_NAME");
            if (secretName == null || secretName.isEmpty()) {
                secretName = "demo-secret";
            }

            log("Using Azure DefaultAzureCredential for authentication");
            log("Configured to use Key Vault: " + keyVaultUrl);
            log("Secret name: " + secretName);
            log("Starting secret retrieval loop (every 30 seconds)...");

            // Create Key Vault client once
            try {
                log("Creating credential...");
                TokenCredential credential = createCredential();
                log("Creating Key Vault client...");
                secretClient = new SecretClientBuilder()
                        .vaultUrl(keyVaultUrl)
                        .credential(credential)
                        .buildClient();
                log("Key Vault client created successfully");
            } catch (Exception e) {
                log("ERROR: Failed to create Key Vault client: " + e.getMessage());
                e.printStackTrace();
                System.exit(1);
                return; // This line will never be reached, but satisfies the compiler
            }
        } catch (Exception e) {
            log("ERROR in main initialization: " + e.getMessage());
            e.printStackTrace();
            System.exit(1);
        }

        // Main loop - retrieve secrets every 30 seconds
        while (true) {
            String timestamp = LocalDateTime.now().format(DATE_FORMATTER);
            log("\n=== Iteration at " + timestamp + " ===");

            try {
                // Retrieve the secret
                KeyVaultSecret secret = secretClient.getSecret(secretName);
                
                if (secret == null || secret.getValue() == null) {
                    log("ERROR: Secret value is null");
                } else {
                    log("Successfully retrieved secret content \"" + secret.getValue() + "\" from Key Vault");
                }

            } catch (Exception e) {
                log("ERROR: Failed to get secret: " + e.getMessage());
                e.printStackTrace();
            }

            // Wait 30 seconds before next iteration
            try {
                Thread.sleep(30000);
            } catch (InterruptedException e) {
                log("Sleep interrupted: " + e.getMessage());
                Thread.currentThread().interrupt();
                break;
            }
        }
    }

    private static TokenCredential createCredential() {
        // DefaultAzureCredential automatically uses Managed Identity in Azure environments
        // It works for pod-identity, workload-identity, and identity-binding
        return new DefaultAzureCredentialBuilder().build();
    }
}
