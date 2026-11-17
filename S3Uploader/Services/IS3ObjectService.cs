using S3Uploader.Contracts;

namespace S3Uploader.Services;

public interface IS3ObjectService
{
    Task<UploadTextResponse> UploadTextAsync(
        string name,
        string text,
        CancellationToken cancellationToken);
}
