using System.ComponentModel.DataAnnotations;

namespace S3Uploader.Contracts;

/// <summary>Text content and the S3 object key to upload.</summary>
public sealed record UploadTextRequest
{
    /// <summary>The name to use as the S3 object key.</summary>
    [Required, MaxLength(1024)]
    public required string Name { get; init; }

    /// <summary>The text to store as the object content. Empty content is allowed.</summary>
    [Required(AllowEmptyStrings = true)]
    public required string Text { get; init; }
}
