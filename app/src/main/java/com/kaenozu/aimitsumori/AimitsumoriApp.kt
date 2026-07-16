package com.kaenozu.aimitsumori

import android.app.Application
import com.kaenozu.aimitsumori.app.AppContainer

class AimitsumoriApp : Application() {
    lateinit var container: AppContainer
        private set

    override fun onCreate() {
        super.onCreate()
        container = AppContainer(this)
        container.seedSampleData()
    }
}
