### **1. Infrastructure (Terraform)**

You need to allow your backend Lambda function to access the ElevenLabs API and store the generated audio files.

- **Secrets Management (`modules/secrets` & `modules/compute`):**
- Add a new secret `elevenlabs_api_key` to SSM Parameter Store (following the existing pattern).
- The `ELEVENLABS_API_KEY_PARAM` env var is injected into all Lambda functions via `local.lambda_env_vars`, providing the SSM parameter path for runtime secret fetching.

- **S3 Permissions (`modules/compute/iam.tf`):**
- The existing Lambda role has `s3:PutObject` permissions on `${var.static_content_s3_bucket_arn}/*`.
- **Action:** Reuse this bucket for audio files to keep infrastructure simple. Establish a convention that audio files are stored under an `audio/` prefix.
- **Action:** Ensure the CORS configuration on this bucket allows `GET` requests from your frontend domain so users can play the audio.

- **Environment Variables:**
- `STATIC_CONTENT_S3_BUCKET` — the S3 bucket name (available to all Lambdas)
- `STATIC_CONTENT_CDN_DOMAIN` — the CDN domain for serving content (available to all Lambdas)
- `ELEVENLABS_API_KEY_PARAM` — SSM parameter path for the ElevenLabs API key (available to all Lambdas)
- **Note:** The CDN domain (`images.*.cosmonaut-ai.com`) and S3 bucket name (`cosmonaut-ai-${env}-images`) remain unchanged in AWS. Only the Terraform module/variable names were renamed from `images` to `static_content`.

### **2. Data Modeling (Cosmonaut API)**

We need to store references to the audio files on the story nodes and track user usage.

- **Story Node Entity (`app/models/entities/story_node.py`):**
- Add new attributes to the `StoryNode` class:
- `audio_url` (UnicodeAttribute, null=True): Stores the S3 URL of the generated audio.
- `audio_voice_id` (UnicodeAttribute, null=True): Stores the ID of the voice used (useful for consistency).
- `audio_status` (UnicodeAttribute, default='pending'): Tracks generation state (e.g., `pending`, `completed`, `failed`) to prevent duplicate requests.

- **User Usage Entity (`app/models/entities/usage.py`):**
- Add a new attribute: `audio_narrations_used` (NumberAttribute, default=0).
- This will track usage against the quotas you defined.

### **3. Backend Implementation (Cosmonaut API)**

- **Environment Variable Rename (Breaking Change):**
- The S3/CDN env vars were renamed from `IMAGES_S3_BUCKET` / `IMAGES_CDN_DOMAIN` to `STATIC_CONTENT_S3_BUCKET` / `STATIC_CONTENT_CDN_DOMAIN`. Any existing code reading the old names must be updated.
- These env vars are now promoted to **all** Lambda functions (API, fast worker, slow worker, streaming API) via `local.lambda_env_vars`. Previously they were only on the slow worker. This means audio generation can run synchronously on the API Lambda without needing to dispatch to a worker.
- The underlying S3 bucket (`cosmonaut-ai-${env}-images`) and CDN domain (`images.*.cosmonaut-ai.com`) are **unchanged** — only the env var names changed.
- A new env var `ELEVENLABS_API_KEY_PARAM` is available on all Lambdas, containing the SSM parameter path for the ElevenLabs API key.

- **Configuration (`app/core/config.py`):**
- Update `TIER_LIMITS` to include `audio_limit` for each tier:
- **Free:** Set a low fixed limit (e.g., 20) to represent "one story".
- **Explorer:** 60.
- **Cosmonaut:** 200.

- **Usage Service (`app/services/usage.py`):**
- Update `_METRIC_ATTR` mapping to include `"audio": "audio_narrations_used"`.
- **Crucial Logic Change:** Modify `get_or_create_usage`. In the "Lazy period reset" block, add logic to _skip_ resetting `audio_narrations_used` if the user is on the **Free** tier. This enforces the "First story only" (lifetime limit) rule, whereas paid tiers should reset monthly.

- **Audio Service (`app/services/audio.py` - New File):**
- Create a service to handle ElevenLabs interaction.
- Fetch the API key at runtime via SSM using the `ELEVENLABS_API_KEY_PARAM` env var (following the same pattern as Gemini/Pinecone keys).
- Implement `generate_audio(text: str, voice_id: str) -> bytes`:
- Calls ElevenLabs Text-to-Speech API using the **Flash 2.5** model (`eleven_flash_v2_5`).
- **Tier Logic:** You can select different voice IDs or models here based on the user's tier if you want to enforce the "Standard" vs "Neural" differentiation mentioned in your pricing (e.g., use `eleven_flash_v2_5` for Explorer and `eleven_multilingual_v2` or `eleven_turbo_v2_5` for Cosmonaut, or simply use Flash 2.5 for everyone as requested).

- Implement `upload_audio_to_s3(audio_data: bytes, node_id: str) -> str`:
- Read the bucket name from the `STATIC_CONTENT_S3_BUCKET` env var.
- Uploads the bytes to S3 key `audio/{world_id}/{node_id}.mp3`.
- Construct the public URL using the `STATIC_CONTENT_CDN_DOMAIN` env var (e.g., `https://{cdn_domain}/audio/{world_id}/{node_id}.mp3`). No presigned URLs are needed since CloudFront serves via OAC.

- **API Router (`app/api/story_nodes.py`):**
- Create a new endpoint: `POST /worlds/{world_id}/nodes/{node_id}/audio`.
- This runs synchronously on the API Lambda (ElevenLabs Flash 2.5 generates in 1-3s, well within the 29s API Gateway timeout).
- **Workflow:**

1. Fetch the `StoryNode`.
2. If `node.audio_url` already exists, return it immediately.
3. Call `usage_service.check_and_increment(user_id, "audio")` to verify quota.
4. Call `audio_service.generate_audio` with the node's text.
5. Call `audio_service.upload_audio_to_s3`.
6. Update `StoryNode` with the new `audio_url` and `audio_status`.
7. Return the URL.

### **4. Frontend Implementation (Cosmonaut Web)**

- **Tier Configuration (`src/lib/config/tiers.ts`):**
- Update `TIER_CONFIG` to display the audio limits in the pricing UI features list.

- **API Client (`src/lib/api/client.ts`):**
- Add a `generateNodeAudio(worldId, nodeId)` function calling the new backend endpoint.

- **Node View (`src/lib/components/story/StoryNodeView.svelte`):**
- **State:** Add `isGeneratingAudio` state.
- **UI:** Add a "Play Narration" button (e.g., near the existing "Read Aloud" / `Volume2` icon).
- **Logic:**
- If `node.audio_url` is present, the button acts as a Play/Pause toggle using a standard HTML `<audio>` element or specific Svelte audio handling.
- If `node.audio_url` is missing, the button triggers `generateNodeAudio`.
- Handle `QuotaExceededError` by showing the `UpgradePrompt` (reuse the existing mechanism used for text generation).

- **Constraint:** Ensure the audio button is disabled while the text is still streaming/generating (`isStreaming` or `isNodeGenerating`).

- **Clean Up:**
- The existing text-to-speech implementation (using `window.speechSynthesis`) in `StoryNodeView.svelte` should likely be removed or hidden behind a "System Voice" fallback if you want to strictly push the ElevenLabs integration.

### **5. Summary of Workflow**

1. **User** clicks "Play Audio" on a story node.
2. **Frontend** calls `POST /audio`.
3. **Backend** checks if User has used < 60 (Explorer) audio generations this month.
4. **Backend** sends text to ElevenLabs Flash 2.5.
5. **Backend** saves MP3 to S3 and updates DynamoDB.
6. **Backend** returns URL.
7. **Frontend** plays the MP3.
