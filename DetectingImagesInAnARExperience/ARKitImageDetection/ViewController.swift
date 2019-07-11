/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Main view controller for the AR experience.
*/

import ARKit
import SceneKit
import UIKit
import AVFoundation

@available(iOS 12.0, *)
class ViewController: UIViewController, ARSCNViewDelegate {
    
    @IBOutlet var sceneView: ARSCNView!
    
    @IBOutlet weak var blurView: UIVisualEffectView!
    
    /// The view controller that displays the status and "restart experience" UI.
    lazy var statusViewController: StatusViewController = {
        return children.lazy.compactMap({ $0 as? StatusViewController }).first!
    }()
    
    /// A serial queue for thread safety when modifying the SceneKit node graph.
    let updateQueue = DispatchQueue(label: Bundle.main.bundleIdentifier! +
        ".serialSceneKitQueue")
    
    /// Convenience accessor for the session owned by ARSCNView.
    var session: ARSession {
        return sceneView.session
    }
    
    // MARK: - View Controller Life Cycle
    
    var audioPlayer = [AVAudioPlayer]()
    var videoIds = [String]();
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        do{
            try audioPlayer.append(AVAudioPlayer(contentsOf: URL.init(fileURLWithPath: Bundle.main.path(forResource: "soccer", ofType: "mp3")!)))
            
            videoIds.append("soccer");
            try audioPlayer.append(AVAudioPlayer(contentsOf: URL.init(fileURLWithPath: Bundle.main.path(forResource: "sports-desk", ofType: "mp3")!)))
            
            videoIds.append("sports-desk");
            for i in 0...1
            {
                audioPlayer[i].prepareToPlay()
            }
        }
        catch{
            print(error)
        }
        
        sceneView.delegate = self
        sceneView.session.delegate = self

        // Hook up status view controller callback(s).
        statusViewController.restartExperienceHandler = { [unowned self] in
            self.restartExperience()
        }
    }

	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		
		// Prevent the screen from being dimmed to avoid interuppting the AR experience.
		UIApplication.shared.isIdleTimerDisabled = true

        // Start the AR experience
        resetTracking()
	}
	
	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)

        session.pause()
	}

    // MARK: - Session management (Image detection setup)
    
    /// Prevents restarting the session while a restart is in progress.
    var isRestartAvailable = true

    /// Creates a new AR configuration to run on the `session`.
    /// - Tag: ARReferenceImage-Loading
	func resetTracking() {
        
        guard let referenceImages = ARReferenceImage.referenceImages(inGroupNamed: "AR Resources", bundle: nil) else {
            fatalError("Missing expected asset catalog resources.")
        }
        
        let configuration = ARImageTrackingConfiguration()
        configuration.trackingImages = referenceImages
        session.run(configuration, options: [.resetTracking, .removeExistingAnchors])

        statusViewController.scheduleMessage("Look around to detect images", inSeconds: 7.5, messageType: .contentPlacement)
    }

    // MARK: - ARSCNViewDelegate (Image detection results)
    /// - Tag: ARImageAnchor-Visualizing}
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let imageAnchor = anchor as? ARImageAnchor else { return }
        let referenceImage = imageAnchor.referenceImage
        updateQueue.async {
            
            // Create a plane to visualize the initial position of the detected image.
            let plane = SCNPlane(width: referenceImage.physicalSize.width,
                                 height: referenceImage.physicalSize.height)
            let planeNode = SCNNode(geometry: plane)
            planeNode.opacity = 0.25
            
            /*
             `SCNPlane` is vertically oriented in its local coordinate space, but
             `ARImageAnchor` assumes the image is horizontal in its local space, so
             rotate the plane to match.
             */
            planeNode.eulerAngles.x = -.pi / 2
            
            /*
             Image anchors are not tracked after initial detection, so create an
             animation that limits the duration for which the plane visualization appears.
             */
            //planeNode.runAction(self.imageHighlightAction)

            // Add the plane visualization to the scene.
            node.addChildNode(planeNode)

          //  self.resetTracking()
        }

        DispatchQueue.main.async {
            var track:Int = 99
            let imageName = referenceImage.name ?? ""
            self.statusViewController.cancelAllScheduledMessages()
            self.statusViewController.showMessage("Detected image “\(imageName)”")
            
            switch imageName{
            case "demo0":
                track = 0
            case "demo1":
                track = 1
            default:
                print("Track not detected")
            }//END SWITCH
            if track < 99
            {
                //self.playAudio(track: track)
                let urlPath: String = "http://192.168.50.237:8080/progress/\(self.videoIds[track])"
                let url: NSURL = NSURL(string: urlPath)!
                let request1: NSURLRequest = NSURLRequest(url: url as URL)
                let queue:OperationQueue = OperationQueue()
                
                NSURLConnection.sendAsynchronousRequest(request1 as URLRequest, queue: queue, completionHandler:{ (response: URLResponse?, data: Data?, error: Error?) -> Void in
                    
                    do {
                        if let jsonResult = try JSONSerialization.jsonObject(with: data!, options: []) as? NSDictionary {
                            
                            if let progress = jsonResult["progress"] as? Double {
                                // access individual value in dictionary
                                print(progress)
                                self.audioPlayer[track].currentTime = progress;
                                self.playAudio(track: track)
                            }
                        }
                    } catch let error as NSError {
                        print(error.localizedDescription)
                    }
                })
            }
        }
    }

    var imageHighlightAction: SCNAction {
        return .sequence([
            .wait(duration: 100), //How long to show rectangle
            .fadeOpacity(to: 0.85, duration: 0.25),
            .fadeOpacity(to: 0.15, duration: 0.25),
            .fadeOpacity(to: 0.85, duration: 0.25),
            .fadeOut(duration: 0.5),
            .removeFromParentNode()
        ])
    }
    func playAudio(track:Int)
    {
        for i in 0...1 {
            if(track != i)
            {
                audioPlayer[i].setVolume(0.0, fadeDuration: 0)
                //print("audio: " + String(i) + " " + String(audioPlayer[i].currentTime))
            }
        }
        
        audioPlayer[track].setVolume(1.0, fadeDuration: 0)
        audioPlayer[track].play()
        
    }
}
