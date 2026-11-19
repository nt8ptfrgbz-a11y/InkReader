import AppKit

let output = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "InkReader/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
let image = NSImage(size: NSSize(width: 1024, height: 1024))
image.lockFocus()
let rect = NSRect(x: 0, y: 0, width: 1024, height: 1024)
NSGradient(starting: NSColor(srgbRed: 0.16, green: 0.28, blue: 0.22, alpha: 1), ending: NSColor(srgbRed: 0.08, green: 0.17, blue: 0.13, alpha: 1))!.draw(in: rect, angle: -80)
let gold = NSColor(srgbRed: 0.78, green: 0.69, blue: 0.46, alpha: 1)
let paper = NSColor(srgbRed: 0.94, green: 0.90, blue: 0.79, alpha: 1)
let left = NSBezierPath()
left.move(to: NSPoint(x: 200, y: 285)); left.line(to: NSPoint(x: 200, y: 730))
left.curve(to: NSPoint(x: 496, y: 680), controlPoint1: NSPoint(x: 306, y: 760), controlPoint2: NSPoint(x: 411, y: 748))
left.line(to: NSPoint(x: 496, y: 245))
left.curve(to: NSPoint(x: 200, y: 285), controlPoint1: NSPoint(x: 402, y: 310), controlPoint2: NSPoint(x: 300, y: 320))
paper.setFill(); left.fill()
let right = NSBezierPath()
right.move(to: NSPoint(x: 528, y: 245)); right.line(to: NSPoint(x: 528, y: 680))
right.curve(to: NSPoint(x: 824, y: 730), controlPoint1: NSPoint(x: 613, y: 748), controlPoint2: NSPoint(x: 718, y: 760))
right.line(to: NSPoint(x: 824, y: 285))
right.curve(to: NSPoint(x: 528, y: 245), controlPoint1: NSPoint(x: 724, y: 320), controlPoint2: NSPoint(x: 622, y: 310))
paper.withAlphaComponent(0.93).setFill(); right.fill()
gold.setStroke()
for y in [460.0, 515, 570] {
    let line = NSBezierPath(); line.lineWidth = 9; line.lineCapStyle = .round
    line.move(to: NSPoint(x: 264, y: y)); line.curve(to: NSPoint(x: 430, y: y - 15), controlPoint1: NSPoint(x: 320, y: y + 8), controlPoint2: NSPoint(x: 380, y: y + 2)); line.stroke()
}
let ribbon = NSBezierPath()
ribbon.move(to: NSPoint(x: 687, y: 734)); ribbon.line(to: NSPoint(x: 744, y: 740)); ribbon.line(to: NSPoint(x: 744, y: 515)); ribbon.line(to: NSPoint(x: 715, y: 542)); ribbon.line(to: NSPoint(x: 687, y: 515)); ribbon.close()
gold.setFill(); ribbon.fill()
image.unlockFocus()
let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
print(output)
