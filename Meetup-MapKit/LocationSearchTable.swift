//
//  LocationSearchTable.swift
//  Meetup-MapKit
//
//  Created by Robert Chen on 4/27/16.
//  Copyright © 2016 Robert Chen. All rights reserved.
//

import UIKit
import MapKit

class LocationSearchTable: UITableViewController {
    var mapView: MKMapView? = nil
    var matchingItems: [MKMapItem] = []
    
    func convertEmptyToNil(string: String?) -> String? {
        return (string ?? "").isEmpty ? nil : string
    }
    
    func parseAddress(selectedItem: MKPlacemark) -> String {
        let streetNumber = selectedItem.subThoroughfare
        let streetName = selectedItem.thoroughfare
        let city = selectedItem.locality
        let state = selectedItem.administrativeArea
        let addressLine1 = [streetNumber, streetName].flatMap{ $0 }.joinWithSeparator(" ")
        let addressLine2 = [city, state].flatMap { $0 }.joinWithSeparator(" ")
        let oneLineAddress = [addressLine1, addressLine2].flatMap { convertEmptyToNil($0) }.joinWithSeparator(", ")
        return oneLineAddress
    }
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

extension LocationSearchTable {
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return matchingItems.count
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("cell")!
        let selectedItem = matchingItems[indexPath.row]
        cell.textLabel?.text = selectedItem.placemark.name
        cell.detailTextLabel?.text = parseAddress(selectedItem.placemark)
        return cell
    }
}