#!/bin/zsh

PYTHON3=/Library/Frameworks/Python.framework/Versions/3.12/bin/python3
COSCMD=/Library/Frameworks/Python.framework/Versions/3.12/bin/coscmd
GIT=/usr/bin/git
PROJECT="/Users/olddrhhtang/Claude Code/Slideshares/slideshare"

cd "$PROJECT"

exec >> "$PROJECT/slides/publish-slides.log" 2>&1

STEP="初始化"

_on_error() {
  osascript -e "display notification \"上傳失敗：$STEP\" with title \"Slideshare\""
}
trap '_on_error' ERR
set -e

# Convert Keynote files
for keyfile in "$PROJECT"/slides/*.key(N); do
  [ -e "$keyfile" ] || continue
  filename=$(basename "$keyfile")
  pdffile="${keyfile%.key}.pdf"
  [ -e "$pdffile" ] && { echo "[略過] $filename → PDF 已存在"; continue; }
  STEP="轉檔：$filename"
  osascript <<APPLESCRIPT
tell application "Keynote"
  open POSIX file "$keyfile"
  export front document to POSIX file "$pdffile" as PDF
  close front document saving no
end tell
APPLESCRIPT
done

# Convert PowerPoint files
for pptxfile in "$PROJECT"/slides/*.pptx(N); do
  [ -e "$pptxfile" ] || continue
  filename=$(basename "$pptxfile")
  pdffile="${pptxfile%.pptx}.pdf"
  [ -e "$pdffile" ] && { echo "[略過] $filename → PDF 已存在"; continue; }
  STEP="轉檔：$filename"
  osascript <<APPLESCRIPT
tell application "Microsoft PowerPoint"
  open POSIX file "$pptxfile"
  save active presentation in "$pdffile" as save as PDF
  close active presentation saving no
end tell
APPLESCRIPT
done

STEP="產生縮圖"
$PYTHON3 -c "
import os, sys
from pathlib import Path

try:
    import fitz
except ImportError:
    print('[縮圖略過] pymupdf 未安裝，執行 pip3 install pymupdf 以啟用縮圖產生')
    sys.exit(0)

slides_dir = '$PROJECT/slides'
thumbs_dir = os.path.join(slides_dir, 'thumbs')
os.makedirs(thumbs_dir, exist_ok=True)

for pdf_path in sorted(Path(slides_dir).glob('*.pdf')):
    thumb_path = os.path.join(thumbs_dir, pdf_path.stem + '.jpg')
    if os.path.exists(thumb_path):
        print(f'[略過] {pdf_path.name} → 縮圖已存在')
        continue
    try:
        doc = fitz.open(str(pdf_path))
        page = doc[0]
        rect = page.rect
        scale = min(640 / max(rect.width, rect.height), 1.0)
        mat = fitz.Matrix(scale, scale)
        pix = page.get_pixmap(matrix=mat)
        data = pix.tobytes(output='jpg', jpg_quality=85)
        with open(thumb_path, 'wb') as f:
            f.write(data)
        doc.close()
        print(f'[縮圖] {pdf_path.name}')
    except Exception as e:
        print(f'[錯誤] {pdf_path.name}: {e}')
" || osascript -e 'display notification "縮圖產生失敗，已略過" with title "Slideshare"'

STEP="產生 index.json"
$PYTHON3 -c "
import os, json
from datetime import datetime

d = '$PROJECT/slides'
index_path = os.path.join(d, 'index.json')

# Load existing index and build lookup keyed by 'file'
existing = {}
if os.path.exists(index_path):
    with open(index_path, 'r', encoding='utf-8') as f:
        data = json.load(f)
    if data and isinstance(data[0], str):
        # Legacy plain string array — migrate each entry, preserve order intent
        now = datetime.now().strftime('%Y-%m-%dT%H:%M:%S')
        for s in data:
            title = s[:-4] if s.lower().endswith('.pdf') else s
            existing[s] = {'file': s, 'title': title, 'uploaded': now}
    else:
        for obj in data:
            existing[obj['file']] = obj

# Scan slides/ sorted by mtime descending (newest first)
pdfs = sorted(
    [f for f in os.listdir(d) if f.lower().endswith('.pdf')],
    key=lambda f: os.path.getmtime(os.path.join(d, f)),
    reverse=True
)

now = datetime.now().strftime('%Y-%m-%dT%H:%M:%S')
result = []
for filename in pdfs:
    if filename in existing:
        result.append(existing[filename])
    else:
        title = filename[:-4] if filename.lower().endswith('.pdf') else filename
        result.append({'file': filename, 'title': title, 'uploaded': now})

with open(index_path, 'w', encoding='utf-8') as fp:
    json.dump(result, fp, ensure_ascii=False, indent=2)
"

STEP="COS 上傳"
$COSCMD upload -rs slides/ /slides/ || \
  osascript -e 'display notification "COS 上傳失敗，已略過" with title "Slideshare"'

STEP="git push"
$GIT add slides/
$GIT diff --cached --quiet || $GIT commit -m "update slides $(date '+%Y-%m-%d %H:%M')"
$GIT push

osascript -e 'display notification "GitHub 已更新 ✓" with title "Slideshare"'
