# Simulator SSO-SAML Login

This dotnet8 application simulates login to Checkbox8 via SSO-SAML.

## Usage

1. Install SDK .NET8 https://dotnet.microsoft.com/en-us/download/dotnet/8.0
2. Modify URL in code 'apiBaseUrl'.
   - For On-Line version => https://{HOST_NAME}/v1/{ACCOUNT_NAME}/
   - For On-Premise version => https://{HOST_NAME}/v1/
3. If port 5000 is already in use, change the port in the variable 'callbackUrl'.
4. The application will run a browser and request permission from your Identity Provider.
5. Login as the user with access to Checkbox8 admin application.
6. Copy the authorization header from the console and add it to the API requests.
