using System.Diagnostics;
using System.IdentityModel.Tokens.Jwt;
using System.Net;
using System.Text;
using System.Text.Json;
using System.Web;

// Change apiBaseUrl to your API URL
// On-Line version => https://{HOST_NAME}/v1/{ACCOUNT_NAME}/
// On-Premise version => https://{HOST_NAME}/v1/
var apiBaseUrl = "https://localhost:37431/v1/account1/";

// Modify PORT if 5000 already is used
var callbackUrl = "http://localhost:5000/callback/";
var initSsoLoginUrl = $"{apiBaseUrl}saml/init-sso?returnUrl={callbackUrl}?saml_token=saml_token_value";
var checkboxLoginUrl = $"{apiBaseUrl}oauth2/token";

Console.WriteLine("Opening browser for SSO...");
Process.Start(new ProcessStartInfo { FileName = initSsoLoginUrl, UseShellExecute = true });

HttpListener listener = new HttpListener();
listener.Prefixes.Add(callbackUrl);
listener.Start();

Console.WriteLine("Waiting for SAML response...");
var context = listener.GetContext();

var assertionServiceToken = HttpUtility.UrlDecode(context.Request.QueryString["saml_token"]);
Console.WriteLine("Received token from assertion-consumer-service: " + assertionServiceToken);
Console.WriteLine("");

// Get UserName from assertionServiceToken
var handler = new JwtSecurityTokenHandler();
var jwtToken = handler.ReadJwtToken(assertionServiceToken);
var userName = jwtToken.Claims.First(claim => claim.Type == "contactId").Value;

// Write in the browser, that login was a success
context.Response.StatusCode = 200;
using (var writer = new StreamWriter(context.Response.OutputStream))
{
    writer.WriteLine("Login successful! You can close this window.");
}

listener.Stop();

try
{
    // Get bearer token from Checkbox8 API
    var requestModel = $"grant_type=external_provider&provider_name=saml&client_id=AdminWebApp&token={assertionServiceToken}&username={userName}";
    var httpClient = new HttpClient();
    var content = new StringContent(requestModel, Encoding.UTF8, "application/x-www-form-urlencoded");

    // Add headers (User-Agent and any others)
    httpClient.DefaultRequestHeaders.UserAgent.ParseAdd("Checkbox.LoginSimulator/1.0");

    // Send POST request
    var response = await httpClient.PostAsync(checkboxLoginUrl, content);

    if (response.IsSuccessStatusCode)
    {
        var responseData = await response.Content.ReadAsStringAsync();
        using JsonDocument doc = JsonDocument.Parse(responseData);
        var bearerToken = doc.RootElement.GetProperty("access_token").GetString();
        Console.WriteLine("");
        Console.WriteLine("Add the next Header to every request");
        Console.WriteLine("Authorization: Bearer " + bearerToken);
        Console.WriteLine("");
    }
    else
    {
        Console.WriteLine($"Error: {response.StatusCode}");
        Console.WriteLine(await response.Content.ReadAsStringAsync());
    }
}
catch (Exception ex)
{
    Console.WriteLine("Request failed: " + ex.Message);
}

Console.WriteLine($"Click ENTER to close the window");
Console.ReadLine();