package com.stackspeak.data.local

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query

@Dao
interface ProgressDao {
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertProgress(progress: UserProgressEntity)

    @Query("SELECT * FROM user_progress WHERE id = :id")
    suspend fun getProgress(id: Int = UserProgressEntity.SINGLETON_ID): UserProgressEntity?

    @Query("SELECT * FROM review_state ORDER BY wordId")
    suspend fun getReviewStates(): List<ReviewStateEntity>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertReviewStates(states: List<ReviewStateEntity>)

    @Query("DELETE FROM review_state")
    suspend fun clearReviewStates()

    @Query("SELECT * FROM assessment_result ORDER BY id")
    suspend fun getAssessmentResults(): List<AssessmentResultEntity>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertAssessmentResults(results: List<AssessmentResultEntity>)

    @Query("DELETE FROM assessment_result")
    suspend fun clearAssessmentResults()

    @Query("SELECT * FROM practiced_sentence ORDER BY rowId")
    suspend fun getPracticedSentences(): List<PracticedSentenceEntity>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertPracticedSentences(sentences: List<PracticedSentenceEntity>)

    @Query("DELETE FROM practiced_sentence")
    suspend fun clearPracticedSentences()

    @Query("SELECT * FROM book_progress ORDER BY bookId")
    suspend fun getBookProgress(): List<BookProgressEntity>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertBookProgress(books: List<BookProgressEntity>)

    @Query("DELETE FROM book_progress")
    suspend fun clearBookProgress()
}

@Dao
interface DailySetDao {
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(set: DailySetEntity)

    @Query("SELECT * FROM daily_set WHERE dayString = :dayString")
    suspend fun get(dayString: String): DailySetEntity?
}
