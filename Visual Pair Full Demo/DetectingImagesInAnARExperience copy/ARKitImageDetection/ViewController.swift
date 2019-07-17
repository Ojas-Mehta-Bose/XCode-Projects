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
    var detectedSound = AVAudioPlayer()
    var videoIds = [String]();
    var pressedReset = false
    var isTrackInitialized = [false,false]
    var track:Int = 99
    
    var videoFiles = ["NFL","MLB", "Goodwood"]
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //Load audio files and prepare to play them | Load their corresponding ids to the server
        do{
            for i in 0...(videoFiles.count-1)
            {
                try audioPlayer.append(AVAudioPlayer(contentsOf: URL.init(fileURLWithPath: Bundle.main.path(forResource: videoFiles[i], ofType: "mp3")!)))
                videoIds.append(videoFiles[i]);
                audioPlayer[i].numberOfLoops = 99
                audioPlayer[i].prepareToPlay()
            }
            //Load the "image detected" sound
            try detectedSound = (AVAudioPlayer(contentsOf: URL.init(fileURLWithPath: Bundle.main.path(forResource: "detectedSound", ofType: "mp3")!)))
            detectedSound.prepareToPlay()
        }
        catch{
            print(error)
        }
        
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers, .allowAirPlay])
            print("Playback OK")
            try AVAudioSession.sharedInstance().setActive(true)
            print("Session is Active")
        } catch {
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
        configuration.isAutoFocusEnabled = true
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
            
            // Add the plane visualization to the scene.
            node.addChildNode(planeNode)
        }
        
        DispatchQueue.main.async {
            var previousTrack:Int = 99
            let imageName = referenceImage.name ?? ""
            self.statusViewController.cancelAllScheduledMessages()
            self.statusViewController.showMessage("Detected image “\(imageName)”")
            previousTrack = self.track
            
            if self.pressedReset{
                previousTrack = 99
                self.pressedReset = false
            }
            
//            //Load the corresponding track based on the name of the detected reference image
//            if imageName == "Goodwood"
//            {
//                self.track = 0
//            }
//
//            else{
//                self.track = 1
//            }
            
            switch imageName{
            case self.videoFiles[0]:
                self.track = 0
            case self.videoFiles[1]:
                self.track = 1
            case self.videoFiles[2]:
                self.track = 2
            default:
                print("Track not found")
            }
            //Switch track if a new image is detected, otherwise keep playing the audio files without retriving new positions
            if previousTrack != self.track
            {
                //HOME WIFI IP let urlPath: String = "http://192.168.86.89:8080/progress/\(self.videoIds[self.track])"
                
                let urlPath: String = "http://192.168.50.202:8080/progress/\(self.videoIds[self.track])"
                let url: NSURL = NSURL(string: urlPath)!
                let request1: NSURLRequest = NSURLRequest(url: url as URL)
                let queue:OperationQueue = OperationQueue()
                
                NSURLConnection.sendAsynchronousRequest(request1 as URLRequest, queue: queue, completionHandler:{ (response: URLResponse?, data: Data?, error: Error?) -> Void in
                    
                    do {
                        if let jsonResult = try JSONSerialization.jsonObject(with: data!, options: []) as? NSDictionary {
                            if let progress = jsonResult["progress"] as? Double {
                                // access individual value in dictionary
                                if (self.audioPlayer[self.track].volume == 0.0 || self.audioPlayer[self.track].isPlaying == false)
                                {
                                    self.detectedSound.play()
                                    self.audioPlayer[self.track].currentTime = progress;
                                    self.playAudio(track: self.track, previousTrack: previousTrack)
                                    self.detectedSound.currentTime = 0.0
                                }
                            }
                        }
                    } catch let error as NSError {
                        print(error.localizedDescription)
                    }
                })
            }
        }
    }
    func playAudio(track:Int, previousTrack:Int)
    {
        if previousTrack != 99
        {
        audioPlayer[previousTrack].setVolume(0.0, fadeDuration: 0)
        }
        audioPlayer[track].setVolume(1.0, fadeDuration: 0)
        audioPlayer[track].play()
    }
}
