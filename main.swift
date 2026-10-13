import Foundation
import PDFKit
import CoreGraphics

func mergePDF(input: String, output: String) {
    guard let srcDoc = PDFDocument(url: URL(fileURLWithPath: input)) else {
        print("ERROR: cannot open \(input)")
        exit(1)
    }

    let pageCount = srcDoc.pageCount
    guard let p0 = srcDoc.page(at: 0) else { exit(1) }
    let bounds = p0.bounds(for: .mediaBox)
    let W = bounds.size.width
    let H = bounds.size.height

    var mediaBox = CGRect(x: 0, y: 0, width: W, height: H)
    let outURL = URL(fileURLWithPath: output)
    guard let ctx = CGContext(outURL as CFURL, mediaBox: &mediaBox, nil) else {
        print("ERROR: cannot create PDF context")
        exit(1)
    }

    // Pass correct A4 mediaBox to each page
    let boxData = Data(bytes: &mediaBox, count: MemoryLayout<CGRect>.size)
    let pageInfo: [String: Any] = ["kCGPDFContextMediaBox": boxData]

    let pairs = pageCount / 2

    for i in 0 ..< pairs {
        guard let pageA = srcDoc.page(at: i * 2),
              let pageB = srcDoc.page(at: i * 2 + 1) else { continue }

        ctx.beginPDFPage(pageInfo as CFDictionary)

        // pageA top half → upper half of dest
        ctx.saveGState()
        ctx.clip(to: CGRect(x: 0, y: H/2, width: W, height: H/2))
        pageA.draw(with: .mediaBox, to: ctx)
        ctx.restoreGState()

        // pageB top half → lower half of dest
        ctx.saveGState()
        ctx.clip(to: CGRect(x: 0, y: 0, width: W, height: H/2))
        ctx.translateBy(x: 0, y: -(H/2))
        pageB.draw(with: .mediaBox, to: ctx)
        ctx.restoreGState()

        ctx.endPDFPage()
    }

    // Odd page: top half → upper half only
    if pageCount % 2 != 0, let last = srcDoc.page(at: pageCount - 1) {
        ctx.beginPDFPage(pageInfo as CFDictionary)
        ctx.saveGState()
        ctx.clip(to: CGRect(x: 0, y: H/2, width: W, height: H/2))
        last.draw(with: .mediaBox, to: ctx)
        ctx.restoreGState()
        ctx.endPDFPage()
    }

    ctx.closePDF()
    print("Done: \(output) (\(pairs + pageCount % 2) pages)")
}

let args = CommandLine.arguments
guard args.count >= 2 else {
    print("Usage: pdfstitch <input.pdf> [output.pdf]")
    exit(1)
}

let input = args[1]
let output: String
if args.count >= 3 {
    output = args[2]
} else {
    // Default: append _stitch before the .pdf extension
    let url = URL(fileURLWithPath: input)
    let name = url.deletingPathExtension().lastPathComponent
    let dir  = url.deletingLastPathComponent().path
    output = "\(dir)/\(name)_stitch.pdf"
}

mergePDF(input: input, output: output)
