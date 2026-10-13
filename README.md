# pdfstitch

A macOS command-line tool that merges pairs of half-page scanned PDFs into full pages.

## Background

When scanning double-sided documents with a flatbed scanner, each page is scanned separately and the content only occupies the top half of the resulting A4 page. `pdfstitch` takes consecutive half-page scans and stitches them together — placing the first page's top half in the upper portion and the second page's top half in the lower portion — producing a properly formatted full-page PDF.

## Design

### Problem

Each scanned page is a full A4 sheet (595.2 × 841.44 pt) but with content only in the top half, flush to the top edge.

```
┌─────────────┐   ┌─────────────┐
│   content   │   │   content   │
│  (page 1)   │   │  (page 2)   │
├─────────────┤   ├─────────────┤
│             │   │             │
│   (blank)   │   │   (blank)   │
└─────────────┘   └─────────────┘
       ↓↓↓ stitch ↓↓↓
┌─────────────┐
│   content   │
│  (page 1)   │
├─────────────┤
│   content   │
│  (page 2)   │
└─────────────┘
```

### Key Technical Challenge

`CGContext` created via `CGContext(_:mediaBox:_:)` internally uses a hardcoded Letter-size (612 × 792 pt) clip bounds, regardless of the `mediaBox` parameter passed in. When `PDFPage.draw(with:to:)` renders into this context, it maps the page content to the Letter clip region — not our A4 mediaBox. For A4 pages (841.44 pt tall), this causes the top 49.44 pt (= 841.44 − 792) of content to be clipped.

### Solution

Pass the correct A4 `mediaBox` as `kCGPDFContextMediaBox` in the page info dictionary when calling `CGContext.beginPDFPage(_:)`. This overrides the default Letter clip bounds and sets the clip region to match the actual page size, ensuring content is rendered without any clipping.

```swift
var mediaBox = CGRect(x: 0, y: 0, width: W, height: H)
let boxData  = Data(bytes: &mediaBox, count: MemoryLayout<CGRect>.size)
let pageInfo = ["kCGPDFContextMediaBox": boxData]
ctx.beginPDFPage(pageInfo as CFDictionary)
```

### Rendering

Each source page is rendered using `PDFPage.draw(with:to:)` with a clip rect restricting output to either the upper or lower half of the destination page:

- **Page A** (even index): clipped to `y:[H/2 .. H]` → upper half
- **Page B** (odd index): translated by `−H/2`, clipped to `y:[0 .. H/2]` → lower half

This is a lossless vector operation — the original PDF content streams are not rasterized or re-encoded.

## Requirements

- macOS 12+
- Xcode Command Line Tools

## Build

```bash
swiftc main.swift -o pdfstitch
```

To install globally:

```bash
cp pdfstitch /usr/local/bin/
```

## Usage

```bash
# Output defaults to <input>_stitch.pdf in the same directory
pdfstitch input.pdf

# Specify output path explicitly
pdfstitch input.pdf output.pdf
```

### Example

```bash
pdfstitch scan.pdf
# → produces scan_stitch.pdf
```

If the source PDF has an odd number of pages, the last page is included as-is with its top half placed in the upper portion of the final page.
