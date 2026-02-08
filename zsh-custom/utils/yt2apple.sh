#!/bin/bash

# Example: `yt2apple https://www.youtube.com/watch\?v\=TDG5YejapUA\&t\=183s`
# Downloads the best audio from the given YouTube URL, extracts metadata, and adds it to Apple Music with proper tags.
# Depends on: yt-dlp, ffmpeg, and jq.
yt2apple() {
  (( $# == 1 )) || { echo "Usage: yt2apple <YouTube URL>"; return 1 }

  local url="$1"
  local temp_dir=$(mktemp -d) || { echo "Failed to create temp dir"; return 1 }
  pushd "$temp_dir" > /dev/null

  # 1. Download best native audio + get full metadata JSON
  yt-dlp -f bestaudio \
    -f "bestaudio[ext=m4a]/bestaudio" \
    --audio-format m4a \
    --embed-thumbnail \
    --print-json \
    -o "audio.%(ext)s" \
    --extract-audio \
    --audio-quality 0 \
    "$url" > info.json

  # Remove first line if it's "NA" (fixes invalid JSON)
  if [[ $(head -n 1 info.json) == "NA" ]]; then
    tail -n +2 info.json > temp.json
    mv temp.json info.json
  fi

  # 2. Find the downloaded audio file
  local audio_file
  audio_file=$(ls audio.* 2>/dev/null | head -1)
  [[ -z "$audio_file" ]] && { echo "Error: No audio file downloaded"; return 1; }

  # 3. Extract metadata safely with jq
  local artist title date year safe_filename
  artist=$(jq -r '.uploader // .channel // "Unknown Artist"' info.json)
  title=$(jq -r '.title // "Unknown Title"' info.json)
  date=$(jq -r '.upload_date' info.json)  # → 20150730
  # year=${date:0:4}        # Bash substring expansion

  safe_filename="${artist} - ${title}.m4a"

  ## return here to debug yt-dlp
  # return

  # 4. Convert + tag with ffmpeg (works with any source format)
  ffmpeg \
    -i "$audio_file" \
    -codec copy \
    -metadata title="$title" \
    -metadata artist="$artist" \
    -metadata album="YouTube" \
    -metadata date="$date" \
    -loglevel warning \
    -y "$safe_filename"

  # 5. Move to Apple Music
  # mv "$safe_filename" ~/Downloads/
  mv "$safe_filename" ~/Music/Music/Media.localized/"Automatically Add to Music.localized"/

  echo "✓ Added to Apple Music: $artist — $title"

  popd > /dev/null
  rm -rf "$temp_dir"
}

# # An older version that relies on yt-dlp's built-in metadata embedding, which I couldn't get to work, so for now we're using ffmpeg to tag the files instead.
# yt2apple() {
#   [[ $# -eq 1 ]] || { echo "Usage: yt2apple <URL>"; return 1; }

#   yt-dlp \
#     -f "bestaudio[ext=m4a]/bestaudio" \
#     --audio-format m4a \
#     --audio-quality 0 \
#     --embed-metadata \
#     --parse-metadata "title:%(title)s" \
#     --parse-metadata "artist:%(uploader,channel)s" \
#     --parse-metadata "album:YouTube" \
#     --parse-metadata "date:%(upload_date)s" \
#     --postprocessor-args "Metadata:-movflags +faststart" \
#     --embed-thumbnail \
#     -o "~/Downloads/%(uploader,channel,Unknown Artist|)s - %(title)s.%(ext)s" \
#     "$1"

#   echo "✓ Added to Apple Music"
# }
