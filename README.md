# MapKit Meetup

## Get Location

In `ViewController.swift`:

```swift
import MapKit
```

```swift
let locationManager = CLLocationManager()
```

In `viewDidLoad()`:

```swift
locationManager.requestLocation()
```

Error because can't handle the location.

```
'NSInternalInconsistencyException', reason: 'Delegate must respond to locationManager:didUpdateLocations:'
```

Set the delegate:

```swift
locationManager.delegate = self
```

And implement the method from the error message:

```swift
extension ViewController: CLLocationManagerDelegate {    
    func locationManager(manager: CLLocationManager, didUpdateLocations locations: [CLLocation]){
        print("locations: \(locations)")
    }
    
    func locationManager(manager: CLLocationManager, didFailWithError error: NSError) {
        print("error: \(error)")
    }
}
```

Note: You need implement `didFailWithError` otherwise you get this:

```
'NSInternalInconsistencyException', reason: 'Delegate must respond to locationManager:didFailWithError:'
```

You don't have permissions.

```
error: Error Domain=kCLErrorDomain Code=0 "(null)"
```

Because you need to request permission.

```swift
locationManager.requestWhenInUseAuthorization()
```

No permission prompt.

Info.plist

```
NSLocationWhenInUseUsageDescription
```

(when running, purposely wait before hitting Allow. race condition between requestLocation timeout and the user responding to the prompt)

Need to re-request location if the user hits Allow:

Pro-tip: Use a guard statement here:

```swift
func locationManager(manager: CLLocationManager, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
    guard status == .AuthorizedWhenInUse else { return }
    locationManager.requestLocation()
}
```

Make sure to set location in Simulator. Show how to do it.

```
39.1671385
-76.840939
```

## Add Map

Need some UI.

Disable size classes.

1. Add MKMapView
1. Set constraints

Pro Tip: Set the top constraint NOT to the layout guide

1. Set delegate
1. Show user location

Crash:

```
'NSInvalidUnarchiveOperationException', reason: 'Could not instantiate class named MKMapView'
```

1. Set the capabilities due to error
1. Create IBOutlet mapView

Zoom in

```swift
func locationManager(manager: CLLocationManager, didUpdateLocations locations: [CLLocation]){
    guard let location = locations.first else { return }
    let span = MKCoordinateSpanMake(0.05, 0.05)
    let region = MKCoordinateRegion(center: location.coordinate, span: span)
    mapView.setRegion(region, animated: true)
}
```

## Search Table

Create the class:

`LocationSearchTable.swift`

```swift
import UIKit
class LocationSearchTable : UITableViewController { 

}
```

Storyboard stuff:

1. Add table view controller
1. Set the class
1. Set storyboard ID **important**
1. Set cell to subtitle
1. Set cell identifier
1. Embed nav controller

Pro-tip: Point out that there is **NO** segue to the table

TODO:
Need a good analogy of the UISearchController. Something small that dangles off the bigger thing, and controls whether the big thing shows up. Venetian blinds?

Set up the table. Maybe write everything out as pseudo-code first.

```
        // create search controller

        // make the table

        // set search results CONTROLLER

		// set search results UPDATER

		// stick the search bar somewhere
```

Maybe `definesPresentationContext` and `hidesNavigationBarDuringPresentation` -- let them see the bug first.

* hidesNavigationBarDuringPresentation: nav bar flies off the screen
* definesPresentationContext: search results table totally obscures the nav bar. show analogy of cards in a deck, and pushing multiple cards and iOS removes the ones beneath.

Also show what happens when you don't use an instance variable for the resultSearchController (no table shows up)

```
var resultSearchController:UISearchController? = nil
```

```swift
func setupSearchTable(){
    guard let locationSearchTable = storyboard?.instantiateViewControllerWithIdentifier(String(LocationSearchTable)) as? LocationSearchTable else { return }
    resultSearchController = UISearchController(searchResultsController: locationSearchTable)
    resultSearchController?.searchResultsUpdater = locationSearchTable
    let searchBar = resultSearchController?.searchBar
    searchBar?.placeholder = "Search for places"
    navigationItem.titleView = searchBar
    resultSearchController?.hidesNavigationBarDuringPresentation = false 
    definesPresentationContext = true
}
```

In `viewDidLoad`:

```swift
setupSearchTable()
```


Explain some tricky concepts:

1. UISearchController has 3 components:
  * searchResultsController: displays results. the table view controller
  * searchResultsUpdater: figures out new results. also the table view controller
  * searchBar: you stick this into the nav bar
1. Presentation context lets you superimpose cards on one another

Set up the delegate

```swift
extension LocationSearchTable : UISearchResultsUpdating {
    func updateSearchResultsForSearchController(searchController: UISearchController) {
    }
}
```

Why do you use an instance variable for the UISearchController?

```
Attempting to load the view of a view controller while it is deallocating is not allowed and may result in undefined behavior (<UISearchController: 0x7fb8db6af1b0>)
```

## MKLocalSearchRequest

Add this to `ViewController.swift`

```swift
locationSearchTable.mapView = mapView
```

And completely replace `LocationSearchTable.swift`

1. Add the `import` and variables
1. Implement UISearchResultsUpdating
1. Populate the cell
1. Add the address parsing methods
1. Add the detail text label

```swift
import UIKit
import MapKit

class LocationSearchTable: UITableViewController {
    
    var matchingItems:[MKMapItem] = []
    var mapView: MKMapView? = nil

}

extension LocationSearchTable: UISearchResultsUpdating {
    func updateSearchResultsForSearchController(searchController: UISearchController) {
        guard let mapView = mapView else { return }
        let request = MKLocalSearchRequest()
        request.naturalLanguageQuery = searchController.searchBar.text
        request.region = mapView.region
        let search = MKLocalSearch(request: request)
        search.startWithCompletionHandler { response, _ in
            guard let response = response else { return }
            self.matchingItems = response.mapItems
            self.tableView.reloadData()
        }
    }
}
```

Request is made up of a search term `tacos` and a map region. The request is like a cannon ball. The `MKLocalSearch` fires off the request.

```swift
extension LocationSearchTable {
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return matchingItems.count
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("cell")!
        let selectedItem = matchingItems[indexPath.row].placemark
        cell.textLabel?.text = selectedItem.name
        return cell
    }
}
```

## Address Parser

```swift
func convertEmptyToNil(string: String?) -> String? {
    return (string ?? "").isEmpty ? nil : string
}

func parseAddress(selectedItem:MKPlacemark) -> String {
    // see https://gist.github.com/joemasilotti/da1c5a04bd6386c22d55
    let streetNumber = selectedItem.subThoroughfare
    let streetName = selectedItem.thoroughfare
    let city = selectedItem.locality
    let state = selectedItem.administrativeArea
    
    let addressLine1 = [streetNumber, streetName].flatMap{ $0 }.joinWithSeparator(" ")
    let addressLine2 = [city, state].flatMap{ $0 }.joinWithSeparator(" ")
    let oneLineAddress = [addressLine1, addressLine2].flatMap{ convertEmptyToNil($0) }.joinWithSeparator(", ")
    return oneLineAddress
}

```

```swift
cell.detailTextLabel?.text = parseAddress(selectedItem)
```

## Drop Pin

`ViewController.swift`

```swift
protocol HandleMapSearch {
    func dropPinZoomIn(placemark:MKPlacemark)
}
```

```swift
var selectedPin:MKPlacemark? = nil
```

```swift
extension ViewController: HandleMapSearch {
    func dropPinZoomIn(placemark:MKPlacemark){
        // cache the pin
        selectedPin = placemark
        // clear existing pins
        mapView.removeAnnotations(mapView.annotations)
        let annotation = MKPointAnnotation()
        annotation.coordinate = placemark.coordinate
        annotation.title = placemark.name
        let city = placemark.locality
        let state = placemark.administrativeArea
        annotation.subtitle = [city, state].flatMap { $0 }.joinWithSeparator(", ")
        mapView.addAnnotation(annotation)
        let span = MKCoordinateSpanMake(0.05, 0.05)
        let region = MKCoordinateRegionMake(placemark.coordinate, span)
        mapView.setRegion(region, animated: true)
    }
}
```

In `viewDidLoad()`:

```swift
locationSearchTable.handleMapSearchDelegate = self
```

`LocationSearchTable.swift`

```swift
var handleMapSearchDelegate:HandleMapSearch? = nil
```

```swift
extension LocationSearchTable {
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let selectedItem = matchingItems[indexPath.row].placemark
        handleMapSearchDelegate?.dropPinZoomIn(selectedItem)
        dismissViewControllerAnimated(true, completion: nil)
    }
}
```

## Wire the button and pin

```swift
extension ViewController : MKMapViewDelegate {
    func mapView(mapView: MKMapView, viewForAnnotation annotation: MKAnnotation) -> MKAnnotationView?{
        if annotation is MKUserLocation {
            //return nil so map view draws "blue dot" for standard user location
            return nil
        }
        let reuseId = "pin"
        var pinView = mapView.dequeueReusableAnnotationViewWithIdentifier(reuseId) as? MKPinAnnotationView
        pinView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: reuseId)
        pinView?.pinTintColor = UIColor.orangeColor()
        pinView?.canShowCallout = true
        let smallSquare = CGSize(width: 30, height: 30)
        let button = UIButton(frame: CGRect(origin: CGPointZero, size: smallSquare))
        button.setBackgroundImage(UIImage(named: "car"), forState: .Normal)
        button.addTarget(self, action: #selector(ViewController.getDirections), forControlEvents: .TouchUpInside)
        pinView?.leftCalloutAccessoryView = button
        return pinView
    }
}
```

```swift
func getDirections(){
    if let selectedPin = selectedPin {
        let mapItem = MKMapItem(placemark: selectedPin)
        let launchOptions = [MKLaunchOptionsDirectionsModeKey : MKLaunchOptionsDirectionsModeDriving]
        mapItem.openInMapsWithLaunchOptions(launchOptions)
    }
}
```

## Custom image

Import StyleKit file from desktop

```swift
let carImage = StyleKit.imageOfCar(size: smallSquare, resizing: .AspectFit)
button.setBackgroundImage(carImage, forState: .Normal)
```

Monkey patch the setFill color in Style Kit
