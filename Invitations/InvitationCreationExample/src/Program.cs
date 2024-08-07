using System;
using System.Collections.Generic;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;

class Program
{
    private static readonly string Server = "http://127.0.0.1";
    private static readonly string Username = "admin";
    private static readonly string Password = "admin";
    private static readonly int SurveyToInviteTo = 3011;

    static async Task Main(string[] args)
    {
        string baseUri = $"{Server}/api/v1";
        string tokenUri = $"{baseUri}/oauth2/token";
        string invitationUri = $"{baseUri}/surveys/{SurveyToInviteTo}/invitations";

        try
        {
            var accessToken = await GetJwtToken(tokenUri);
            if (accessToken != null)
            {
                var invitationId = await CreateSurveyInvitation(invitationUri, accessToken);
                if (invitationId.HasValue)
                {
                    Console.WriteLine($"Invitation ID: {invitationId.Value}");
                    await AssignMessageToInvitation(invitationId.Value, accessToken);

                    // List of email addresses to add
                    var emailAddresses = new List<string>
                    {
                        "frank.jones@testmail.com",
                        "steve.stevens@testmail.com",
                        "ari.gato@testmail.com"
                    };

                    await AddRecipientsToInvitation(invitationId.Value, accessToken, emailAddresses);
                    await ScheduleInvitation(invitationId.Value, accessToken);
                }
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Error: {ex.Message}");
        }
    }

    private static async Task<string?> GetJwtToken(string tokenUri)
    {
        using HttpClient client = new HttpClient();
        var content = new FormUrlEncodedContent(new[]
        {
            new KeyValuePair<string, string>("username", Username),
            new KeyValuePair<string, string>("password", Password),
            new KeyValuePair<string, string>("grant_type", "password")
        });

        HttpResponseMessage response = await client.PostAsync(tokenUri, content);
        response.EnsureSuccessStatusCode();

        var responseBody = await response.Content.ReadAsStringAsync();
        var json = JsonDocument.Parse(responseBody);
        return json.RootElement.GetProperty("access_token").GetString();
    }

    private static async Task<int?> CreateSurveyInvitation(string invitationUri, string accessToken)
    {
        using HttpClient client = new HttpClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", accessToken);
        client.DefaultRequestHeaders.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));

        var payload = new
        {
            name = "My Test Campaign",
            invitation_type = "Email",
            created_by = "",
            status = "",
            allow_opt_out = true,
            allow_auto_login = true,
            invitation_link_expiration_in_hours = 168,
            company_profile_id = 1000,
            message_source_invitation_id = (int?)null
        };

        var jsonPayload = JsonSerializer.Serialize(payload);
        var content = new StringContent(jsonPayload, Encoding.UTF8, "application/json");

        HttpResponseMessage response = await client.PostAsync(invitationUri, content);
        response.EnsureSuccessStatusCode();

        var responseBody = await response.Content.ReadAsStringAsync();
        var json = JsonDocument.Parse(responseBody);

        if (json.RootElement.TryGetProperty("id", out var invitationId))
        {
            int id = invitationId.GetInt32();
            Console.WriteLine($"Survey invitation created successfully with ID: {id}");
            return id;
        }
        else
        {
            Console.WriteLine("ID not found in the response.");
            return null;
        }
    }

    private static async Task AssignMessageToInvitation(int invitationId, string accessToken)
    {
        string messageUri = $"{Server}/api/v1/surveys/{SurveyToInviteTo}/invitations/{invitationId}/message";

        using HttpClient client = new HttpClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", accessToken);
        client.DefaultRequestHeaders.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));

        var payload = new
        {
            from_email = "surveyadmin@yourdomain.com",
            from_name = "Checkbox Survey",
            subject = "You have been auto-invited",
            body = "<p><br />Hello @@FirstName <br /><br />An automated system has invited you to a survey.&nbsp; Please follow the link.<br /><br /><a href=\"@@SURVEY_URL_PLACEHOLDER__DO_NOT_ERASE\">Click here to take the survey</a>.</p>",
            invitation_type = "Email"
        };

        var jsonPayload = JsonSerializer.Serialize(payload);
        var content = new StringContent(jsonPayload, Encoding.UTF8, "application/json");

        HttpResponseMessage response = await client.PutAsync(messageUri, content);
        response.EnsureSuccessStatusCode();

        Console.WriteLine("Message assigned to invitation successfully.");
    }

    private static async Task AddRecipientsToInvitation(int invitationId, string accessToken, List<string> emailAddresses)
    {
        string batchUri = $"{Server}/api/v1/surveys/{SurveyToInviteTo}/invitations/{invitationId}/panels/batch?skip_invalid_results=false";

        using HttpClient client = new HttpClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", accessToken);
        client.DefaultRequestHeaders.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));

        var recipients = new List<Dictionary<string, string>>();
        foreach (var email in emailAddresses)
        {
            recipients.Add(new Dictionary<string, string>
        {
            { "value", email },
            { "type", "Email" }
        });
        }

        var jsonPayload = JsonSerializer.Serialize(recipients);
        var content = new StringContent(jsonPayload, Encoding.UTF8, "application/json");

        HttpResponseMessage response = await client.PostAsync(batchUri, content);
        response.EnsureSuccessStatusCode();

        var responseBody = await response.Content.ReadAsStringAsync();
        var responseJson = JsonDocument.Parse(responseBody).RootElement;

        foreach (var recipient in responseJson.EnumerateArray())
        {
            var status = recipient.GetProperty("status").GetString();
            var email = recipient.GetProperty("email").GetString();

            if (status != "Valid")
            {
                Console.WriteLine($"Warning: {email} was not valid.");
            }
        }

        Console.WriteLine("Recipients added successfully.");
    }

    private static async Task ScheduleInvitation(int invitationId, string accessToken)
    {
        string scheduleUri = $"{Server}/api/v1/surveys/{SurveyToInviteTo}/invitations/{invitationId}/schedules";

        using HttpClient client = new HttpClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", accessToken);
        client.DefaultRequestHeaders.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));

        var payload = new
        {
            scheduled_date = DateTime.UtcNow.ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
        };

        var jsonPayload = JsonSerializer.Serialize(payload);
        var content = new StringContent(jsonPayload, Encoding.UTF8, "application/json");

        HttpResponseMessage response = await client.PostAsync(scheduleUri, content);
        response.EnsureSuccessStatusCode();

        Console.WriteLine("Invitation scheduled successfully.");
    }

}
