//
//  ScrollableBottomSheetViewController
//  MySampleApp
//
//  Created by Joel Whitney on 8/20/17.
//
//

import Foundation
import UIKit
import SwiftyJSON
import AWSDynamoDB
import AWSMobileHubHelper

class ScrollableBottomSheetViewController: UIViewController {
    @IBOutlet var headerView: UIView!
    @IBOutlet var tableView: UITableView!
    @IBOutlet var dragHandle: UIButton!
    
    var searchController: UISearchController!
    var firstIndexPath: IndexPath!
    let fullView: CGFloat = 70
    var partialView: CGFloat {
        return UIScreen.main.bounds.height - 150
    }
    var scanBeerStore = [Beer]()
    var mainBeerStore = [AWSBeer]()
    var currentAWSBeer: AWSBeer!
    var currentBeer: Beer!
    var currentBeerIndexPath: IndexPath!
    var pickerQuantity = "1"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.delegate = self
        tableView.dataSource = self
        configureSearchController()
        let gesture = UIPanGestureRecognizer.init(target: self, action: #selector(ScrollableBottomSheetViewController.panGesture))
        dragHandle.addTarget(self, action: #selector(dragHandleAction), for: .touchUpInside)
        gesture.delegate = self
        view.addGestureRecognizer(gesture)
        queryWithPartitionKeyWithCompletionHandler { (response, error) in
            if let erro = error {
                //self.NoSQLResultLabel.text = String(erro)
                print("error: \(erro)")
            } else if response?.items.count == 0 {
                //self.NoSQLResultLabel.text = String("0")
                print("No items")
            } else {
                //self.NoSQLResultLabel.text = String(response!.items)
                print("success: \(response!.items)")
                self.updateItemstoStore(items: response!.items) {
                    DispatchQueue.main.async(execute: {
                        print("mainBeerStore updated")
                    })
                }
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        prepareBackgroundView()
        queryWithPartitionKeyWithCompletionHandler { (response, error) in
            if let erro = error {
                //self.NoSQLResultLabel.text = String(erro)
                print("error: \(erro)")
            } else if response?.items.count == 0 {
                //self.NoSQLResultLabel.text = String("0")
                print("No items")
            } else {
                //self.NoSQLResultLabel.text = String(response!.items)
                print("success: \(response!.items)")
                self.updateItemstoStore(items: response!.items) {
                    DispatchQueue.main.async(execute: {
                        print("mainBeerStore updated")
                    })
                }
            }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        UIView.animate(withDuration: 0.6, animations: { [weak self] in
            let frame = self?.view.frame
            let yComponent = self?.partialView
            self?.view.frame = CGRect(x: 0, y: yComponent!, width: frame!.width, height: frame!.height - 70)
        })
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    func queryWithPartitionKeyDescription() -> String {
        let partitionKeyValue = AWSIdentityManager.default().identityId!
        return "Find all items with userId = \(partitionKeyValue)."
    }
    func queryWithPartitionKeyWithCompletionHandler(_ completionHandler: @escaping (_ response: AWSDynamoDBPaginatedOutput?, _ error: NSError?) -> Void) {
        let objectMapper = AWSDynamoDBObjectMapper.default()
        let queryExpression = AWSDynamoDBQueryExpression()
        
        queryExpression.keyConditionExpression = "#userId = :userId"
        queryExpression.expressionAttributeNames = ["#userId": "userId",]
        queryExpression.expressionAttributeValues = [":userId": AWSIdentityManager.default().identityId!,]
        
        objectMapper.query(AWSBeer.self, expression: queryExpression) { (response: AWSDynamoDBPaginatedOutput?, error: Error?) in
            DispatchQueue.main.async(execute: {
                completionHandler(response, error as? NSError)
            })
        }
    }
    func updateItemstoStore(items: [AWSDynamoDBObjectModel], onCompletion: () -> Void) {
        for item in items {
            let awsBeer = item as! AWSBeer
            mainBeerStore.append(awsBeer)
            var sortedMainBeerStore = [Beer]()
            for item in mainBeerStore {sortedMainBeerStore.append(item.returnBeerObject())}
            sortedMainBeerStore.sort() { $0.name < $1.name }
            mainBeerStore = [AWSBeer]()
            for beerItem in sortedMainBeerStore { mainBeerStore.append(beerItem.awsBeer()) }
            //print("\(mainBeerStore.count) items in beer store")
        }
        onCompletion()
    }
    func dragHandleAction() {
        let y = self.view.frame.minY
        if y < fullView {
            partialHeight()
        } else {
            fullHeight()
        }
    }
    
    func configureSearchController() {
        headerView.layer.shadowColor = UIColor(white: 0.0, alpha: 0.5).cgColor
        headerView.layer.shadowOffset = CGSize(width: 0.0, height: 1.0)
        headerView.layer.shadowOpacity = 0.25
        headerView.layer.shadowRadius = 1.0
        // Initialize and perform a minimum configuration to the search controller.
        searchController = UISearchController(searchResultsController: nil)
        searchController.searchResultsUpdater = self
        searchController.dimsBackgroundDuringPresentation = false
        searchController.searchBar.backgroundColor = UIColor(red: 235/255, green: 171/255, blue: 28/255, alpha: 1)
        searchController.searchBar.searchBarStyle = .minimal
        searchController.searchBar.placeholder = "Scan barcode or search beers"
        searchController.searchBar.returnKeyType = UIReturnKeyType.search
        searchController.searchBar.delegate = self
        searchController.hidesNavigationBarDuringPresentation = false
        //searchController.searchBar.translatesAutoresizingMaskIntoConstraints = false
        searchController.searchBar.contentMode = .redraw
        self.definesPresentationContext = false
        //searchController.searchBar.frame = CGRect(x: headerView.frame.origin.x, y: headerView.frame.origin.y + 20 , width: headerView.frame.width - 55, height: 44.0)
        searchController.searchBar.frame = CGRect(x: headerView.frame.origin.x, y: dragHandle.frame.origin.y + dragHandle.frame.height + 2 , width: headerView.frame.width - 55, height: 44.0)
        searchController.searchBar.sizeToFit()
        headerView.addSubview(searchController.searchBar)
        //tableView.tableHeaderView = searchController.searchBar
    }
    func panGesture(_ recognizer: UIPanGestureRecognizer) {
        
        let translation = recognizer.translation(in: self.view)
        let velocity = recognizer.velocity(in: self.view)
        
        let y = self.view.frame.minY
        if (y + translation.y >= fullView) && (y + translation.y <= partialView) {
            self.view.frame = CGRect(x: 0, y: y + translation.y, width: view.frame.width, height: view.frame.height)
            recognizer.setTranslation(CGPoint.zero, in: self.view)
        }
        
        if recognizer.state == .ended {
            var duration =  velocity.y < 0 ? Double((y - fullView) / -velocity.y) : Double((partialView - y) / velocity.y )
            duration = duration > 1.3 ? 1 : duration
            UIView.animate(withDuration: duration, delay: 0.0, options: [.allowUserInteraction], animations: {
                if  velocity.y >= 0 {
                    self.view.frame = CGRect(x: 0, y: self.partialView, width: self.view.frame.width, height: self.view.frame.height)
                    self.tableView.scrollToRow(at: self.firstIndexPath!, at: .top, animated: true)
                } else {
                    self.view.frame = CGRect(x: 0, y: self.fullView, width: self.view.frame.width, height: self.view.frame.height)
                }
                
            }, completion: { [weak self] _ in
                if ( velocity.y < 0 ) {
                    self?.tableView.isScrollEnabled = true
                }
            })
        }
    }
    
    func fullHeight() {
        UIView.animate(withDuration: 0.0, delay: 0.0, options: [], animations: {
                self.view.frame = CGRect(x: 0, y: self.fullView, width: self.view.frame.width, height: self.view.frame.height)
        })
    }
    func partialHeight() {
        UIView.animate(withDuration: 0.0, delay: 0.0, options: [], animations: {
            self.view.frame = CGRect(x: 0, y: self.partialView, width: self.view.frame.width, height: self.view.frame.height)
        })
        tableView.scrollToRow(at: firstIndexPath!, at: .top, animated: true)
    }
    
    func prepareBackgroundView(){
        let blurEffect = UIBlurEffect.init(style: .dark)
        let visualEffect = UIVisualEffectView.init(effect: blurEffect)
        let bluredView = UIVisualEffectView.init(effect: blurEffect)
        bluredView.contentView.addSubview(visualEffect)
        visualEffect.frame = UIScreen.main.bounds
        bluredView.frame = UIScreen.main.bounds
        view.insertSubview(bluredView, at: 0)
    }
    func checkButtonTapped(sender:AnyObject) {
        let buttonPosition = sender.convert(CGPoint.zero, to: self.tableView)
        let indexPath = self.tableView.indexPathForRow(at: buttonPosition)
        currentBeerIndexPath = indexPath!
    }

    func cancelSelection(sender: UIButton){
        print("Cancel");
        self.dismiss(animated: true, completion: nil);
        // We dismiss the alert. Here you can add your additional code to execute when cancel is pressed
    }
    func showPickerInActionSheet(sender: AnyObject) {
        pickerQuantity = "1"
        checkButtonTapped(sender: sender)
        print(currentBeerIndexPath.row)
        currentBeer = scanBeerStore[currentBeerIndexPath.row]
        var actionType: String
        var actionTitle: String
        if sender.tag == 1 {
            actionType = "add"
            actionTitle = "Add"
        } else {
            actionType = "remove"
            actionTitle = "Remove"
        }
        print("\(actionTitle) \(currentBeer.name)")
        var title = "\(actionTitle) \(currentBeer.name)"
        var message = "Enter quantity of beers to \(actionType)\n\n\n\n\n\n\n\n\n\n"
        var alert = UIAlertController(title: title, message: message, preferredStyle: UIAlertControllerStyle.actionSheet)
        alert.isModalInPopover = true
        //Create a frame (placeholder/wrapper) for the picker and then create the picker
        var pickerFrame: CGRect = CGRect(x: 17, y: 52, width: 270, height: 160); // CGRectMake(left), top, width, height) - left and top are like margins
        var picker: UIPickerView = UIPickerView(frame: pickerFrame);
        //set the pickers datasource and delegate
        picker.delegate = self
        picker.dataSource = self
        //Add the picker to the alert controller
        alert.view.addSubview(picker)
        //add buttons to the view
        var buttonCancelFrame: CGRect = CGRect(x: 0, y: 200, width: 100, height: 30) //size & position of the button as placed on the toolView
        //Create the cancel button & set its title
        var buttonCancel: UIButton = UIButton(frame: buttonCancelFrame)
        buttonCancel.setTitle("Cancel", for: UIControlState.normal)
        buttonCancel.setTitleColor(UIColor(red: 200/255, green: 147/255, blue: 49/255, alpha: 1), for: UIControlState.normal)
        //Add the target - target, function to call, the event witch will trigger the function call
        buttonCancel.addTarget(self, action: #selector(cancelSelection), for: UIControlEvents.touchDown)
        //add buttons to the view
        var buttonOkFrame: CGRect = CGRect(x: 170, y:  200, width: 100, height: 30); //size & position of the button as placed on the toolView
        //Create the Select button & set the title
        var buttonOk: UIButton = UIButton(frame: buttonOkFrame)
        if sender.tag == 1 {
            buttonOk.addTarget(self, action: #selector(addBeers), for: UIControlEvents.touchDown);
            buttonOk.setTitle("Add", for: UIControlState.normal);
            buttonOk.setTitleColor(UIColor(red: 200/255, green: 147/255, blue: 49/255, alpha: 1), for: UIControlState.normal)
        } else {
            //
        }
        alert.view.addSubview(buttonOk)
        alert.view.addSubview(buttonCancel)
        self.present(alert, animated: true, completion: nil);
    }
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if(segue.identifier == "detailsViewController") {
            let yourNextViewController = (segue.destination as! DetailsController)
            yourNextViewController.beer = currentBeer
        }

    }
    func addBeers(sender: UIButton){
        guard let quantity = Int(pickerQuantity) else {
            // handle bad no value or text entry
            return
        }
        guard let existingAWSBeer = mainBeerStore.filter({$0._beerEntryId == currentBeer.brewerydb_id}).first else {
            // Add new beer if doesn't exist
            currentBeer.quantity = quantity
            insertAWSBeer(beer: currentBeer)
            self.dismiss(animated: true, completion: {
                let alertController2 = UIAlertController(title: "\(self.currentBeer.name) added", message: "You added \(self.currentBeer.quantity) \(self.currentBeer.name).", preferredStyle: UIAlertControllerStyle.alert)
                alertController2.addAction(UIAlertAction(title: "Dismiss", style: UIAlertActionStyle.default,handler: nil))
                self.present(alertController2, animated: true, completion: nil)
            })
            return
        }
        // Update beer quanity if exists
        let existingBeer = existingAWSBeer.returnBeerObject()
        existingBeer.quantity += quantity
        existingAWSBeer._beer = existingBeer.beerObjectMap()
        let objectMapper = AWSDynamoDBObjectMapper.default()
        objectMapper.save(existingAWSBeer, completionHandler: {(error: Error?) -> Void in
            if let error = error {
                print("Amazon DynamoDB Save Error: \(error)")
                return
            }
            print("Item saved.")
        })
        self.dismiss(animated: true, completion: {
            let alertController2 = UIAlertController(title: "\(self.currentBeer.name) added", message: "You now have \(existingBeer.quantity) \(self.currentBeer.name).", preferredStyle: UIAlertControllerStyle.alert)
            alertController2.addAction(UIAlertAction(title: "Dismiss", style: UIAlertActionStyle.default,handler: nil))
            self.present(alertController2, animated: true, completion: nil)
        })
    }
    func insertAWSBeer(beer: Beer) {
        let objectMapper = AWSDynamoDBObjectMapper.default()
        let itemToCreate: AWSBeer = AWSBeer()
        itemToCreate._userId = AWSIdentityManager.default().identityId!
        itemToCreate._beerEntryId = beer.brewerydb_id
        itemToCreate._beer = beer.beerObjectMap()
        //itemToCreate._beer = ["thing": ""]
        print(itemToCreate._userId as String!)
        print(itemToCreate._beerEntryId as String!)
        print(itemToCreate._beer as [String: String]!)
        objectMapper.save(itemToCreate, completionHandler: {(error: Error?) -> Void in
            if let error = error {
                print("Amazon DynamoDB Save Error: \(error)")
                return
            }
            print("Item saved.")
        })
    }
    func updateAWSBeer(beer: Beer) {
        let objectMapper = AWSDynamoDBObjectMapper.default()
        let itemToCreate: AWSBeer = AWSBeer()
        itemToCreate._userId = AWSIdentityManager.default().identityId!
        itemToCreate._beerEntryId = beer.brewerydb_id
        itemToCreate._beer = beer.beerObjectMap()
        //itemToCreate._beer = ["thing": ""]
        print(itemToCreate._userId as String!)
        print(itemToCreate._beerEntryId as String!)
        print(itemToCreate._beer as [String: String]!)
        objectMapper.save(itemToCreate, completionHandler: {(error: Error?) -> Void in
            if let error = error {
                print("Amazon DynamoDB Save Error: \(error)")
                return
            }
            print("Item saved.")
        })
    }
    func handleJSON(beerJSON: JSON, maxResults: Int, onCompletion: () -> Void) {
        if let results = beerJSON["data"].array {
            var showMaxResults = maxResults
            if results.count < maxResults { showMaxResults = results.count }
            for i in 0..<showMaxResults {
                let beerResult = results[i]
                print("           " + beerResult["name"].string! )
                let beerResultObject = Beer(brewerydb_id: beerResult["id"].string! ,
                                            upc_code: "" ,
                                            name: beerResult["name"].string ?? "" ,
                                            beer_description: beerResult["description"].string ?? "",
                                            abv: beerResult["abv"].string ?? "--" ,
                                            label: beerResult["labels"]["large"].string ?? "" ,
                                            gravity: beerResult["style"]["ogMin"].string ?? "--" ,
                                            availability: beerResult["available"]["name"].string ?? "" ,
                                            availability_desc: beerResult["available"]["description"].string ?? "" ,
                                            style_name: beerResult["style"]["shortName"].string ?? "" ,
                                            style_desc: beerResult["style"]["description"].string ?? "" ,
                                            style_id: beerResult["style"]["id"].string ?? "" )
                beerResultObject.brewery_id = beerResult["breweries"][0]["id"].string ?? ""
                beerResultObject.brewery_name = beerResult["breweries"][0]["name"].string ?? ""
                scanBeerStore.append(beerResultObject)
            }
            print(self.scanBeerStore)
        } else {
            print("   No Beers")
            //            let alertController = UIAlertController(title: "Error", message: "The barcode is not in the database, consider adding it. Showing last search result", preferredStyle: UIAlertControllerStyle.alert)
            //            alertController.addAction(UIAlertAction(title: "Dismiss", style: UIAlertActionStyle.default,handler: nil))
            //            self.present(alertController, animated: true, completion: nil)
        }
        onCompletion()
    }
}

// MARK: - UIPicker delegate
extension ScrollableBottomSheetViewController: UIPickerViewDelegate {
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        pickerQuantity = String(row + 1)
    }
}

// MARK: - UIPicker delegate
extension ScrollableBottomSheetViewController: UIPickerViewDataSource {
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

// MARK: - Table view data source
extension ScrollableBottomSheetViewController: UITableViewDelegate, UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if self.scanBeerStore.count == 0 {
            return "Search results"
        } else if self.scanBeerStore.count == 1 {
            return "Last search results (\(self.scanBeerStore.count) beer)"
        } else {
            return "Last search results (\(self.scanBeerStore.count) beers)"
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return scanBeerStore.count + 1
    }
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if self.scanBeerStore.count == 0 {
            return 0.0
        } else {
            return 20.0
        }
    }
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 135.0
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        currentBeer = scanBeerStore[indexPath.row]
        tableView.deselectRow(at: indexPath, animated: true)
        self.performSegue(withIdentifier: "detailsViewController", sender: self)
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.row == 0 {
            firstIndexPath = indexPath
        }
        if indexPath.row < scanBeerStore.count {
            self.tableView.estimatedRowHeight = 135
            let cell = tableView.dequeueReusableCell(withIdentifier: "ScanBeerTableCell", for: indexPath) as! ScanBeerTableCell
            let beer = scanBeerStore[indexPath.row]
            // cell details
            cell.beerNameLabel.text = beer.name
            cell.beerStyle.text = beer.style_name
            cell.breweryNameLabel.text = beer.brewery_name
            cell.abvLabel.text = "\(beer.abv)%"
            cell.addBeerButton.tag = 1
            cell.addBeerButton.addTarget(self, action: #selector(showPickerInActionSheet), for: .touchUpInside)
            return cell
            // handle the last cell after all beers
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "ScanLastCell", for: indexPath) as! ScanLastCell
            if self.scanBeerStore.count == 0 {
                cell.lastCellLabel.text =  "No beers"
            } else {
                cell.lastCellLabel.text = ""
            }
            return cell
        }
    }
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if let myCell = cell as? ScanBeerTableCell {
            // cell formatting
            myCell.mainBackground.layer.cornerRadius = 8
            myCell.mainBackground.layer.masksToBounds = true
            myCell.shadowLayer.layer.masksToBounds = false
            myCell.shadowLayer.layer.shadowOffset = CGSize.zero
            myCell.shadowLayer.layer.shadowColor = UIColor.black.cgColor
            myCell.shadowLayer.layer.shadowOpacity = 0.5
            myCell.shadowLayer.layer.shadowRadius = 2
            myCell.shadowLayer.layer.shadowPath = UIBezierPath(roundedRect: myCell.shadowLayer.bounds, byRoundingCorners: .allCorners, cornerRadii: CGSize(width: 8, height: 8)).cgPath
            myCell.shadowLayer.layer.shouldRasterize = false
            myCell.shadowLayer.layer.rasterizationScale = UIScreen.main.scale
        }
    }
}

extension ScrollableBottomSheetViewController: UIGestureRecognizerDelegate {
    
    // Solution
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        let gesture = (gestureRecognizer as! UIPanGestureRecognizer)
        let direction = gesture.velocity(in: view).y
        
        let y = view.frame.minY
        if (y == fullView && tableView.contentOffset.y == 0 && direction > 0) || (y == partialView) {
            tableView.isScrollEnabled = false
        } else {
            tableView.isScrollEnabled = true
        }
        
        return false
    }
    
}

extension ScrollableBottomSheetViewController: UISearchBarDelegate {
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        print("search")
    }
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        print("cancel")
        partialHeight()
        scanBeerStore = [Beer]()
        tableView.reloadData()
    }
}

extension ScrollableBottomSheetViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        
        if searchController.isActive {
            print("text changed")
            fullHeight()
            if searchController.searchBar.text != "" {
                let searchString = searchController.searchBar.text!
                print("text changed to: \(searchString)")
                scanBeerStore = [Beer]()
                BrewerydbAPI.sharedInstance.search_beer_name(beerName: searchString, onCompletion: { (json: JSON) in
                    self.handleJSON(beerJSON: json, maxResults: 10, onCompletion: {
                        DispatchQueue.main.async(execute: {
                            print("reload search tableview")
                            self.tableView.reloadData()
                        })
                    })
                })
            } else {
                scanBeerStore = [Beer]()
                self.tableView.reloadData()
            }
        }
    
    }
}

