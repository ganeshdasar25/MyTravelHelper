//
//  SearchTrainInteractor.swift
//  MyTravelHelper
//
//  Created by Satish on 11/03/19.
//  Copyright © 2019 Sample. All rights reserved.
//

import Foundation
import XMLParsing

class SearchTrainInteractor: PresenterToInteractorProtocol {
    var _sourceStationCode = String()
    var _destinationStationCode = String()
    weak var presenter: InteractorToPresenterProtocol?
    var urlSession: URLSessionProtocol = URLSession(configuration: .default)

    func fetchallStations() {
        guard Reach().isNetworkReachable() else {
            self.presenter?.showNoInterNetAvailabilityMessage()
            return
        }
        SearchTrainInteractor.fetchDataUsing(urlString: "http://api.irishrail.ie/realtime/realtime.asmx/getAllStationsXML", urlSession: urlSession) { (data, response, error) in
            guard let _data = data else {
                self.presenter?.stationListFetched(list: [])
                return
            }
            do {
                let station = try XMLDecoder().decode(Stations.self, from: _data)
                self.presenter?.stationListFetched(list: station.stationsList)
            }
            catch {
                debugPrint(error)
                self.presenter?.stationListFetched(list: [])
            }
        }
    }

    func fetchTrainsFromSource(sourceCode: String, destinationCode: String) {
        _sourceStationCode = sourceCode
        _destinationStationCode = destinationCode
        guard Reach().isNetworkReachable() else {
            self.presenter?.showNoInterNetAvailabilityMessage()
            return
        }
        
        let urlString = "http://api.irishrail.ie/realtime/realtime.asmx/getStationDataByCodeXML?StationCode=\(sourceCode)"
        SearchTrainInteractor.fetchDataUsing(urlString: urlString, urlSession: urlSession) { (data, response, error) in
            guard let _data = data else {
                self.presenter?.showNoTrainAvailbilityFromSource()
                return
            }
            do {
                let stationData = try XMLDecoder().decode(StationData.self, from: _data)
                if let _trainsList = stationData.trainsList, _trainsList.count > 0 {
                    self.processTrainListforDestinationCheck(trainsList: _trainsList)
                } else {
                    self.presenter?.showNoTrainAvailbilityFromSource()
                }
            }
            catch {
                debugPrint(error)
                self.presenter?.showNoTrainAvailbilityFromSource()
            }
        }
    }
    
    private func processTrainListforDestinationCheck(trainsList: [StationTrain]) {
        guard Reach().isNetworkReachable() else {
            self.presenter?.showNoInterNetAvailabilityMessage()
            return
        }
        
        var _trainsList = trainsList
        let today = Date()
        let group = DispatchGroup()
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        let dateString = formatter.string(from: today)
        for index  in 0...trainsList.count-1 {
            group.enter()
            let _urlString = "http://api.irishrail.ie/realtime/realtime.asmx/getTrainMovementsXML?TrainId=\(trainsList[index].trainCode)&TrainDate=\(dateString)"
            SearchTrainInteractor.fetchDataUsing(urlString: _urlString, urlSession: urlSession) { (data, response, error) in
                guard let _data = data else {
                    debugPrint(error ?? "Error is not available")
                    group.leave()
                    return
                }
                do {
                    let trainMovements = try XMLDecoder().decode(TrainMovementsData.self, from: _data)
                    if let _movements = trainMovements.trainMovements,
                       let sourceIndex = _movements.firstIndex(where: {$0.locationCode.caseInsensitiveCompare(self._sourceStationCode) == .orderedSame}),
                       let destinationIndex = _movements.firstIndex(where: {$0.locationCode.caseInsensitiveCompare(self._destinationStationCode) == .orderedSame}),
                       sourceIndex < destinationIndex,
                       let desiredStationMoment = _movements.filter({$0.locationCode.caseInsensitiveCompare(self._destinationStationCode) == .orderedSame}).first
                    {
                        _trainsList[index].destinationDetails = desiredStationMoment
                    }
                    group.leave()
                }
                catch {
                    debugPrint(error)
                    group.leave()
                }
            }
        }

        group.notify(queue: DispatchQueue.main) {
            let sourceToDestinationTrains = _trainsList.filter{$0.destinationDetails != nil}
            self.presenter?.fetchedTrainsList(trainsList: sourceToDestinationTrains)
        }
    }
}

extension SearchTrainInteractor {
    static func fetchDataUsing(urlString: String, urlSession: URLSessionProtocol, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) {
        guard let url = URL(string: urlString) else {
            completionHandler(nil, nil, "URL \(urlString) is not a proper.")
            return
        }

        let dataTask = urlSession.dataTask(with: url) { (data, response, error) in
            DispatchQueue.main.async {
                completionHandler(data, response, error?.localizedDescription)
            }
        }
        dataTask.resume()
    }
}

extension String: Error { }
