using System.ComponentModel.DataAnnotations;

namespace S3Uploader.Options;

public sealed class S3Options
{
    public const string SectionName = "S3";

    [Required]
    public string Endpoint { get; init; } = string.Empty;

    [Required]
    public string BucketName { get; init; } = string.Empty;

    [Required]
    public string Region { get; init; } = string.Empty;

    [Required]
    public string AccessKeyId { get; init; } = string.Empty;

    [Required]
    public string SecretAccessKey { get; init; } = string.Empty;
}
