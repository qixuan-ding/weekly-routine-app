import AppKit

// Code-drawn icon: blue skies, a cloud, and one small step completed.
let destination = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "macos/Runner/Assets.xcassets/AppIcon.appiconset"
for size in [16, 32, 64, 128, 256, 512, 1024] {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let transform = NSAffineTransform()
    transform.scale(by: CGFloat(size) / 1024)
    transform.concat()
    let tile = NSBezierPath(roundedRect: NSRect(x: 70, y: 70, width: 884, height: 884), xRadius: 192, yRadius: 192)
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.18)
    shadow.shadowOffset = NSSize(width: 0, height: -12)
    shadow.shadowBlurRadius = 22
    shadow.set()
    NSGradient(starting: NSColor(calibratedRed: 0.31, green: 0.56, blue: 0.94, alpha: 1),
        ending: NSColor(calibratedRed: 0.23, green: 0.35, blue: 0.76, alpha: 1))!.draw(in: tile, angle: -70)
    shadow.shadowColor = .clear
    shadow.set()
    let cloud = NSBezierPath()
    cloud.move(to: NSPoint(x: 338, y: 365))
    cloud.curve(to: NSPoint(x: 314, y: 620), controlPoint1: NSPoint(x: 172, y: 365), controlPoint2: NSPoint(x: 166, y: 597))
    cloud.curve(to: NSPoint(x: 648, y: 644), controlPoint1: NSPoint(x: 337, y: 819), controlPoint2: NSPoint(x: 604, y: 830))
    cloud.curve(to: NSPoint(x: 695, y: 365), controlPoint1: NSPoint(x: 840, y: 677), controlPoint2: NSPoint(x: 859, y: 365))
    cloud.line(to: NSPoint(x: 338, y: 365))
    cloud.lineWidth = 45
    cloud.lineJoinStyle = .round
    cloud.lineCapStyle = .round
    NSColor.white.setStroke()
    cloud.stroke()
    let check = NSBezierPath()
    check.move(to: NSPoint(x: 428, y: 535))
    check.line(to: NSPoint(x: 490, y: 475))
    check.line(to: NSPoint(x: 599, y: 589))
    check.lineWidth = 42
    check.lineCapStyle = .round
    check.lineJoinStyle = .round
    check.stroke()
    NSGraphicsContext.restoreGraphicsState()
    try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(destination)/app_icon_\(size).png"))
}
