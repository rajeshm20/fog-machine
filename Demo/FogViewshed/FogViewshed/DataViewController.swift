//
//  DataViewController.swift
//  FogMachineSearch
//
//  Created by Ram Subramaniam on 1/25/16.
//  Copyright © 2016 NGA. All rights reserved.
//

import UIKit
import MapKit

class DataViewController: UIViewController, UIScrollViewDelegate, UITableViewDelegate, UITableViewDataSource,
MKMapViewDelegate, UIGestureRecognizerDelegate, CLLocationManagerDelegate, HgtDownloadMgrDelegate {
    
    struct hgtLatLngPrefix {
        var latitudePrefix: String
        var longitudePrefix: String
    }
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var gpsButton: UIButton!
    
    var hgtCoordinate:CLLocationCoordinate2D!
    var pickerData: [String] = [String]()
    var hgtFilename:String = String()
    var locationManager: CLLocationManager!
    var isInitialAuthorizationCheck = false
    let zoomLevelDegrees:Double = 5
    let arrowPressedImg = UIImage(named: "ArrowPressed")! as UIImage
    let arrowImg = UIImage(named: "Arrow")! as UIImage
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.tableView.registerClass(UITableViewCell.self, forCellReuseIdentifier: "cell")
        self.tableView.backgroundColor = UIColor.clearColor();
        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.mapView.delegate = self
        self.getHgtFiles()
        
        let lpgr = UILongPressGestureRecognizer(target: self, action:"handleLongPress:")
        lpgr.minimumPressDuration = 0.5
        lpgr.delaysTouchesBegan = true
        lpgr.delegate = self
        self.mapView.addGestureRecognizer(lpgr)
        
        if (self.locationManager == nil) {
            self.locationManager = CLLocationManager()
            self.locationManager.desiredAccuracy = kCLLocationAccuracyBest
            self.locationManager.delegate = self
        }
        let status = CLLocationManager.authorizationStatus()
        if (status == .NotDetermined || status == .Denied || status == .Restricted)  {
            // present an alert indicating location authorization required
            // and offer to take the user to Settings for the app via
            self.locationManager.requestWhenInUseAuthorization()
            self.mapView.tintColor = UIColor.blueColor()
        }
        gpsButton.setImage(arrowPressedImg, forState: UIControlState.Normal)
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        // remove the rectangle boundary on the map for the dowloaded data
        self.removeAllFromMap()
        // find out if there is a way to remove a selected map overlay..
        // navigate the data folder and redraw the overlays from the data files..
        self.getHgtFiles()
        // refresh the table with the latest array data
        self.refresh()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func focusToCurrentLocation(sender: AnyObject) {
        gpsButton.setImage(arrowPressedImg, forState: UIControlState.Normal)
        
        if let coordinate = mapView.userLocation.location?.coordinate {
            // Get the span that the mapView is set to by the user.
            let span = self.mapView.region.span
            // Now setup the region based on the lat/lon and retain the span that already exists.
            let region = MKCoordinateRegion(center: coordinate, span: span)
            //Center the view with some animation.
            self.mapView.setRegion(region, animated: true)
        }
    }
    
    func mapView(mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
        let view = self.mapView.subviews[0]
        //  Look through gesture recognizers to determine whether this region change is from user interaction
        if let gestureRecognizers = view.gestureRecognizers {
            for recognizer in gestureRecognizers {
                if( recognizer.state == UIGestureRecognizerState.Began || recognizer.state == UIGestureRecognizerState.Ended ) {
                    gpsButton.setImage(arrowImg, forState: UIControlState.Normal)
                }
            }
        }
    }
    
    // MARK: - Location Delegate Methods
    func locationManager(manager: CLLocationManager, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
        if (status == .AuthorizedWhenInUse || status == .AuthorizedAlways) {
            self.locationManager.startUpdatingLocation()
            self.isInitialAuthorizationCheck = true
            self.mapView.showsUserLocation = true
        }
    }
    
    func locationManager(manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if (self.isInitialAuthorizationCheck) {
            //self.pinDownloadeAnnotation(locations.last!)
            let title = "Download Current Location?"
            self.pinAnnotation(title , subtitle: "", coordinate: locations.last!.coordinate)
            self.locationManager.stopUpdatingLocation()
        }
    }
    
    func locationManager(manager: CLLocationManager, didFailWithError error: NSError) {
        print("Error: " + error.localizedDescription)
    }
   
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let dataCell = tableView.dequeueReusableCellWithIdentifier("dataCell", forIndexPath: indexPath)
        dataCell.textLabel!.text = self.pickerData[indexPath.row]
        return dataCell
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.pickerData.count
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let currentCell = tableView.cellForRowAtIndexPath(indexPath)! as UITableViewCell
        let selectedHGTFile = currentCell.textLabel!.text!
        if let aTmpStr:String = selectedHGTFile {
            if !aTmpStr.isEmpty {
                self.hgtFilename = aTmpStr[aTmpStr.startIndex.advancedBy(0)...aTmpStr.startIndex.advancedBy(6)]
                self.hgtCoordinate = parseCoordinate(hgtFilename)
                let coordinate = CLLocationCoordinate2D(latitude: self.hgtCoordinate.latitude + 0.5, longitude: self.hgtCoordinate.longitude + 0.5)
                
                let title = "Delete " + hgtFilename + ".hgt" + "?"
                self.pinAnnotation(title , subtitle: "", coordinate: coordinate)
            }
        }
    }
    
    func refresh() {
        self.tableView?.reloadData()
    }
    
    func pinAnnotation(title: String, subtitle: String, coordinate: CLLocationCoordinate2D) {
        // remove all the annotations on the map
        self.mapView.removeAnnotations(mapView.annotations)
        
        // Get the span that the mapView is set to by the user.
        let span = self.mapView.region.span
        // Now setup the region based on the lat/lon and retain the span that already exists.
        let region = MKCoordinateRegion(center: coordinate, span: span)
        //Center the view with some animation.
        self.mapView.setRegion(region, animated: true)
        
        let pointAnnotation:MKPointAnnotation = MKPointAnnotation()
        pointAnnotation.coordinate = coordinate
        pointAnnotation.title = title
        pointAnnotation.subtitle =  "\(String(format:"%.4f", coordinate.latitude)) \(String(format:"%.4f", coordinate.longitude))"
        self.mapView.addAnnotation(pointAnnotation)
    }
    
    func getHgtFiles() {
        do {
            self.pickerData.removeAll()
            let fm = NSFileManager.defaultManager()
            let documentDirPath:NSURL =  try fm.URLForDirectory(.DocumentDirectory, inDomain: .UserDomainMask, appropriateForURL: nil, create: true)
            let docDirItems = try! fm.contentsOfDirectoryAtPath(documentDirPath.path!)
            for docDirItem in docDirItems {
                if docDirItem.hasSuffix(".hgt") {
                    self.manageHgtDataArray(docDirItem, arrayAction: "add")
                    self.addRectBoundry(self.hgtCoordinate.latitude, longitude: self.hgtCoordinate.longitude)
                }
            }
        } catch let error as NSError  {
            print("Couldn't find the HGT files: \(error.localizedDescription)")
        }
    }
    
    func manageHgtDataArray(docDirItem: String, arrayAction: String) {
        let hgFileName = NSURL(fileURLWithPath: docDirItem).URLByDeletingPathExtension?.lastPathComponent
        self.hgtCoordinate = self.parseCoordinate(hgFileName!)
        let tableCellItem = "\(docDirItem) (Lat \(self.hgtCoordinate.latitude) Lng \(self.hgtCoordinate.longitude))"
        
        if (!self.pickerData.contains(tableCellItem) && arrayAction == "add") {
            self.pickerData.append(tableCellItem)
        }
        if (self.pickerData.contains(tableCellItem) && arrayAction == "remove") {
            let index = self.pickerData.indexOf(tableCellItem)
            self.pickerData.removeAtIndex(index!)
        }
    }
    
    func parseCoordinate(filename : String) -> CLLocationCoordinate2D {
        let northSouth = filename.substringWithRange(Range<String.Index>(start: filename.startIndex,end: filename.startIndex.advancedBy(1)))
        let latitudeValue = filename.substringWithRange(Range<String.Index>(start: filename.startIndex.advancedBy(1),end: filename.startIndex.advancedBy(3)))
        let westEast = filename.substringWithRange(Range<String.Index>(start: filename.startIndex.advancedBy(3),end: filename.startIndex.advancedBy(4)))
        let longitudeValue = filename.substringWithRange(Range<String.Index>(start: filename.startIndex.advancedBy(4),end: filename.endIndex))
        
        var latitude:Double = Double(latitudeValue)!
        var longitude:Double = Double(longitudeValue)!
        if (northSouth.uppercaseString == "S") {
            latitude = latitude * -1.0
        }
        if (westEast.uppercaseString == "W") {
            longitude = longitude * -1.0
        }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    func mapView(mapView: MKMapView, rendererForOverlay overlay: MKOverlay) -> MKOverlayRenderer {
        let defaultOverlay = MKPolygonRenderer()
        if overlay is MKPolygon {
            let polygonView = MKPolygonRenderer(overlay: overlay)
            polygonView.lineWidth = 0.5
            polygonView.fillColor = UIColor.yellowColor().colorWithAlphaComponent(0.4)
            polygonView.strokeColor = UIColor.redColor().colorWithAlphaComponent(0.6)

            return polygonView
        }
        return defaultOverlay
    }
    
    func addRectBoundry(latitude: Double, longitude: Double) {
        var points = [
            CLLocationCoordinate2DMake(latitude, longitude),
            CLLocationCoordinate2DMake(latitude+1, longitude),
            CLLocationCoordinate2DMake(latitude+1, longitude+1),
            CLLocationCoordinate2DMake(latitude, longitude+1)
        ]
        let polygonOverlay:MKPolygon = MKPolygon(coordinates: &points, count: points.count)
        self.mapView.addOverlay(polygonOverlay)
    }
    
    func removeAllFromMap() {
        self.mapView.removeAnnotations(mapView.annotations)
        self.mapView.removeOverlays(mapView.overlays)
    }

    func mapView(mapView: MKMapView, annotationView view: MKAnnotationView, didChangeDragState newState: MKAnnotationViewDragState, fromOldState oldState: MKAnnotationViewDragState) {
        // if the annotation is dragged to a different location, handle it
        if newState == MKAnnotationViewDragState.Ending {
            //let droppedAt = view.annotation?.coordinate
            let annotation = view.annotation!
            let title:String = ((view.annotation?.title)!)!
            self.pinAnnotation(title, subtitle: "", coordinate: annotation.coordinate)
        }
    }
    
    func mapView(mapView: MKMapView, viewForAnnotation annotation: MKAnnotation) -> MKAnnotationView? {
        var view : MKAnnotationView! = nil
        let t: String = String(annotation.title)
        if (annotation is MKUserLocation) {
            //if annotation is not an MKPointAnnotation (eg. MKUserLocation),
            //return nil so map draws default view for it (eg. blue dot)...
            //let identifier = "downloadFile"
            //view = self.mapViewCalloutAccessoryAction("Download", annotation: annotation, identifier: identifier)
            return nil
        } else if (t.containsString("Download")) {
            let identifier = "downloadFile"
            view = self.mapViewCalloutAccessoryAction("Download", annotation: annotation, identifier: identifier)
        } else {
            let identifier = "deleteFile"
            view = self.mapViewCalloutAccessoryAction("Delete", annotation: annotation, identifier: identifier)
        }
        return view
    }
    
    func mapViewCalloutAccessoryAction(calloutAction: String, annotation: MKAnnotation, identifier: String)-> MKAnnotationView? {
        var view : MKAnnotationView! = nil
        view = self.mapView.dequeueReusableAnnotationViewWithIdentifier(identifier)
        if view == nil {
            view = MKPinAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            view.canShowCallout = true
            view.calloutOffset = CGPoint(x: -5, y: 5)
            //view!.animatesDrop = true
            
            let image = UIImage(named:calloutAction)
            let button = UIButton(type: UIButtonType.DetailDisclosure)
            button.setImage(image, forState: UIControlState.Normal)
            view!.leftCalloutAccessoryView = button as UIView
            
            // if the annotation title contains Download, allow drag option
            if (calloutAction.containsString("Download")) {
                view.draggable = true
            } else {
                view.draggable = false
            }
        }
        return view
    }
    
    func mapView(mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
        let annotation = view.annotation!
        let annotLatLng = annotation.subtitle!
        // added the ';' delimeter in the annotation subtitle in the handleLongPress
        let latLng = annotLatLng!.componentsSeparatedByString(" ")
        var lat: Double! = Double(latLng[0])
        var lng: Double! = Double(latLng[1])
        
        let tempHgtLatLngPrefix = getHgtLatLngPrefix(lat, longitude: lng)
        // round the lat & long to the closest integer value..
        lat = floor(lat)
        lng = floor(lng)
        
        let strFileName = (String(format:"%@%02d%@%03d%@", tempHgtLatLngPrefix.latitudePrefix, abs(Int(lat)), tempHgtLatLngPrefix.longitudePrefix, abs(Int(lng)), ".hgt"))
        self.hgtCoordinate = CLLocationCoordinate2D(latitude: lat, longitude: lng)
        let strTableCellItem = "\(strFileName) (Lat \(lat) Lng \(lng))"
        
        if view.reuseIdentifier == "downloadFile" {
            self.initiateDownload(annotationView: view, tableCellItem2Add: strTableCellItem, hgtFileName: strFileName)
        } else if view.reuseIdentifier == "deleteFile" {
            self.initiateDelete(strFileName)
        }
    }
    
    func initiateDownload(annotationView view: MKAnnotationView, tableCellItem2Add: String, hgtFileName: String) {
        // check if the data already downloaded and exists in the table..
        // don't download if its there already
        if (pickerData.contains(tableCellItem2Add)) {
            let alertController = UIAlertController(title: hgtFileName, message: "File Already Exists..", preferredStyle: .Alert)
            let ok = UIAlertAction(title: "OK", style: .Default, handler: { (action) -> Void in
            })
            alertController.addAction(ok)
            presentViewController(alertController, animated: true, completion: nil)
        } else{
            let srtmDataRegion = self.getHgtRegion(hgtFileName)
            if (srtmDataRegion.isEmpty) {
                ActivityIndicator.hide(success: false, animated: true, errorMsg: "Download Error!!")
                let alertController = UIAlertController(title: "Download Error!!", message: "Data unavailable. Try someother location.", preferredStyle: .Alert)
                let ok = UIAlertAction(title: "OK", style: .Default, handler: {
                    (action) -> Void in
                })
                alertController.addAction(ok)
                self.presentViewController(alertController, animated: true, completion: nil)
            } else {
                ActivityIndicator.show("Downloading",  disableUI: false)
                let hgtFilePath: String = SRTM.DOWNLOAD_SERVER + srtmDataRegion + "/" + hgtFileName + ".zip"
                let url = NSURL(string: hgtFilePath)
                let hgtDownloadMgr = HgtDownloadMgr()
                hgtDownloadMgr.delegate = self
                hgtDownloadMgr.downloadHgtFile(url!)
            }
        }
    }
    
    func getHgtRegion(hgtFileName: String) -> String {
        let tmpHgtZipName = hgtFileName + ".zip"
        if (NORTH_AMERICA_REGION_DATA.contains(tmpHgtZipName)) {
            return SRTM.REGION_NORTH_AMERICA
        } else if (ISLANDS_REGION_DATA.contains(tmpHgtZipName)) {
            return SRTM.REGION_ISLANDS
        } else if (EURASIA_REGION_DATA.contains(tmpHgtZipName)) {
            return SRTM.REGION_EURASIA
        } else if (AUSTRALIA_REGION_DATA.contains(tmpHgtZipName)) {
            return SRTM.REGION_AUSTRALIA
        } else if (AFRICA_REGION_DATA.contains(tmpHgtZipName)) {
            return SRTM.REGION_AFRICA
        } else if (SOUTH_AMERICA_REGION_DATA.contains(tmpHgtZipName)) {
            return SRTM.REGION_SOUTH_AMERICA
        }
        return ""
    }
    
    func didReceiveResponse(destinationPath: String) {
        
        if (destinationPath.isEmpty || destinationPath.containsString("Error")) {
            // capture and throw a message if anyother error occurs
            ActivityIndicator.hide(success: false, animated: true, errorMsg: destinationPath)
            let alertController = UIAlertController(title: "Download Error!!", message: destinationPath, preferredStyle: .Alert)
            let ok = UIAlertAction(title: "OK", style: .Default, handler: {
                (action) -> Void in
            })
            alertController.addAction(ok)
            presentViewController(alertController, animated: true, completion: nil)
        } else {
            dispatch_async(dispatch_get_main_queue()) {
                () -> Void in
                ActivityIndicator.hide(success: true, animated: true, errorMsg: "")
                self.mapView.removeAnnotations(self.mapView.annotations)
                let fileName = NSURL(fileURLWithPath: destinationPath).lastPathComponent!
                // add the downloaded file to the array of file names...
                self.manageHgtDataArray(fileName, arrayAction: "add")
                // draw the rectangle boundary on the map for the dowloaded data
                self.addRectBoundry(self.hgtCoordinate.latitude, longitude: self.hgtCoordinate.longitude)
                // refresh the table with the latest array data
                self.refresh()
            }
        }
    }
    func didFailToReceieveResponse(error: String) {
        ActivityIndicator.hide(success: false, animated: true, errorMsg: error)
        print("\(error)")
    }
    
    func handleLongPress(gestureRecognizer: UILongPressGestureRecognizer) {
        if gestureRecognizer.state == UIGestureRecognizerState.Began {
            gestureRecognizerStateBegan(gestureRecognizer)
        }
    }
    
    func gestureRecognizerStateBegan(gestureRecognizer: UILongPressGestureRecognizer) {
        let touchLocation:CGPoint = gestureRecognizer.locationInView(mapView)
        self.mapView.removeAnnotations(mapView.annotations)
        let locationCoordinate = mapView.convertPoint(touchLocation,toCoordinateFromView: mapView)
        let tempHgtLatLngPrefix = getHgtLatLngPrefix(locationCoordinate.latitude, longitude: locationCoordinate.longitude)
        
        // round the lat & long to the closest integer value..
        let lat = floor(locationCoordinate.latitude)
        let lng = floor(locationCoordinate.longitude)
        let strFileName = (String(format:"%@%02d%@%03d%@", tempHgtLatLngPrefix.latitudePrefix, abs(Int(lat)), tempHgtLatLngPrefix.longitudePrefix, abs(Int(lng)), ".hgt"))
        
        if (CheckHgtFileExists(strFileName)) {
            let title = "Delete \(strFileName) File?"
            let subtitle = "\(String(format:"%.4f", locationCoordinate.latitude)) \(String(format:"%.4f", locationCoordinate.longitude))"
            
            pinAnnotation (title, subtitle: subtitle, coordinate:locationCoordinate)
            return
        } else if (!getHgtRegion(strFileName).isEmpty) {
            // degree symbol "\u{00B0}"
            let title = "Download 1\("\u{00B0}") Tile?"
            let subtitle = "\(String(format:"%.4f", locationCoordinate.latitude)) \(String(format:"%.4f", locationCoordinate.longitude))"
            pinAnnotation (title, subtitle: subtitle, coordinate:locationCoordinate)
            return
        } else {
            var style = ToastStyle()
            style.messageColor = UIColor.redColor()
            style.backgroundColor = UIColor.whiteColor()
            style.messageFont = UIFont(name: "HelveticaNeue", size: 16)
            self.view.makeToast("Data unavailable for this location", duration: 1.5, position: .Center, style: style)
            return
        }
    }
    
    func CheckHgtFileExists(strHgtFileName: String) -> Bool {
        let fm = NSFileManager.defaultManager()
        let documentsFolderPath = NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory.DocumentDirectory, NSSearchPathDomainMask.UserDomainMask, true)
        if (fm.fileExistsAtPath(documentsFolderPath[0] + "/" + strHgtFileName)) {
            return true
        }
        return false
    }
   
    func deleteFile(hgtFileName: String?) {
        let documentDirPath = NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory.DocumentDirectory, NSSearchPathDomainMask.UserDomainMask, true)
        if hgtFileName?.isEmpty == false {
            
            let filePath = "\(documentDirPath[0])/\(hgtFileName!)"
            if NSFileManager.defaultManager().fileExistsAtPath(filePath) {
                do {
                    try NSFileManager.defaultManager().removeItemAtPath(filePath)
                    
                    // refresh the map and the table after the hgt file has been removed.
                    dispatch_async(dispatch_get_main_queue()) {
                        () -> Void in
                        let fileName = NSURL(fileURLWithPath: filePath).lastPathComponent!
                        // remove the file from the array of file names...
                        self.manageHgtDataArray(fileName, arrayAction: "remove")
                        // remove the rectangle boundary on the map for the dowloaded data
                        self.removeAllFromMap()
                        // find out if there is a way to remove a selected map overlay..
                        //self.removeRectBoundry(self.hgtCoordinate.latitude, longitude: self.hgtCoordinate.longitude)
                        // navigate the data folder and redraw the overlays from the data files..
                        self.getHgtFiles()
                        // refresh the table with the latest array data
                        self.refresh()
                    }
                } catch let error as NSError  {
                    print("Error occurred during file delete : \(error.localizedDescription)")
                }
            }
        }
    }
    
    func getHgtLatLngPrefix(latitude: Double, longitude: Double) -> hgtLatLngPrefix {
        
        var tempHgtLatLngPrefix = hgtLatLngPrefix(latitudePrefix: "N", longitudePrefix: "E")
        if (latitude < 0) {
            tempHgtLatLngPrefix.longitudePrefix = "S"
        }
        if (longitude < 0) {
            tempHgtLatLngPrefix.longitudePrefix = "W"
        }
        return tempHgtLatLngPrefix
    }
    
    func initiateDelete(hgtFileName: String?) {
        let alertController = UIAlertController(title: "Delete selected data File?", message: "", preferredStyle: .Alert)
        let ok = UIAlertAction(title: "OK", style: .Default, handler: {
            (action) -> Void in
            self.deleteFile(hgtFileName)
        })
        let cancel = UIAlertAction(title: "Cancel", style: .Cancel) {
            (action) -> Void in
            print("Delete cancelled!")
        }
        alertController.addAction(ok)
        alertController.addAction(cancel)
        presentViewController(alertController, animated: true, completion: nil)
    }
}


