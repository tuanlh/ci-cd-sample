using System.Collections.Concurrent;

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddSingleton<TaskStore>();
var app = builder.Build();

app.MapGet("/health", () => Results.Ok(new { status = "healthy" }));
app.MapGet("/version", (IConfiguration config) => Results.Ok(new
{
    version = config["APP_VERSION"] ?? "local",
    environment = app.Environment.EnvironmentName
}));
app.MapGet("/tasks", (TaskStore store) => Results.Ok(store.All()));
app.MapPost("/tasks", (CreateTask request, TaskStore store) =>
{
    if (string.IsNullOrWhiteSpace(request.Title) || request.Title.Length > 200)
        return Results.ValidationProblem(new Dictionary<string, string[]>
        {
            ["title"] = ["Title must contain 1–120 characters and cannot be blank."]
        });
    var task = store.Add(request.Title.Trim());
    return Results.Created($"/tasks/{task.Id}", task);
    //return Results.Ok(task);
});
app.MapGet("/tasks/{id:guid}", (Guid id, TaskStore store) =>
    store.Find(id) is { } task ? Results.Ok(task) : Results.NotFound());
app.MapPut("/tasks/{id:guid}/complete", (Guid id, TaskStore store) =>
    store.Complete(id) is { } task ? Results.Ok(task) : Results.NotFound());
app.Run();

public partial class Program { }
public record CreateTask(string? Title);
public record TaskItem(Guid Id, string Title, bool IsCompleted);
public sealed class TaskStore
{
    private readonly ConcurrentDictionary<Guid, TaskItem> tasks = new();
    public TaskItem[] All() => tasks.Values.OrderBy(t => t.Title).ToArray();
    public TaskItem? Find(Guid id) => tasks.GetValueOrDefault(id);
    public TaskItem Add(string title)
    {
        var task = new TaskItem(Guid.NewGuid(), title, false);
        tasks[task.Id] = task;
        return task;
    }
    public TaskItem? Complete(Guid id)
    {
        while (tasks.TryGetValue(id, out var task))
        {
            var completed = task with { IsCompleted = true };
            if (tasks.TryUpdate(id, completed, task)) return completed;
        }
        return null;
    }
}
