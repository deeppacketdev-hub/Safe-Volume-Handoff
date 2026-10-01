import UIKit

@MainActor
enum HapticFeedbackService {
    /// Легкий тактильний відгук (для натискання кнопок)
    static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    
    /// Середній тактильний відгук (для підключення пристрою)
    static func medium() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    
    /// Важкий тактильний відгук (для попередження про гучність)
    static func heavy() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }
    
    /// Успіх (для успішного підключення)
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    
    /// Попередження (для високої гучності)
    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
    
    /// Помилка
    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}
