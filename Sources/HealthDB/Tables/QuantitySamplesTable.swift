import Foundation
import SQLite

struct QuantitySamplesTable {

    func create(in database: Connection, referencing unitStrings: UnitStringsTable) throws {
        try database.execute("CREATE TABLE quantity_samples (data_id INTEGER PRIMARY KEY, quantity REAL, original_quantity REAL, original_unit INTEGER REFERENCES unit_strings (ROWID) ON DELETE NO ACTION)")
    }

    let table = Table("quantity_samples")

    let dataId = SQLite.Expression<Int>("data_id")

    let quantity = SQLite.Expression<Double?>("quantity")

    let originalQuantity = SQLite.Expression<Double?>("original_quantity")

    /// References `ROWID` on table `unit_strings`
    let originalUnit = SQLite.Expression<Int?>("original_unit")

    func quantity(for id: Int, in database: Connection) throws -> (quantity: Double?, original: Double?, unit: Int?) {
        try database.prepare(table.filter(dataId == id).limit(1)).map {
            (quantity: $0[quantity], original: $0[originalQuantity], unit: $0[originalUnit])
        }.first ?? (nil, nil, nil)
    }
}
