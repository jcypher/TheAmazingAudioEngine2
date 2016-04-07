//
//  ViewController.swift
//  TAAESample
//
//  Created by Michael Tyson on 23/03/2016.
//  Copyright © 2016 A Tasty Pixel. All rights reserved.
//
// Strictly for educational purposes only. No part of TAAESample is to be distributed
// in any form other than as source code within the TAAE2 repository.

import UIKit

let PadWetDryRate              = 0.04
let PadWetDryUpdateInterval    = 0.005
let SpeedSliderRestoreRate     = 0.02
let SpeedSliderRestoreInterval = 0.01
let ShowCountInThreshold       = 0.5
let NormalRecordRotateSpeed    = 30.0
let SyncRecordRotateSpeed      = -3.0
let MeteringUpdateInterval     = 1.0/30.0

class ViewController: UIViewController {

    @IBOutlet var topBackground: UIView!
    @IBOutlet var bottomBackground: UIView!
    @IBOutlet var beatButton: PlayerButton!
    @IBOutlet var bassButton: PlayerButton!
    @IBOutlet var pianoButton: PlayerButton!
    @IBOutlet var sample1Button: UIButton!
    @IBOutlet var sample2Button: UIButton!
    @IBOutlet var sample3Button: UIButton!
    @IBOutlet var sweepButton: UIButton!
    @IBOutlet var hitButton: UIButton!
    @IBOutlet var speedSlider: UISlider!
    @IBOutlet var pad: UIImageView!
    @IBOutlet var stereoSweepButton: UIButton!
    @IBOutlet var recordButton: UIButton!
    @IBOutlet var playButton: UIButton!
    @IBOutlet var exportButton: UIButton!
    @IBOutlet var micButton: UIButton!
    
    var audio: AEAudioController?
    
    private var padWetDryTimer: NSTimer?
    private var padWetDryTarget = 0.0
    private var padWetDryValue = 0.0
    private var speedRestoreTimer: NSTimer?
    private var meteringTimer : NSTimer?
    private var meterLabel : UITextField!
    private var meterLabelHighestAvg : UITextField!
    private var meterLabelHighestPeak : UITextField!
    private let meterStringFormat = "avg:  %.3f // %.3f         peak: %.3f // %.3f"
    private let meterStringFormatHighest = "highest:  %.3f"
    private var maxAvg = 0.0
    private var maxPeak = 0.0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Setup visuals
        topBackground.backgroundColor = UIColor(patternImage: UIImage(named: "Upper Background")!)
        bottomBackground.backgroundColor = UIColor(patternImage: UIImage(named: "Lower Background")!)
        beatButton.image = UIImage(named: "Beat")
        bassButton.image = UIImage(named: "Bass")
        pianoButton.image = UIImage(named: "Piano")
        
        let trackImage = UIImage(named: "Speed Track")?
            .resizableImageWithCapInsets(UIEdgeInsets(top: 0.0, left: 2.0, bottom: 0.0, right: 2.0))
        speedSlider.setMaximumTrackImage(trackImage, forState: UIControlState.Normal)
        speedSlider.setMinimumTrackImage(trackImage, forState: UIControlState.Normal)
        speedSlider.setThumbImage(UIImage(named: "Speed Handle"), forState: UIControlState.Normal)
        speedSlider.maximumValue = 2.0
        speedSlider.minimumValue = 0.0
        speedSlider.value = 1.0
        
        if self.traitCollection.horizontalSizeClass != UIUserInterfaceSizeClass.Compact {
            speedSlider.transform = CGAffineTransformMakeRotation(CGFloat(-M_PI_2))
        }
        
        pad.image = UIImage(named: "Effect Bar")?
            .resizableImageWithCapInsets(UIEdgeInsets(top: 0, left: 63.0, bottom: 0, right: 62.0))
        
        // Add gesture recognizers
        pad.addGestureRecognizer(TriggerGestureRecognizer(target: self, action: #selector(effectPadPan)))
        hitButton.addGestureRecognizer(TriggerGestureRecognizer(target: self, action: #selector(hitTouch)))
        stereoSweepButton.addGestureRecognizer(TriggerGestureRecognizer(target: self, action: #selector(stereoSweepTouch)))
        
        // Enable/disable actions requiring prior recording
        updateFileActionsEnabled()
        
        meteringTimer = NSTimer.scheduledTimerWithTimeInterval(MeteringUpdateInterval, target: self,
                                                               selector: #selector(updateMeteringTimer), userInfo: nil, repeats: true)
        
        let sz = self.view.bounds.size
        meterLabel = UITextField(frame: CGRect(x: 0, y: 0, width: sz.width, height: 22));
        meterLabel.text = String(format: meterStringFormat, 0.0,0.0,0.0,0.0);
        meterLabel.center = CGPoint(x: sz.width/2, y: sz.height * 0.75);
        meterLabel.textAlignment = NSTextAlignment.Center
        meterLabel.font = UIFont(name: "Courier", size: 12);
        self.view.addSubview(meterLabel)
        
        meterLabelHighestAvg = UITextField(frame: CGRect(x: 0, y: 0, width: sz.width/3, height: 22));
        meterLabelHighestAvg.text = String(format: meterStringFormatHighest, 0.0);
        meterLabelHighestAvg.center = CGPoint(x: sz.width/3, y: sz.height * 0.75 - 22);
        meterLabelHighestAvg.textAlignment = NSTextAlignment.Center
        meterLabelHighestAvg.font = UIFont(name: "Courier", size: 12);
        self.view.addSubview(meterLabelHighestAvg)
        
        meterLabelHighestPeak = UITextField(frame: CGRect(x: 0, y: 0, width: sz.width/3, height: 22));
        meterLabelHighestPeak.text = String(format: meterStringFormatHighest, 0.0);
        meterLabelHighestPeak.center = CGPoint(x: sz.width * (2/3), y: sz.height * 0.75 - 22);
        meterLabelHighestPeak.textAlignment = NSTextAlignment.Center
        meterLabelHighestPeak.font = UIFont(name: "Courier", size: 12);
        self.view.addSubview(meterLabelHighestPeak)
    }
    
    @objc private func updateMeteringTimer() {
        if let audio = self.audio {
            let avgL = audio.metering.averagePowerForChannel(0)
            let avgR = audio.metering.averagePowerForChannel(1)
            let peakL = audio.metering.peakPowerForChannel(0)
            let peakR = audio.metering.peakPowerForChannel(1)
            meterLabel.text = String(format: meterStringFormat, avgL, avgR, peakL, peakR)
            maxAvg = max(maxAvg, max(avgL, avgR))
            maxPeak = max(maxPeak, max(peakL, peakR))
            meterLabelHighestAvg.text = String(format: meterStringFormatHighest, maxAvg);
            meterLabelHighestPeak.text = String(format: meterStringFormatHighest, maxPeak);
        }
    }
    
    override func prefersStatusBarHidden() -> Bool {
        // No status bar, please
        return true
    }
    
    override func willTransitionToTraitCollection(newCollection: UITraitCollection,
                                                  withTransitionCoordinator coordinator: UIViewControllerTransitionCoordinator) {
        // Slider is horizontal for small screens, vertical otherwise
        if newCollection.horizontalSizeClass == UIUserInterfaceSizeClass.Compact {
            speedSlider.transform = CGAffineTransformIdentity
        } else {
            speedSlider.transform = CGAffineTransformMakeRotation(CGFloat(-M_PI_2))
        }
    }
    
    // MARK: - Actions
    
    @IBAction func loopTapped(recognizer: UITapGestureRecognizer) {
        let sender = recognizer.view! as! PlayerButton
        if let player = associatedPlayerForView(sender) {
            if let audio = audio {
                if player.playing {
                    // Stop
                    player.stop()
                    sender.rotateSpeed = 0
                } else {
                    // Work out sync time
                    let syncTime = audio.nextSyncTimeForPlayer(player)
                    
                    // Start player
                    player.currentTime = 0
                    player.playAtTime(syncTime, beginBlock: {
                        // Show playing state
                        sender.rotateSpeed = self.currentRotateSpeed()
                    })
                    
                    let now = AECurrentTimeInHostTicks()
                    if syncTime > now && AESecondsFromHostTicks(syncTime - now) > ShowCountInThreshold {
                        // If there's a sync delay, spin the record slowly so we know something's happening
                        sender.rotateSpeed = SyncRecordRotateSpeed
                    } else {
                        // Show playing state
                        sender.rotateSpeed = self.currentRotateSpeed()
                    }
                }
            }
        }
    }
    
    @IBAction func sampleButtonTapped(sender: UIButton) {
        if let player = associatedPlayerForView(sender) {
            if let audio = audio {
                if player.playing {
                    // Stop, and reset button state
                    player.stop()
                    sender.imageView!.layer.removeAllAnimations()
                    sender.selected = false
                } else {
                    // Work out sync time
                    let syncTime = audio.nextSyncTimeForPlayer(player)
                    
                    // Start player
                    player.currentTime = 0
                    player.playAtTime(syncTime, beginBlock: {
                        // Set button state to playing
                        sender.imageView!.layer.removeAllAnimations()
                        sender.selected = true
                    })
                    
                    // Reset button state when we're done
                    player.completionBlock = { sender.selected = false }
                    
                    let now = AECurrentTimeInHostTicks()
                    if syncTime > now && AESecondsFromHostTicks(syncTime - now) > ShowCountInThreshold {
                        // If there's a sync delay, show a little animation so we know something's happening
                        let animation = CABasicAnimation(keyPath: "transform.translation.y")
                        animation.byValue = -8.0
                        animation.duration = audio.drums.duration / 32.0
                        animation.autoreverses = true
                        animation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseOut)
                        animation.repeatCount = Float.infinity
                        sender.imageView!.layer.addAnimation(animation, forKey: nil)
                    } else {
                        // Show playing state
                        sender.selected = true
                    }
                }
            }
        }
    }
    
    @IBAction func speedSliderDrag() {
        if speedRestoreTimer != nil {
            // Get rid of prior timer
            speedRestoreTimer?.invalidate()
            speedRestoreTimer = nil
        }
        
        // Set the playback rate based on the slider position
        updatePlaybackRate(Double(speedSlider!.value))
    }
    
    @IBAction func speedSliderEnd() {
        // Finished interacting with slider - set a timer to gradually bring the speed back to normal
        speedRestoreTimer = NSTimer.scheduledTimerWithTimeInterval(SpeedSliderRestoreInterval, target: self,
                                selector: #selector(speedSliderRestoreTimeout), userInfo: nil, repeats: true);
    }
    
    @IBAction func recordTap() {
        if let audio = audio {
            if audio.recording {
                // Stop recording
                audio.stopRecordingAtTime(0, completionBlock: { 
                    self.recordButton.selected = false
                    self.recordButton.layer.removeAllAnimations()
                    self.updateFileActionsEnabled()
                });
            } else {
                do {
                    // Start recording
                    try audio.beginRecordingAtTime(0)
                    
                    // Add a little animation to show recording is active
                    recordButton.selected = true
                    let animation = CABasicAnimation(keyPath: "transform.rotation.z")
                    animation.byValue = 2.0*M_PI
                    animation.duration = 2.0
                    animation.repeatCount = Float.infinity
                    recordButton.layer.addAnimation(animation, forKey: nil)
                } catch _ {
                    // D'oh, something went wrong. Guess we can't record.
                    self.recordButton.enabled = false
                    self.recordButton.layer.removeAllAnimations()
                }
            }
        }
    }
    
    @IBAction func playTap() {
        if let audio = audio {
            if audio.playingRecording {
                // Stop the playback
                audio.stopPlayingRecording()
                self.playButton.selected = false
            } else {
                // Start playback
                self.playButton.selected = true
                audio.playRecordingWithCompletionBlock({ 
                    self.playButton.selected = false
                })
            }
        }
    }
    
    @IBAction func exportTap() {
        if let audio = audio {
            // Show the share controller
            let controller = UIActivityViewController(activityItems: [audio.recordingPath], applicationActivities: nil)
            controller.completionWithItemsHandler = { activity, success, items, error in
                self.dismissViewControllerAnimated(true, completion: nil)
            }
            
            if UIDevice.currentDevice().userInterfaceIdiom == UIUserInterfaceIdiom.Pad {
                controller.modalPresentationStyle = UIModalPresentationStyle.Popover
                controller.popoverPresentationController?.sourceView = exportButton
            }
            
            self.presentViewController(controller, animated: true, completion: nil)
        }
    }
    
    @IBAction func micTap() {
        if let audio = audio {
            // Toggle mic
            audio.inputEnabled = !audio.inputEnabled
            micButton.selected = audio.inputEnabled
        }
    }
    
    @objc private func hitTouch(sender: TriggerGestureRecognizer) {
        if sender.state == UIGestureRecognizerState.Began {
            if let audio = audio {
                // Begin playing the hit sample
                audio.hit.regionDuration = audio.drums.regionDuration / 32
                audio.hit.loop = true
                if !audio.hit.playing {
                    audio.hit.currentTime = 0
                    audio.hit.playAtTime(audio.nextSyncTimeForPlayer(audio.hit))
                }
                hitButton.selected = true
                
                // Stop the drum loop
                if audio.drums.playing {
                    audio.drums.stop()
                }
                beatButton.rotateSpeed = -60.0 / audio.hit.regionDuration
            }
        } else if ( sender.state == UIGestureRecognizerState.Changed ) {
            if let audio = audio {
                // Adjust the hit cycle length, based on 3D Touch pressure, for a beat repeat-like feature
                audio.hit.regionDuration = audio.drums.regionDuration / (sender.pressure >= 1.0 ? 64 : 32)
            }
        } else if sender.state == UIGestureRecognizerState.Ended || sender.state == UIGestureRecognizerState.Cancelled {
            if let audio = audio {
                // Start the drums playing again
                if !audio.drums.playing {
                    audio.drums.currentTime = 0
                    audio.drums.playAtTime(audio.nextSyncTimeForPlayer(audio.drums))
                    beatButton.rotateSpeed = currentRotateSpeed()
                }
                
                // Stop the hit sample
                audio.hit.completionBlock = {
                    self.hitButton.selected = false
                }
                audio.hit.loop = false
            }
        }
        
    }
    
    @objc private func effectPadPan(sender: TriggerGestureRecognizer) {
        if sender.state == UIGestureRecognizerState.Began {
            // Start transitioning to 100% wet
            padWetDryTarget = 1.0
            if padWetDryTimer == nil {
                padWetDryTimer = NSTimer.scheduledTimerWithTimeInterval(PadWetDryUpdateInterval, target: self,
                                                                       selector: #selector(padWetDryTimeout),
                                                                       userInfo: nil, repeats: true)
            }
        }
        if sender.state == UIGestureRecognizerState.Began || sender.state == UIGestureRecognizerState.Changed {
            // Update effect
            let location = sender.locationInView(sender.view!)
            let bounds = sender.view!.bounds
            let x = Double(location.x / bounds.size.width);
            audio?.bandpassCenterFrequency = min(1.0, max(0.001, x*x*x*x)) * 16000.0
        } else {
            // Start transitioning to 0% wet
            padWetDryTarget = 0.0
            if padWetDryTimer == nil {
                padWetDryTimer = NSTimer.scheduledTimerWithTimeInterval(PadWetDryUpdateInterval, target: self,
                                                                        selector: #selector(padWetDryTimeout),
                                                                        userInfo: nil, repeats: true)
            }
        }
    }
    
    @objc private func stereoSweepTouch(sender: TriggerGestureRecognizer) {
        if let audio = audio {
            if sender.state == UIGestureRecognizerState.Began || sender.state == UIGestureRecognizerState.Changed {
                audio.balanceSweepRate = (sender.pressure >= 1.0 ? 0.5 : 2.0);
            } else {
                audio.balanceSweepRate = 0.0
            }
        }
    }
}

// MARK: - Helpers

private extension ViewController {
    
    // Get player for a given UI element
    private func associatedPlayerForView(view: UIView) -> AEAudioFilePlayerModule? {
        if let audio = audio {
            return view == beatButton ? audio.drums :
                    view == bassButton ? audio.bass :
                    view == pianoButton ? audio.piano :
                    view == sample1Button ? audio.sample1 :
                    view == sample2Button ? audio.sample2 :
                    view == sample3Button ? audio.sample3 :
                    view == hitButton ? audio.hit :
                    audio.sweep;
        } else {
            return nil
        }
    }
    
    // Respond to a change in playback rate
    private func updatePlaybackRate(rate: Double) {
        if let audio = audio {
            audio.varispeed.playbackRate = rate
            let rotateSpeed = self.currentRotateSpeed()
            if audio.bass.playing {
                bassButton.rotateSpeed = rotateSpeed
            }
            if audio.drums.playing {
                beatButton.rotateSpeed = rotateSpeed
            }
            if audio.piano.playing {
                pianoButton.rotateSpeed = rotateSpeed
            }
        }
    }
    
    // Enable/disable recording-based actions, depending on whether a recording exists
    private func updateFileActionsEnabled() {
        if let audio = audio {
            let fileManager = NSFileManager.defaultManager()
            exportButton.enabled = fileManager.fileExistsAtPath(audio.recordingPath.path!)
            playButton.enabled = exportButton.enabled;
        }
    }
    
    // Calculate rotation animation speed
    private func currentRotateSpeed() -> Double {
        return audio != nil ? audio!.varispeed.playbackRate * NormalRecordRotateSpeed : 1.0
    }
    
    // Transition between wet and dry for effect
    @objc private func padWetDryTimeout() {
        if padWetDryTarget > padWetDryValue {
            padWetDryValue = min(padWetDryTarget, padWetDryValue + PadWetDryRate)
        } else {
            padWetDryValue = max(padWetDryTarget, padWetDryValue - PadWetDryRate)
        }
        audio?.bandpassWetDry = padWetDryValue
        if padWetDryValue == padWetDryTarget {
            padWetDryTimer?.invalidate()
            padWetDryTimer = nil
        }
    }
    
    // Transition speed back to normal
    @objc private func speedSliderRestoreTimeout() {
        if let speedSlider = speedSlider {
            if speedSlider.value > 1.0 {
                speedSlider.value = max(1.0, speedSlider.value - Float(SpeedSliderRestoreRate))
            } else {
                speedSlider.value = min(1.0, speedSlider.value + Float(SpeedSliderRestoreRate))
            }
            
            updatePlaybackRate(Double(speedSlider.value))
            
            if speedSlider.value == 1.0 {
                speedRestoreTimer?.invalidate()
                speedRestoreTimer = nil
            }
        }
    }
}

