using Amazon.S3;
using Amazon.Runtime;
using S3Uploader.Endpoints;
using S3Uploader.Options;
using S3Uploader.Services;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
// Learn more about configuring OpenAPI at https://aka.ms/aspnet/openapi
builder.Services.AddOpenApi();
builder.Services.AddProblemDetails();
builder.Services.AddValidation();

builder.Services.AddOptions<S3Options>()
    .BindConfiguration(S3Options.SectionName)
    .ValidateDataAnnotations()
    .ValidateOnStart();

builder.Services.AddSingleton<IAmazonS3>(serviceProvider =>
{
    var options = serviceProvider.GetRequiredService<Microsoft.Extensions.Options.IOptions<S3Options>>().Value;
    var config = new AmazonS3Config
    {
        ServiceURL = options.Endpoint,
        ForcePathStyle = true,
        AuthenticationRegion = options.Region
    };

    return new AmazonS3Client(
        new BasicAWSCredentials(options.AccessKeyId, options.SecretAccessKey),
        config);
});
builder.Services.AddSingleton<IS3ObjectService, S3ObjectService>();
builder.Services.AddHealthChecks();

var app = builder.Build();

// Configure the HTTP request pipeline.
app.UseExceptionHandler();
app.UseStatusCodePages();

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
}

app.UseHttpsRedirection();
app.MapS3ObjectEndpoints();
app.MapHealthChecks("/health");

app.Run();
