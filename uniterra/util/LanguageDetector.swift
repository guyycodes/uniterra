//
//  LanguageDetector.swift
//  Uniterra
//
//  Created by Guy Morgan Beals on 10/18/25.
//

import Foundation
import NaturalLanguage

struct LanguageDetector {
    static func detect(from text: String) -> String? {
        guard !text.isEmpty else { return nil }
        
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        
        guard let languageCode = recognizer.dominantLanguage?.rawValue else {
            return nil
        }
        
        // Get language name in English
        let locale = Locale(identifier: "en")
        return locale.localizedString(forLanguageCode: languageCode)?.capitalized
    }
}
