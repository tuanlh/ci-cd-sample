using System.Net;
using System.Net.Http.Json;
using Microsoft.AspNetCore.Mvc.Testing;
using Xunit;

namespace TaskApi.Tests;

public class ApiTests
{
    [Fact]
    public async Task Health_and_version_are_available()
    {
        await using var factory = new WebApplicationFactory<Program>();
        using var client = factory.CreateClient();
        Assert.Equal(HttpStatusCode.OK, (await client.GetAsync("/health")).StatusCode);
        Assert.Equal(HttpStatusCode.OK, (await client.GetAsync("/version")).StatusCode);
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("   ")]
    public async Task Invalid_title_is_rejected(string? title)
    {
        await using var factory = new WebApplicationFactory<Program>();
        using var client = factory.CreateClient();
        var response = await client.PostAsJsonAsync("/tasks", new { title });
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task Overlong_title_is_rejected()
    {
        await using var factory = new WebApplicationFactory<Program>();
        using var client = factory.CreateClient();
        Assert.Equal(HttpStatusCode.BadRequest,
            (await client.PostAsJsonAsync("/tasks", new { title = new string('x', 121) })).StatusCode);
    }

    [Fact]
    public async Task Task_can_be_created_read_and_completed()
    {
        await using var factory = new WebApplicationFactory<Program>();
        using var client = factory.CreateClient();
        var response = await client.PostAsJsonAsync("/tasks", new { title = "  Learn CI/CD  " });
        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        var task = (await response.Content.ReadFromJsonAsync<TaskItem>())!;
        Assert.Equal("Learn CI/CD", task.Title);
        Assert.False(task.IsCompleted);
        Assert.Equal(task, await client.GetFromJsonAsync<TaskItem>(response.Headers.Location));
        var completed = await client.PutAsync($"/tasks/{task.Id}/complete", null);
        Assert.True((await completed.Content.ReadFromJsonAsync<TaskItem>())!.IsCompleted);
        Assert.Single((await client.GetFromJsonAsync<TaskItem[]>("/tasks"))!);
    }

    [Fact]
    public async Task Unknown_task_returns_404()
    {
        await using var factory = new WebApplicationFactory<Program>();
        using var client = factory.CreateClient();
        var path = $"/tasks/{Guid.NewGuid()}";
        Assert.Equal(HttpStatusCode.NotFound, (await client.GetAsync(path)).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await client.PutAsync(path + "/complete", null)).StatusCode);
    }
}
