package com.aljaroudi.lingko.di

import dagger.Module
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent

@Module
@InstallIn(SingletonComponent::class)
object AppModule {
    // Repository dependencies are injected via constructor injection
    // Future providers for database, datastore, etc. will go here
}
