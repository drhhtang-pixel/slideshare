# 課程投影片庫 — DITLDESIGN

透過瀏覽器瀏覽課程 PDF 投影片，無需安裝任何軟體。

## 公開網址

部署後可透過以下網址存取：

```
https://drhhtang-pixel.github.io/slideshare/
```

## 新增投影片步驟

1. 將 PDF 檔案複製到 `slides/` 目錄
2. 編輯 `slides/index.json`，在陣列中加入新檔名：
   ```json
   [
     "既有檔案.pdf",
     "新增檔案.pdf"
   ]
   ```
3. 執行 git commit 並推送到 main 分支，GitHub Actions 會自動部署

## 本機預覽

```bash
cd slideshare
python3 -m http.server 8000
```

開啟瀏覽器至 `http://localhost:8000`

## 技術架構

- 純靜態網站：HTML + CSS + PDF.js 3.11.174
- 部署：GitHub Pages（透過 GitHub Actions 自動部署）
- PDF 渲染：[PDF.js](https://mozilla.github.io/pdf.js/)（本地 `js/` 目錄）
- 投影片列表：`slides/index.json`（手動維護）
