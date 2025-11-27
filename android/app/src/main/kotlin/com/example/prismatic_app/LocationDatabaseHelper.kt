package com.example.prismatic_app

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper

class LocationDatabaseHelper(context: Context) :
    SQLiteOpenHelper(context, "location_data.db", null, 2) {

    companion object {
        private const val TABLE_NAME = "unsent_locations"
        private const val COLUMN_ID = "id"
        private const val COLUMN_JSON = "json_data"
        private const val COLUMN_SENT = "sent"
    }

    override fun onCreate(db: SQLiteDatabase) {
        val createTable = """
            CREATE TABLE $TABLE_NAME (
                $COLUMN_ID INTEGER PRIMARY KEY AUTOINCREMENT,
                $COLUMN_JSON TEXT,
                $COLUMN_SENT INTEGER DEFAULT 0
            )
        """.trimIndent()
        db.execSQL(createTable)
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        if (oldVersion < 2) {
            db.execSQL("ALTER TABLE $TABLE_NAME ADD COLUMN $COLUMN_SENT INTEGER DEFAULT 0")
        }
    }

    @Synchronized
    fun insertLocation(jsonData: String) {
        val db = writableDatabase
        val values = ContentValues().apply {
            put(COLUMN_JSON, jsonData)
            put(COLUMN_SENT, 0)
        }
        db.insert(TABLE_NAME, null, values)
        db.close()
    }

    @Synchronized
    fun getUnsentLocations(): List<Pair<Int, String>> {
        val db = readableDatabase
        // Order by ID ASC to get oldest locations first (chronological order)
        val cursor = db.rawQuery("SELECT $COLUMN_ID, $COLUMN_JSON FROM $TABLE_NAME WHERE $COLUMN_SENT = 0 ORDER BY $COLUMN_ID ASC", null)
        val locations = mutableListOf<Pair<Int, String>>()
        while (cursor.moveToNext()) {
            locations.add(cursor.getInt(0) to cursor.getString(1))
        }
        cursor.close()
        db.close()
        return locations
    }

    @Synchronized
    fun markAsSent(id: Int) {
        val db = writableDatabase
        val values = ContentValues().apply {
            put(COLUMN_SENT, 1)
        }
        db.update(TABLE_NAME, values, "$COLUMN_ID=?", arrayOf(id.toString()))
        db.close()
    }

    @Synchronized
    fun clearSent() {
        val db = writableDatabase
        db.execSQL("DELETE FROM $TABLE_NAME WHERE $COLUMN_SENT = 1")
        db.close()
    }
}
