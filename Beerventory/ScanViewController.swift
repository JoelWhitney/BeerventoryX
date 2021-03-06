//
//  ScanViewController.swift
//  Beerventory
//
//  Created by Joel Whitney on 4/20/17.
//  Copyright © 2017 Joel Whitney. All rights reserved.
//
import UIKit
import AVFoundation
import SwiftyJSON
import AWSDynamoDB
import AWSMobileClient
import AWSCore

class ScanViewController: UIViewController {
    // MARK: - variables/constants
    var codeFont: UIFont?
    var captureSession: AVCaptureSession?
    var capturePreviewLayer: AVCaptureVideoPreviewLayer?
    var qrCodeFrameView: UIView?
    var prevCodeStringvalue: String = ""
    var mainBeerStore = [AWSBeer]()
    var scanResultsBeers = [Beer]()
    var currentAWSBeer: AWSBeer!
    var currentBeer: Beer!
    var currentBeerIndexPath: IndexPath!
    var alertTextField = UITextField()
    weak var actionToEnable : UIAlertAction?
    let supportedCodeTypes = [AVMetadataObject.ObjectType.upce,
                              AVMetadataObject.ObjectType.code39,
                              AVMetadataObject.ObjectType.code39Mod43,
                              AVMetadataObject.ObjectType.code93,
                              AVMetadataObject.ObjectType.code128,
                              AVMetadataObject.ObjectType.ean8,
                              AVMetadataObject.ObjectType.ean13,
                              AVMetadataObject.ObjectType.aztec,
                              AVMetadataObject.ObjectType.pdf417,
                              AVMetadataObject.ObjectType.qr,
                              AVMetadataObject.ObjectType.ean8,
                              AVMetadataObject.ObjectType.aztec,
                              AVMetadataObject.ObjectType.itf14,
                              AVMetadataObject.ObjectType.code128,
                              AVMetadataObject.ObjectType.dataMatrix,
                              AVMetadataObject.ObjectType.interleaved2of5]
    var pickerQuantity = "1"
    var upc_code = ""
    var scanResultsFound: (([Beer]) -> Void)?
    var captureDevice: AVCaptureDevice!
    
    // MARK: Outlets
    //@IBOutlet var tableView: UITableView!
    @IBOutlet var activitySpinnerView: UIView!
    @IBOutlet var flashButton: UIButton!
    
    // MARK: Actions
    
    // MARK: Initializers
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    //MARK: View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        self.capturePreviewFrame()
        self.captureDetectionFrame()
        self.refreshScanControllerState()
        flashButton.addTarget(self, action: #selector(updateTorch), for: UIControlEvents.touchDown)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        toggleTorch(on: false)
        self.refreshScanControllerState()
    }
    
    @objc func updateTorch() {
        guard let device = AVCaptureDevice.default(for: AVMediaType.video) else { return }
        if device.isTorchActive {
            toggleTorch(on: false)
            flashButton.setImage( #imageLiteral(resourceName: "flashOn"), for: .normal)
        } else {
            toggleTorch(on: true)
            flashButton.setImage( #imageLiteral(resourceName: "flashOff"), for: .normal)
        }
    }
    
    func toggleTorch(on: Bool) {
        guard let device = AVCaptureDevice.default(for: AVMediaType.video) else { return }
        if device.hasTorch {
            do {
                try device.lockForConfiguration()
                if on == true {
                    device.torchMode = .on
                } else {
                    device.torchMode = .off
                }
                device.unlockForConfiguration()
            } catch {
                print("Torch could not be used")
            }
        } else {
            print("Torch is not available")
        }
    }
    
    func capturePreviewFrame() {
        let screenSize = UIScreen.main.bounds
        let screenWidth = screenSize.width
        let screenHeight = screenSize.height
        let captureRectWidth = CGFloat(200.0)
        let captureRectHeight = CGFloat(200.0)
        let cgCaptureRect = CGRect(x: (screenWidth / 2 - captureRectWidth / 2),
                                   y: (screenHeight / 4 - captureRectHeight / 2),
                                   width: captureRectWidth,
                                   height: captureRectHeight)
        let captureWindowView = UIView()
        captureWindowView.frame = cgCaptureRect
        
        captureDevice = AVCaptureDevice.default(for: AVMediaType.video)
        do {
            // initialize the captureSession object and add input
            let input = try AVCaptureDeviceInput(device: captureDevice)
            captureSession = AVCaptureSession()
            captureSession?.addInput(input)
            // initialize a output object to capture session
            let results = AVCaptureMetadataOutput()
            captureSession?.addOutput(results)
            results.metadataObjectTypes = supportedCodeTypes
            results.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            
            
            // initialize the video preview layer and add to view as sublayer
            capturePreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession!)
            capturePreviewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
            capturePreviewLayer?.frame = view.layer.bounds
            view.layer.addSublayer(capturePreviewLayer!)
            view.addSubview(flashButton)
            // start capture session and move labels to front
            captureSession?.startRunning()
            
            
            // set capture area
            let captureRect = capturePreviewLayer?.metadataOutputRectConverted(fromLayerRect: cgCaptureRect)
            results.rectOfInterest = captureRect!
            captureWindowView.layer.backgroundColor = UIColor.clear.cgColor
            captureWindowView.layer.borderColor = UIColor.lightGray.cgColor
            captureWindowView.layer.borderWidth = 1
            view.addSubview(captureWindowView)
            view.bringSubview(toFront: captureWindowView)
            
            
        } catch {
            // print errors thrown by AVCaptureDeviceInput
            print("Error setting up preview frame: \(error)")
            return
        }
    }
    func captureDetectionFrame() {
        qrCodeFrameView = UIView()
        if let qrCodeFrameView = qrCodeFrameView {
            qrCodeFrameView.layer.borderColor = UIColor.white.cgColor
            qrCodeFrameView.layer.borderWidth = 2
            view.addSubview(qrCodeFrameView)
            view.bringSubview(toFront: qrCodeFrameView)
        }
    }
    
    //MARK: Imperative methods
    func addProgressSubview(){
        let progressHUD = SearchProgress(text: "Searching..")
        self.view.addSubview(progressHUD)
    }
    func removeProgressSubview(){
        DispatchQueue.main.async {
            for subview in self.view.subviews {
                if subview is SearchProgress {
                    subview.removeFromSuperview()
                }
            }
        }
    }
    func cancelSelection(sender: UIButton){
        print("Cancel");
        self.dismiss(animated: true, completion: nil);
        // We dismiss the alert. Here you can add your additional code to execute when cancel is pressed
    }
    func searchBeerBarcodes(upc_code: String, onCompletion: @escaping () -> Void) {
        scanResultsBeers = []
        BrewerydbAPI.sharedInstance.search_barcode(barCode: upc_code, onCompletion: { (json: JSON) in
            guard let results = json["data"].array else {
                self.removeProgressSubview()
                print("   No Beers")
                let alertController = UIAlertController(title: "Error", message: "The barcode is not in the database, consider adding it.", preferredStyle: UIAlertControllerStyle.alert)
                alertController.addAction(UIAlertAction(title: "Dismiss", style: UIAlertActionStyle.default) { action in
                    self.refreshScanControllerState()
                })
                let add = UIAlertAction(title: "Add", style: UIAlertActionStyle.default) { action in
                    self.performSegue(withIdentifier: "AddBeerFromUPC", sender: self)
                }
                alertController.addAction(add)
                self.present(alertController, animated: true, completion: nil)
                return
            }
            self.scanResultsBeers = results.map { Beer(beerJSON: $0) }
            onCompletion()
        })
    }
    func updateBreweryDetails(onCompletion: @escaping () -> Void) {
        BrewerydbAPI.sharedInstance.get_beers_breweries(beers: self.scanResultsBeers, onCompletion: { (updatedBeers: [Beer]) in
            print(updatedBeers)
            self.scanResultsBeers = updatedBeers
            onCompletion()
        })
    }
    func refreshScanControllerState() {
        captureSession?.startRunning()
        self.navigationItem.leftBarButtonItem?.isEnabled = false
        qrCodeFrameView?.frame = CGRect.zero
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        let screenSize = UIScreen.main.bounds.size
        if let touchPoint = touches.first {
            let x = touchPoint.location(in: self.view).y / screenSize.height
            let y = 1.0 - touchPoint.location(in: self.view).x / screenSize.width
            let focusPoint = CGPoint(x: x, y: y)
            
            if let device = captureDevice {
                do {
                    try device.lockForConfiguration()
                    
                    device.focusPointOfInterest = focusPoint
                    //device.focusMode = .continuousAutoFocus
                    device.focusMode = .autoFocus
                    //device.focusMode = .locked
                    device.exposurePointOfInterest = focusPoint
                    device.exposureMode = AVCaptureDevice.ExposureMode.continuousAutoExposure
                    device.unlockForConfiguration()
                }
                catch {
                    // just ignore
                }
            }
        }
    }
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let destinationNavigationController = segue.destination as? UINavigationController {
            let targetController = destinationNavigationController.topViewController as? AddBeerViewController
            print("set barcode")
            targetController!.beer.upc_code = self.upc_code
        }
    }
}

// MARK: - UIPicker delegate
extension ScanViewController: UIPickerViewDelegate {
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        pickerQuantity = String(row + 1)
    }
}

// MARK: - UIPicker delegate
extension ScanViewController: UIPickerViewDataSource {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return 30
    }
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        print(row)
        return String(row + 1)
    }
}

//MARK: AVCapture delegate
extension ScanViewController: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput results: [AVMetadataObject], from connection: AVCaptureConnection) {
        print("thing captured")
        if results == nil || results.count == 0 { // handle empty results
            qrCodeFrameView?.frame = CGRect.zero
            // TODO: - Add no results prompt
            return
        } else {
            let metadataObj = results[0] as! AVMetadataMachineReadableCodeObject
            if supportedCodeTypes.contains(metadataObj.type) { // handle output type
                let barCodeObject = capturePreviewLayer?.transformedMetadataObject(for: metadataObj)
                qrCodeFrameView?.frame = barCodeObject!.bounds
                if !(metadataObj.stringValue?.isEmpty)! { // handle result contents
                    captureSession?.stopRunning()
                    addProgressSubview()
                    print(metadataObj.stringValue)
                    upc_code = metadataObj.stringValue!
                    searchBeerBarcodes(upc_code: upc_code, onCompletion: {
                        self.updateBreweryDetails(onCompletion: { // STEP 2 HERE
                            DispatchQueue.main.async(execute: {
                                print("push results to searchResultsController")
                                self.removeProgressSubview()
                                self.refreshScanControllerState()
                                print(self.scanResultsBeers)
                                self.scanResultsFound?(self.scanResultsBeers)
                            })
                        })
                    })
                } else {
                    // TODO: - Add no results prompt
                }
                return
            }
        }
    }
}
