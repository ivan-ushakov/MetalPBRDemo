//
//  AppDelegate.swift
//  MetalPBRDemo
//
//  Created by  Ivan Ushakov on 18/04/2019.
//  Copyright © 2019  Ivan Ushakov. All rights reserved.
//

import Cocoa
import FBXSceneFramework

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var window: NSWindow!
    
    private let contentView = ContentView()
    
    private var displayLink: CVDisplayLink?
    private var renderer: Renderer?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        guard let parentView = window.contentView else { return }
        
        contentView.translatesAutoresizingMaskIntoConstraints = false
        parentView.addSubview(contentView)
        
        contentView.topAnchor.constraint(equalTo: parentView.topAnchor).isActive = true
        contentView.leftAnchor.constraint(equalTo: parentView.leftAnchor).isActive = true
        contentView.heightAnchor.constraint(equalTo: parentView.heightAnchor).isActive = true
        contentView.widthAnchor.constraint(equalTo: parentView.widthAnchor).isActive = true
        
        contentView.openCallback = { [weak self] in
            let panel = NSOpenPanel()
            
            panel.canChooseFiles = true
            panel.canChooseDirectories = false
            panel.allowsMultipleSelection = false
            
            panel.begin { response in
                if response == .OK {
                    guard let url = panel.urls.first else { return }
                    self?.loadScene(url)
                }
            }
        }
        
        setupDisplayLink()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        if let link = displayLink {
            CVDisplayLinkStop(link)
        }
    }

    private func setupDisplayLink() {
        CVDisplayLinkCreateWithActiveCGDisplays(&displayLink)
        
        if let link = displayLink {
            CVDisplayLinkSetOutputHandler(link) { [weak self] _, _, _, _, _ in
                self?.renderer?.draw()
                return kCVReturnSuccess
            }
        }
    }
    
    private func loadScene(_ url: URL) {
        guard let link = displayLink else { return }
        
        CVDisplayLinkStop(link)
        
        let scene = FBXScene()
        
        DispatchQueue.global().async {
            do {
                try scene.load(url.path)
                
                self.renderer = Renderer(layer: self.contentView.metalLayer, scene: scene)
                self.renderer?.setupScene()
                
                DispatchQueue.main.async {
                    CVDisplayLinkStart(link)
                }
            } catch {
                print("Error: \(error)")
            }
        }
    }
}

private class ContentView: NSView {
    
    var openCallback: (() -> Void)?
    
    let metalLayer = CAMetalLayer()
    
    private let button = NSButton(title: "Open", target: nil, action: nil)
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        layer = metalLayer
        wantsLayer = true
        
        button.translatesAutoresizingMaskIntoConstraints = false
        button.target = self
        button.action = #selector(handleButton)
        addSubview(button)
        
        setupLayout()
    }
    
    private func setupLayout() {
        button.topAnchor.constraint(equalTo: topAnchor, constant: 5.0).isActive = true
        button.leftAnchor.constraint(equalTo: leftAnchor, constant: 5.0).isActive = true
        button.widthAnchor.constraint(equalToConstant: 100).isActive = true
        button.heightAnchor.constraint(equalToConstant: 30.0).isActive = true
    }
    
    required init?(coder decoder: NSCoder) {
        fatalError()
    }
    
    @objc private func handleButton() {
        openCallback?()
    }
}
