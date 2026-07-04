// pbtool: write sentinel clips to / inspect the general pasteboard.
// usage: pbtool rich <text>     write RTF(bold red)+plain pair
//        pbtool file <path...>  write file URL(s)
//        pbtool info            print types + string content
import AppKit

let args = CommandLine.arguments
let pb = NSPasteboard.general

switch args.count > 1 ? args[1] : "info" {
case "rich":
    let text = args.count > 2 ? args[2] : "SENTINEL"
    let attr = NSAttributedString(
        string: text,
        attributes: [.font: NSFont.boldSystemFont(ofSize: 18), .foregroundColor: NSColor.red])
    let rtf = try! attr.data(
        from: NSRange(location: 0, length: attr.length),
        documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
    pb.clearContents()
    pb.declareTypes([.rtf, .string], owner: nil)
    pb.setData(rtf, forType: .rtf)
    pb.setString(text, forType: .string)
    print("wrote rich clip: \(text) (rtf \(rtf.count) bytes)")
case "file":
    let urls = args.dropFirst(2).map { URL(fileURLWithPath: $0) as NSURL }
    pb.clearContents()
    pb.writeObjects(urls)
    print("wrote \(urls.count) file URL(s)")
case "info":
    let types = (pb.types ?? []).map { $0.rawValue }.sorted()
    print("changeCount=\(pb.changeCount)")
    print("types=\(types)")
    if let s = pb.string(forType: .string) { print("string=<<<\(s)>>>") }
    print("hasRTF=\(types.contains("public.rtf"))")
default:
    fatalError("unknown mode")
}
