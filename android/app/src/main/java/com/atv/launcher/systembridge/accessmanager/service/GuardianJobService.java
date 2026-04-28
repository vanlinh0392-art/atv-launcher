package com.atv.launcher.systembridge.accessmanager.service;

import android.app.job.JobParameters;
import android.app.job.JobService;
import android.util.Log;

public class GuardianJobService extends JobService {
    private static final String TAG = "AccessManagerBoot";

    @Override
    public boolean onStartJob(JobParameters params) {
        Log.i(TAG, "Guardian job fired");
        AccessibilityGrantCoordinator.startGuardian(getApplicationContext(), "job_heartbeat");
        jobFinished(params, false);
        return false;
    }

    @Override
    public boolean onStopJob(JobParameters params) {
        return true;
    }
}


