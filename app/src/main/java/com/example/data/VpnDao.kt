package com.example.data

import androidx.room.*
import kotlinx.coroutines.flow.Flow

@Entity(tableName = "cdn_ips")
data class CdnIp(
    @PrimaryKey val ip: String,
    val rtt: Int,
    val provider: String, // Cloudflare, Cloudfront
    val timestamp: Long = System.currentTimeMillis()
)

@Dao
interface VpnDao {
    @Query("SELECT * FROM vpn_profiles ORDER BY latency ASC, id DESC")
    fun getProfilesOrdered(): Flow<List<VpnProfile>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertProfile(profile: VpnProfile)

    @Update
    suspend fun updateProfile(profile: VpnProfile)

    @Delete
    suspend fun deleteProfile(profile: VpnProfile)

    @Query("UPDATE vpn_profiles SET latency = :latency WHERE id = :id")
    suspend fun updateLatency(id: Int, latency: Int?)

    @Query("DELETE FROM vpn_profiles")
    suspend fun clearAll()

    // CDN Scanned IPs queries
    @Query("SELECT * FROM cdn_ips ORDER BY rtt ASC")
    fun getScannedCdnIps(): Flow<List<CdnIp>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertCdnIp(cdnIp: CdnIp)

    @Query("DELETE FROM cdn_ips")
    suspend fun clearCdnIps()
}
