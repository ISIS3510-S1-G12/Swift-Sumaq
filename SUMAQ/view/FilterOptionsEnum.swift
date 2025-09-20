//
//  FilterOptionsEnum.swift
//  SUMAQ
//
//  Created by Gabriela  Escobar Rojas on 20/09/25.
//

enum FilterOption: String, CaseIterable, Identifiable {
    case price = "Price"
    case typeOfFood = "Type of Food"
    case withOffer = "With Offer"
    case withoutOffer = "Without Offer"
    var id: String { rawValue }
}
