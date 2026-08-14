import Foundation
import SwiftData

enum FocusllySchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [
            Habit.self,
            HabitCheckIn.self,
            FocusSessionRecord.self,
            PlannedRestDay.self,
            FreezeTokenLedgerEntry.self,
            ReflectionEntry.self,
            HabitNotificationPlan.self,
            AppMigrationRecord.self
        ]
    }
}

enum FocusllySchemaMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [FocusllySchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}

/*
 Schema versioning rule:
 After a schema version ships, do not silently alter its model definitions.
 Future released schema changes must add a new VersionedSchema and extend
 FocusllySchemaMigrationPlan with an explicit migration stage when automatic
 migration is not sufficient.
 */
