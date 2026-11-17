namespace S3Uploader.Contracts;

/// <summary>Details of the uploaded S3 object.</summary>
public sealed record UploadTextResponse(
    string Name,
    string Bucket,
    string Location);
