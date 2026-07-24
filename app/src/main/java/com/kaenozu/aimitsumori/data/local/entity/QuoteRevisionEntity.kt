package com.kaenozu.aimitsumori.data.local.entity

import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey

@Entity(
    tableName = "quote_revisions",
    foreignKeys = [ForeignKey(
        entity = VendorEntity::class,
        parentColumns = ["id"],
        childColumns = ["vendorId"],
        onDelete = ForeignKey.CASCADE
    )],
    indices = [Index("vendorId")]
)
data class QuoteRevisionEntity(
    @PrimaryKey val id: String,
    val vendorId: String,
    val revisionNumber: Int,
    val quoteDate: String? = null,
    val validUntil: String? = null,
    val subtotal: Long? = null,
    val discount: Long? = null,
    val tax: Long? = null,
    val total: Long? = null,
    val paymentTerms: String? = null,
    val warranty: String? = null,
    val constructionPeriod: String? = null,
    val createdAt: Long
)
