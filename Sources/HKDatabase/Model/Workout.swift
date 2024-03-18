import Foundation
import HealthKit
import CoreLocation

private let df: DateFormatter = {
    let df = DateFormatter()
    df.timeZone = .current
    df.dateStyle = .short
    df.timeStyle = .short
    return df
}()

public struct Workout {

    public let dataId: Int

    /// The distance in km (?)
    public let totalDistance: Double?

    public let goal: Goal?

    public let startDate: Date

    public let endDate: Date

    public let device: HKDevice?

    public let metadata: [String : Any]
    
    public let workoutEvents: [HKWorkoutEvent]

    public let workoutActivities: [HKWorkoutActivity]

    var firstActivityDate: Date? {
        workoutActivities.map { $0.startDate }.min()
    }
    
    var firstEventDate: Date? {
        workoutEvents.map { $0.dateInterval.start }.min()
    }
    
    var firstAvailableDate: Date? {
        [firstEventDate, firstActivityDate].compactMap { $0 }.min()
    }
    
    var dateString: String {
        guard let firstAvailableDate else {
            return "No date"
        }
        return df.string(from: firstAvailableDate)
    }
    
    var typeString: String {
        workoutActivities.first?.workoutConfiguration.activityType.description ?? "Unknown activity"
    }
    
    public init(dataId: Int, startDate: Date, endDate: Date, totalDistance: Double? = nil, goalType: Int? = nil, goal: Double? = nil, events: [HKWorkoutEvent] = [], activities: [HKWorkoutActivity] = [], metadata: [String : Any] = [:], device: HKDevice? = nil) {
        self.dataId = dataId
        self.startDate = startDate
        self.endDate = endDate
        self.totalDistance = totalDistance
        self.goal = .init(goalType: goalType, goal: goal)
        self.workoutEvents = events
        self.workoutActivities = activities
        self.metadata = metadata
        self.device = device
    }

    public func insert(into store: HKHealthStore, samples: [HKSample], route: [CLLocation]? = nil, removingPrivateMetadataFields: Bool = true) async throws -> HKWorkout {
        guard let configuration = workoutActivities.first?.workoutConfiguration else {
            throw WorkoutInsertionError.noWorkoutActivity
        }
        let builder = HKWorkoutBuilder(healthStore: store, configuration: configuration, device: nil)
        if removingPrivateMetadataFields {
            try await builder.addMetadata(metadata.removingPrivateFields())
        } else {
            try await builder.addMetadata(metadata)
        }
        try await builder.addWorkoutEvents(workoutEvents)
        try await builder.addSamples(samples)

        for activity in workoutActivities {
            try await builder.addWorkoutActivity(activity)
        }

        let endDate = workoutActivities.compactMap { $0.endDate }.max() ?? Date()
        try await builder.endCollection(at: endDate)
        guard let workout = try await builder.finishWorkout() else {
            throw WorkoutInsertionError.failedToFinishWorkout
        }

        if let route, !route.isEmpty {
            let routeBuilder = HKWorkoutRouteBuilder(healthStore: store, device: workout.device)
            try await routeBuilder.insertRouteData(route)
            try await routeBuilder.finishRoute(with: workout, metadata: nil)
        }
        return workout
    }
}

public enum WorkoutInsertionError: Error {
    /// No workout activity associated with the workout
    case noWorkoutActivity

    /// Failed to finish workout
    case failedToFinishWorkout
}

extension Workout: Equatable {
    public static func == (lhs: Workout, rhs: Workout) -> Bool {
        lhs.dataId == rhs.dataId
    }
}

extension Workout: Hashable {
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(dataId)
    }
}
