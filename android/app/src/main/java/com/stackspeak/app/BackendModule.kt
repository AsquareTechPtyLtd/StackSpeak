package com.stackspeak.app

import android.content.Context
import com.stackspeak.BuildConfig
import com.stackspeak.data.backend.BackendConfig
import com.stackspeak.data.backend.BackendService
import com.stackspeak.data.backend.EncryptedTokenStore
import com.stackspeak.data.backend.NoOpBackendService
import com.stackspeak.data.backend.SupabaseBackendService
import com.stackspeak.data.backend.TokenStore
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import okhttp3.OkHttpClient
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object BackendModule {

    @Provides
    @Singleton
    fun okHttpClient(): OkHttpClient = OkHttpClient.Builder().build()

    @Provides
    @Singleton
    fun backendConfig(): BackendConfig = BackendConfig(BuildConfig.SUPABASE_URL, BuildConfig.SUPABASE_ANON_KEY)

    @Provides
    @Singleton
    fun tokenStore(@ApplicationContext context: Context): TokenStore = EncryptedTokenStore(context)

    @Provides
    @Singleton
    fun backendService(config: BackendConfig, tokens: TokenStore, http: OkHttpClient): BackendService =
        if (config.isConfigured) SupabaseBackendService(config, tokens, http) else NoOpBackendService()

    @Provides
    @Singleton
    fun purchaseRepository(impl: com.stackspeak.data.billing.PlayBillingRepository): com.stackspeak.data.billing.PurchaseRepository = impl
}
