using Amazon.S3;
using Amazon.S3.Model;
using Microsoft.Extensions.Options;
using S3Uploader.Contracts;
using S3Uploader.Options;

namespace S3Uploader.Services;

public sealed class S3ObjectService(
    IAmazonS3 s3Client,
    IOptions<S3Options> options) : IS3ObjectService
{
    public async Task<UploadTextResponse> UploadTextAsync(
        string name,
        string text,
        CancellationToken cancellationToken)
    {
        var bucketName = options.Value.BucketName;
        await s3Client.PutObjectAsync(new PutObjectRequest
        {
            BucketName = bucketName,
            Key = name,
            ContentBody = text,
            ContentType = "text/plain; charset=utf-8"
        }, cancellationToken);

        var location = $"s3://{bucketName}/{Uri.EscapeDataString(name)}";
        return new UploadTextResponse(name, bucketName, location);
    }
}
