//
//  DateFormatter+Extensions.swift
//  BeReal
//
//  Created by Tony Vazquez on 10/11/24.
//
import Foundation

extension DateFormatter {
    static var postFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter
    }()
}
