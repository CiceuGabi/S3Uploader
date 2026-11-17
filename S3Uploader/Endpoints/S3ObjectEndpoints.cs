using System.Text;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.AspNetCore.Mvc;
using S3Uploader.Contracts;
using S3Uploader.Services;

namespace S3Uploader.Endpoints;

public static class S3ObjectEndpoints
{
    public static IEndpointRouteBuilder MapS3ObjectEndpoints(this IEndpointRouteBuilder app)
    {
        app.MapPost("/api/objects", async Task<Results<Created<UploadTextResponse>, BadRequest<ProblemDetails>>> (
            UploadTextRequest request,
            IS3ObjectService service,
            CancellationToken cancellationToken) =>
        {
            if (Encoding.UTF8.GetByteCount(request.Name) > 1024)
            {
                return TypedResults.BadRequest(new ProblemDetails
                {
                    Status = StatusCodes.Status400BadRequest,
                    Title = "Invalid object name",
                    Detail = "The object name cannot exceed 1,024 UTF-8 bytes."
                });
            }

            var response = await service.UploadTextAsync(
                request.Name,
                request.Text,
                cancellationToken);

            return TypedResults.Created(response.Location, response);
        })
        .WithName("UploadTextObject")
        .WithSummary("Upload text as an S3 object")
        .WithDescription("Stores the supplied text in the configured S3 bucket using the supplied name as the object key.")
        .Produces<UploadTextResponse>(StatusCodes.Status201Created)
        .Produces<ProblemDetails>(StatusCodes.Status400BadRequest)
        .ProducesProblem(StatusCodes.Status500InternalServerError);

        return app;
    }
}
