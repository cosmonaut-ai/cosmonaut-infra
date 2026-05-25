# Audio Narration Infrastructure

This note describes the infrastructure pieces required for Cosmonaut's generated audio narration.

## Terraform Resources

Audio narration depends on existing infrastructure modules:

- `modules/secrets`: SSM Parameter Store placeholder for `elevenlabs_api_key`.
- `modules/compute`: Lambda environment variables and IAM permission to read the ElevenLabs parameter.
- `modules/static_content`: S3 and CloudFront resources used to serve generated MP3 files.

The relevant Lambda environment variables are:

- `STATIC_CONTENT_S3_BUCKET`: target bucket for generated assets.
- `STATIC_CONTENT_CDN_DOMAIN`: CDN hostname used to construct public asset URLs.
- `ELEVENLABS_API_KEY_PARAM`: SSM parameter name for the ElevenLabs API key.

The underlying bucket and CDN may still use historical `images` naming in AWS, but the Terraform and API-facing variables should use the generic static-content names.

## Secret Handling

Populate the ElevenLabs key in SSM for each environment:

```bash
aws ssm put-parameter \
  --name "/dev/cosmonaut/elevenlabs_api_key" \
  --value "..." \
  --type "SecureString" \
  --overwrite
```

Use `/prod/cosmonaut/elevenlabs_api_key` for production. Do not put provider keys in Terraform variables, source files, or documentation examples.

## API Integration

The API stores generated audio references on story nodes and enforces narration quotas through the usage service. Current API-facing concepts:

- story node audio URL
- selected voice ID
- audio generation status
- audio usage counters by subscription tier

The API route is responsible for:

1. Fetching the story node.
2. Returning an existing audio URL when present.
3. Checking and incrementing user quota.
4. Calling ElevenLabs.
5. Uploading the MP3 to S3 under an `audio/` prefix.
6. Updating the story node with the generated audio metadata.

## Frontend Integration

The web client should call the typed API modules under `src/lib/api/` and the corresponding query or mutation hooks under `src/lib/queries/`. UI components should treat quota errors the same way as other subscription-gated generation features.

## Operational Notes

- Audio generation should complete within API Gateway timeout when using a low-latency ElevenLabs model.
- Generated MP3 objects can contain private story content; keep bucket access constrained through CloudFront and avoid logging full URLs in public issue reports.
- CORS must allow the deployed frontend domains to fetch audio files.
