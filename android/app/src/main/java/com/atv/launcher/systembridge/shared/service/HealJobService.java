package com.atv.launcher.systembridge.shared.service;

import android.app.job.JobParameters;
import android.app.job.JobService;

public class HealJobService extends JobService {
    @Override
    public boolean onStartJob(JobParameters params) {
        jobFinished(params, false);
        return false;
    }

    @Override
    public boolean onStopJob(JobParameters params) {
        return true;
    }
}


