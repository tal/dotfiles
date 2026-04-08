---
description: Find, transcribe, and sort downloaded videos from Downloads into topic folders in AI Library
---

# Sort and Transcribe Downloaded Videos

Find all video files downloaded by yt-dlp in `~/Downloads` (root level) and `~/Downloads/Recents/`. Files follow the yt-dlp naming pattern: `<Platform> - <title> [<id>].mp4` (e.g., `Instagram - Video by stuartbrazell [DWM02r5EtFq].mp4`). Also match the legacy pattern `Video by*.mp4` for older downloads. Do NOT include files already inside `~/Downloads/AI Library/`.

For each video found, do the following:

## 1. Transcribe

- Convert the video to 16kHz mono WAV using ffmpeg: `ffmpeg -i "<video>" -ar 16000 -ac 1 -c:a pcm_s16le /tmp/<slug>.wav -y`
- Transcribe with whisper-cpp: `whisper-cli -m /tmp/ggml-base.bin -f /tmp/<slug>.wav --no-timestamps`
- If the whisper model isn't downloaded yet, fetch it: `curl -L -o /tmp/ggml-base.bin "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin"`
- If the transcription is blank/silent, skip the video and report it at the end.

## 2. Enrich from source

After transcribing, extract the video ID from the filename (the `[XXX]` part before the extension) and the platform prefix (e.g., `Instagram`, `TikTok`, `Youtube`).

For **Instagram** videos, fetch the post caption via the oEmbed API:

```
curl -s "https://www.instagram.com/api/v1/oembed/?url=https://www.instagram.com/reel/<VIDEO_ID>/" | jq -r '.title'
```

For other platforms, skip the oEmbed step and rely on the transcription.

Use the caption to enrich the markdown in the following cases:

- **Recipes:** If the transcription is about cooking/food, check the caption for a full ingredient list with measurements and detailed instructions. Replace or supplement the transcription-based recipe with the exact quantities from the caption.
- **Lists of items:** If the transcription references a list (e.g., game recommendations, restaurants, products, tips), check the caption for the complete list with details. Include the full list in the markdown rather than relying solely on what was spoken.

If the oEmbed request fails or returns no useful caption, proceed with just the transcription.

## 3. Categorize

Based on the transcription content, determine the best topic folder. Reuse existing folders in `~/Downloads/AI Library/` when the content fits. Common categories include but are not limited to:

- Comedy
- Marvel & TV
- Self-Improvement
- Food & Restaurants
- Game Recs
- Tech
- Music
- Sports
- Education

If none of the existing folders fit, create a new descriptively named topic folder.

## 4. Rename, move, and create markdown

- Rename the `.mp4` file to include a brief description of the content while keeping the platform, creator name, and video ID. Format: `<brief-description> - <platform> - <creator name> [<video ID>].mp4` (e.g., `sesame-chicken-recipe - Instagram - Video by louishowardpt [DVs_UEwiIx9].mp4`). For legacy files without a platform prefix, use `Instagram` as the default. Keep the description short (2-5 words, lowercase, hyphenated).
- Create the topic folder under `~/Downloads/AI Library/` if it doesn't exist.
- Move the renamed `.mp4` file into that folder.
- Create a matching `.md` file with the same base name, containing:
  - An H1 title: `# Video by <creator name>`
  - An H2 subtitle summarizing the video topic
  - The transcription, cleaned up and formatted nicely with markdown (lists, bold for names/titles, sections where appropriate)
  - Extract and highlight key items (game names, restaurant names, tips, people, etc.) rather than dumping raw transcript text.

## 5. Parallel processing

- Convert all videos to WAV in parallel (background ffmpeg jobs).
- Transcribe all videos in parallel (separate bash calls or subagents).

## 6. Report

When finished, print a summary table of all videos processed:

| Video | Topic Folder | Summary |
|-------|-------------|---------|

Also list any videos that were skipped (blank audio, errors, etc.).
