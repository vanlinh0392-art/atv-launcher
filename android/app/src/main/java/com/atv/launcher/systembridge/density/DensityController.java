package com.atv.launcher.systembridge.density;

import android.content.Context;
import android.content.pm.PackageManager;
import android.os.IBinder;
import android.os.Parcel;
import android.os.SystemClock;
import android.provider.Settings;
import android.text.TextUtils;
import android.util.Log;

import java.io.BufferedReader;
import java.io.File;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

final class DensityController {
    private static final String TAG = "TVDensity";
    private static final String DISPLAY_DENSITY_FORCED = "display_density_forced";
    private static final int DEFAULT_DISPLAY_ID = 0;
    private static final int DEFAULT_USER_ID = 0;
    private static final int FALLBACK_FACTORY_DENSITY = 320;
    private static final int MIN_DENSITY = 120;
    private static final int MAX_DENSITY = 640;
    private static final Pattern PHYSICAL_PATTERN = Pattern.compile("Physical density:\\s*(\\d+)");
    private static final Pattern OVERRIDE_PATTERN = Pattern.compile("Override density:\\s*(\\d+)");

    private DensityController() {
    }

    static Snapshot loadSnapshot(Context context) {
        Context appContext = context.getApplicationContext();
        boolean hasWriteSecureSettings = hasPermission(
                appContext,
                android.Manifest.permission.WRITE_SECURE_SETTINGS
        );
        boolean rootAvailable = isRootBinaryPresent();

        CommandResult wmResult = runPreferredReadCommand();
        ParsedDensity parsedDensity = parseDensityResult(wmResult.output);
        int resourceDensity = appContext.getResources().getDisplayMetrics().densityDpi;
        int factoryDensity = parsedDensity.physicalDensity != null
                ? parsedDensity.physicalDensity
                : FALLBACK_FACTORY_DENSITY;
        int currentDensity = parsedDensity.overrideDensity != null
                ? parsedDensity.overrideDensity
                : (resourceDensity > 0 ? resourceDensity : factoryDensity);

        return new Snapshot(
                currentDensity,
                factoryDensity,
                parsedDensity.overrideDensity,
                hasWriteSecureSettings,
                rootAvailable,
                buildExecutionSummary(hasWriteSecureSettings, rootAvailable, wmResult)
        );
    }

    static ActionResult applyDensity(Context context, int density) {
        if (density < MIN_DENSITY || density > MAX_DENSITY) {
            return ActionResult.failure(
                    String.format(
                            Locale.US,
                            "Density tuy chinh nen nam trong khoang %d den %d DPI.",
                            MIN_DENSITY,
                            MAX_DENSITY
                    )
            );
        }
        return runWriteSequence(context, density, false);
    }

    static ActionResult applyDensityIfNeeded(Context context, int density) {
        Snapshot snapshot = loadSnapshot(context);
        if (snapshot.currentDensity == density) {
            return ActionResult.success(
                    String.format(Locale.US, "Density da o %d DPI.", snapshot.currentDensity),
                    snapshot
            );
        }
        return applyDensity(context, density);
    }

    static ActionResult resetDensity(Context context) {
        return runWriteSequence(context, FALLBACK_FACTORY_DENSITY, true);
    }

    private static ActionResult runWriteSequence(
            Context context,
            int requestedDensity,
            boolean resetToFactory
    ) {
        Snapshot before = loadSnapshot(context);

        if (before.hasWriteSecureSettings) {
            AttemptResult binderAttempt = resetToFactory
                    ? clearViaWindowManager(context)
                    : applyViaWindowManager(context, requestedDensity);
            ActionResult verifiedResult = verifyAttemptResult(
                    context,
                    binderAttempt,
                    requestedDensity,
                    resetToFactory
            );
            if (verifiedResult != null) {
                return verifiedResult;
            }

            AttemptResult settingsAttempt = resetToFactory
                    ? clearViaSecureSettings(context)
                    : applyViaSecureSettings(context, requestedDensity);
            verifiedResult = verifyAttemptResult(
                    context,
                    settingsAttempt,
                    requestedDensity,
                    resetToFactory
            );
            if (verifiedResult != null) {
                return verifiedResult;
            }
        }

        List<CommandAttempt> attempts = buildShellAttempts(before.rootAvailable, requestedDensity, resetToFactory);
        for (CommandAttempt attempt : attempts) {
            CommandResult commandResult = runCommand(attempt.command);
            Log.i(TAG, "Shell attempt " + attempt.label + " -> success=" + commandResult.success + " output=" + commandResult.output);
            if (!commandResult.success) {
                continue;
            }
            ActionResult verifiedResult = verifyAttemptResult(
                    context,
                    new AttemptResult(true, attempt.label, commandResult.output),
                    requestedDensity,
                    resetToFactory
            );
            if (verifiedResult != null) {
                return verifiedResult;
            }
        }

        LocalAdbBridge.Result localAdbResult = resetToFactory
                ? LocalAdbBridge.executeShell(context, "wm density reset")
                : LocalAdbBridge.executeShell(context, "wm density " + requestedDensity);
        Log.i(TAG, "Local ADB attempt -> success=" + localAdbResult.success + " output=" + localAdbResult.output + " detail=" + localAdbResult.detail);
        ActionResult localAdbVerified = verifyAttemptResult(
                context,
                localAdbResult.success
                        ? AttemptResult.success("local adbd", localAdbResult.output)
                        : AttemptResult.failure("local adbd", localAdbResult.detail),
                requestedDensity,
                resetToFactory
        );
        if (localAdbVerified != null) {
            return localAdbVerified;
        }

        if (!before.hasWriteSecureSettings && !before.rootAvailable) {
            return ActionResult.failure(
                    "Grant da thanh cong, nhung app user khong co du quyen shell de goi wm. Can binder WSS hoat dong hoac TV phai co root."
            );
        }
        if (before.hasWriteSecureSettings) {
            if (!localAdbResult.success && !TextUtils.isEmpty(localAdbResult.detail)) {
                return ActionResult.failure(localAdbResult.detail);
            }
            return ActionResult.failure(
                    "WRITE_SECURE_SETTINGS da co, nhung TV khong chap nhan ca binder lan shell fallback. Kha nang cao la firmware da chan API doi density cho app user."
            );
        }
        return ActionResult.failure("Khong the doi density tren TV nay.");
    }

    private static ActionResult verifyAttemptResult(
            Context context,
            AttemptResult attemptResult,
            int requestedDensity,
            boolean resetToFactory
    ) {
        if (attemptResult == null || !attemptResult.success) {
            if (attemptResult != null) {
                Log.w(TAG, "Attempt failed: " + attemptResult.label + " detail=" + attemptResult.detail);
            }
            return null;
        }
        SystemClock.sleep(600L);
        Snapshot after = loadSnapshot(context);
        boolean verified = resetToFactory
                ? after.overrideDensity == null || after.currentDensity == after.factoryDensity
                : after.currentDensity == requestedDensity;
        Log.i(TAG, "Verify after " + attemptResult.label + " -> current=" + after.currentDensity + " factory=" + after.factoryDensity + " override=" + after.overrideDensity);
        if (!verified) {
            return null;
        }
        String message = resetToFactory
                ? String.format(
                Locale.US,
                "Da reset density. Hien tai: %d DPI (%s).",
                after.currentDensity,
                attemptResult.label
        )
                : String.format(
                Locale.US,
                "Da doi density sang %d DPI (%s).",
                after.currentDensity,
                attemptResult.label
        );
        return ActionResult.success(message, after);
    }

    private static AttemptResult applyViaWindowManager(Context context, int density) {
        try {
            AttemptResult transactAttempt = transactWindowManager(
                    "TRANSACTION_setForcedDisplayDensityForUser",
                    DEFAULT_DISPLAY_ID,
                    density,
                    DEFAULT_USER_ID
            );
            if (transactAttempt.success) {
                persistDensitySetting(context, String.valueOf(density));
                return AttemptResult.success("binder transact", transactAttempt.detail);
            }
            transactAttempt = transactWindowManager(
                    "TRANSACTION_setForcedDisplayDensity",
                    DEFAULT_DISPLAY_ID,
                    density
            );
            if (transactAttempt.success) {
                persistDensitySetting(context, String.valueOf(density));
                return AttemptResult.success("binder transact", transactAttempt.detail);
            }

            Object windowManager = getWindowManager();
            if (windowManager == null) {
                return AttemptResult.failure("binder WindowManager", "window service null");
            }
            if (invokeWindowManagerMethod(
                    windowManager,
                    "setForcedDisplayDensityForUser",
                    new Class[]{int.class, int.class, int.class},
                    DEFAULT_DISPLAY_ID,
                    density,
                    DEFAULT_USER_ID
            )) {
                persistDensitySetting(context, String.valueOf(density));
                return AttemptResult.success("binder WindowManager", "setForcedDisplayDensityForUser");
            }
            if (invokeWindowManagerMethod(
                    windowManager,
                    "setForcedDisplayDensity",
                    new Class[]{int.class, int.class},
                    DEFAULT_DISPLAY_ID,
                    density
            )) {
                persistDensitySetting(context, String.valueOf(density));
                return AttemptResult.success("binder WindowManager", "setForcedDisplayDensity");
            }
            return AttemptResult.failure("binder WindowManager", "No matching hidden API method");
        } catch (Exception exception) {
            Log.w(TAG, "applyViaWindowManager failed", exception);
            return AttemptResult.failure("binder WindowManager", exception.toString());
        }
    }

    private static AttemptResult clearViaWindowManager(Context context) {
        try {
            AttemptResult transactAttempt = transactWindowManager(
                    "TRANSACTION_clearForcedDisplayDensityForUser",
                    DEFAULT_DISPLAY_ID,
                    DEFAULT_USER_ID
            );
            if (transactAttempt.success) {
                persistDensitySetting(context, null);
                return AttemptResult.success("binder transact", transactAttempt.detail);
            }
            transactAttempt = transactWindowManager(
                    "TRANSACTION_clearForcedDisplayDensity",
                    DEFAULT_DISPLAY_ID
            );
            if (transactAttempt.success) {
                persistDensitySetting(context, null);
                return AttemptResult.success("binder transact", transactAttempt.detail);
            }

            Object windowManager = getWindowManager();
            if (windowManager == null) {
                return AttemptResult.failure("binder WindowManager", "window service null");
            }
            if (invokeWindowManagerMethod(
                    windowManager,
                    "clearForcedDisplayDensityForUser",
                    new Class[]{int.class, int.class},
                    DEFAULT_DISPLAY_ID,
                    DEFAULT_USER_ID
            )) {
                persistDensitySetting(context, null);
                return AttemptResult.success("binder WindowManager", "clearForcedDisplayDensityForUser");
            }
            if (invokeWindowManagerMethod(
                    windowManager,
                    "clearForcedDisplayDensity",
                    new Class[]{int.class},
                    DEFAULT_DISPLAY_ID
            )) {
                persistDensitySetting(context, null);
                return AttemptResult.success("binder WindowManager", "clearForcedDisplayDensity");
            }
            return AttemptResult.failure("binder WindowManager", "No matching hidden API method");
        } catch (Exception exception) {
            Log.w(TAG, "clearViaWindowManager failed", exception);
            return AttemptResult.failure("binder WindowManager", exception.toString());
        }
    }

    private static AttemptResult applyViaSecureSettings(Context context, int density) {
        try {
            boolean written = persistDensitySetting(context, String.valueOf(density));
            return written
                    ? AttemptResult.success("Settings.Secure", DISPLAY_DENSITY_FORCED)
                    : AttemptResult.failure("Settings.Secure", "putString returned false");
        } catch (Exception exception) {
            Log.w(TAG, "applyViaSecureSettings failed", exception);
            return AttemptResult.failure("Settings.Secure", exception.toString());
        }
    }

    private static AttemptResult clearViaSecureSettings(Context context) {
        try {
            boolean written = persistDensitySetting(context, null);
            return written
                    ? AttemptResult.success("Settings.Secure", DISPLAY_DENSITY_FORCED + "=null")
                    : AttemptResult.failure("Settings.Secure", "putString(null) returned false");
        } catch (Exception exception) {
            Log.w(TAG, "clearViaSecureSettings failed", exception);
            return AttemptResult.failure("Settings.Secure", exception.toString());
        }
    }

    private static boolean persistDensitySetting(Context context, String value) {
        return Settings.Secure.putString(
                context.getContentResolver(),
                DISPLAY_DENSITY_FORCED,
                value
        );
    }

    private static Object getWindowManager() throws Exception {
        Class<?> serviceManagerClass = Class.forName("android.os.ServiceManager");
        IBinder binder = (IBinder) serviceManagerClass
                .getMethod("getService", String.class)
                .invoke(null, "window");
        if (binder == null) {
            return null;
        }
        Class<?> stubClass = Class.forName("android.view.IWindowManager$Stub");
        return stubClass
                .getMethod("asInterface", IBinder.class)
                .invoke(null, binder);
    }

    private static AttemptResult transactWindowManager(
            String transactionFieldName,
            int... intArgs
    ) {
        Parcel data = Parcel.obtain();
        Parcel reply = Parcel.obtain();
        try {
            Class<?> serviceManagerClass = Class.forName("android.os.ServiceManager");
            IBinder binder = (IBinder) serviceManagerClass
                    .getMethod("getService", String.class)
                    .invoke(null, "window");
            if (binder == null) {
                return AttemptResult.failure("binder transact", "window service null");
            }
            Class<?> stubClass = Class.forName("android.view.IWindowManager$Stub");
            java.lang.reflect.Field transactionField = stubClass.getDeclaredField(transactionFieldName);
            transactionField.setAccessible(true);
            int transactionCode = transactionField.getInt(null);

            data.writeInterfaceToken("android.view.IWindowManager");
            for (int arg : intArgs) {
                data.writeInt(arg);
            }
            boolean transactOk = binder.transact(transactionCode, data, reply, 0);
            if (!transactOk) {
                return AttemptResult.failure("binder transact", transactionFieldName + " transact returned false");
            }
            reply.readException();
            return AttemptResult.success("binder transact", transactionFieldName);
        } catch (Exception exception) {
            Log.w(TAG, "transactWindowManager failed for " + transactionFieldName, exception);
            return AttemptResult.failure("binder transact", exception.toString());
        } finally {
            reply.recycle();
            data.recycle();
        }
    }

    private static boolean invokeWindowManagerMethod(
            Object target,
            String methodName,
            Class<?>[] parameterTypes,
            Object... args
    ) {
        Exception primaryException = null;
        try {
            Class<?> interfaceClass = Class.forName("android.view.IWindowManager");
            java.lang.reflect.Method method = interfaceClass.getDeclaredMethod(methodName, parameterTypes);
            method.setAccessible(true);
            method.invoke(target, args);
            return true;
        } catch (Exception exception) {
            primaryException = exception;
            try {
                java.lang.reflect.Method fallbackMethod = target.getClass().getDeclaredMethod(methodName, parameterTypes);
                fallbackMethod.setAccessible(true);
                fallbackMethod.invoke(target, args);
                return true;
            } catch (NoSuchMethodException ignored) {
                if (primaryException != null) {
                    Log.w(TAG, "Primary invoke failed for " + methodName, primaryException);
                }
                return false;
            } catch (Exception fallbackException) {
                if (primaryException != null) {
                    Log.w(TAG, "Primary invoke failed for " + methodName, primaryException);
                }
                Log.w(TAG, "invokeMethod failed for " + methodName, fallbackException);
                return false;
            }
        }
    }

    private static List<CommandAttempt> buildShellAttempts(
            boolean rootAvailable,
            int requestedDensity,
            boolean resetToFactory
    ) {
        String wmSubcommand = resetToFactory
                ? "density reset"
                : "density " + requestedDensity;
        ArrayList<CommandAttempt> attempts = new ArrayList<>();
        if (rootAvailable) {
            attempts.add(new CommandAttempt(
                    "root su",
                    new String[]{"su", "-c", "wm " + wmSubcommand}
            ));
        }
        attempts.add(new CommandAttempt(
                "user shell fallback",
                new String[]{"sh", "-c", "wm " + wmSubcommand}
        ));
        return attempts;
    }

    private static CommandResult runPreferredReadCommand() {
        return runCommand(new String[]{"sh", "-c", "wm density"});
    }

    private static boolean isRootBinaryPresent() {
        String[] candidates = {
                "/system/bin/su",
                "/system/xbin/su",
                "/sbin/su",
                "/system_ext/bin/su",
                "/product/bin/su"
        };
        for (String candidate : candidates) {
            if (new File(candidate).exists()) {
                return true;
            }
        }
        CommandResult whichResult = runCommand(new String[]{"sh", "-c", "which su"});
        return whichResult.success && !TextUtils.isEmpty(whichResult.output);
    }

    private static ParsedDensity parseDensityResult(String output) {
        Integer physical = extractDensity(output, PHYSICAL_PATTERN);
        Integer override = extractDensity(output, OVERRIDE_PATTERN);
        return new ParsedDensity(physical, override);
    }

    private static Integer extractDensity(String output, Pattern pattern) {
        if (TextUtils.isEmpty(output)) {
            return null;
        }
        Matcher matcher = pattern.matcher(output);
        if (!matcher.find()) {
            return null;
        }
        try {
            return Integer.parseInt(matcher.group(1));
        } catch (Exception ignored) {
            return null;
        }
    }

    private static boolean hasPermission(Context context, String permission) {
        return context.checkCallingOrSelfPermission(permission) == PackageManager.PERMISSION_GRANTED;
    }

    private static String buildExecutionSummary(
            boolean hasWriteSecureSettings,
            boolean rootAvailable,
            CommandResult readResult
    ) {
        ArrayList<String> flags = new ArrayList<>();
        flags.add(hasWriteSecureSettings ? "WSS OK" : "WSS Missing");
        flags.add(rootAvailable ? "Root OK" : "Root Off");
        flags.add(readResult.success ? "wm read OK" : "wm read fail");
        return TextUtils.join(" | ", flags);
    }

    private static CommandResult runCommand(String[] command) {
        Process process = null;
        try {
            process = new ProcessBuilder(command)
                    .redirectErrorStream(true)
                    .start();
            String output = readAll(process.getInputStream());
            int exitCode = process.waitFor();
            String lowerOutput = output.toLowerCase(Locale.US);
            boolean success = exitCode == 0
                    && !lowerOutput.contains("permission denial")
                    && !lowerOutput.contains("security exception")
                    && !lowerOutput.contains("not found");
            return success
                    ? CommandResult.success(output)
                    : CommandResult.failure(output, output);
        } catch (Exception exception) {
            return CommandResult.failure("", exception.toString());
        } finally {
            if (process != null) {
                process.destroy();
            }
        }
    }

    private static String readAll(InputStream inputStream) throws Exception {
        ArrayList<String> lines = new ArrayList<>();
        try (BufferedReader reader = new BufferedReader(
                new InputStreamReader(inputStream, StandardCharsets.UTF_8))) {
            String line;
            while ((line = reader.readLine()) != null) {
                lines.add(line);
            }
        }
        return TextUtils.join("\n", lines).trim();
    }

    static final class Snapshot {
        final int currentDensity;
        final int factoryDensity;
        final Integer overrideDensity;
        final boolean hasWriteSecureSettings;
        final boolean rootAvailable;
        final String executionSummary;

        Snapshot(
                int currentDensity,
                int factoryDensity,
                Integer overrideDensity,
                boolean hasWriteSecureSettings,
                boolean rootAvailable,
                String executionSummary
        ) {
            this.currentDensity = currentDensity;
            this.factoryDensity = factoryDensity;
            this.overrideDensity = overrideDensity;
            this.hasWriteSecureSettings = hasWriteSecureSettings;
            this.rootAvailable = rootAvailable;
            this.executionSummary = executionSummary;
        }
    }

    static final class ActionResult {
        final boolean success;
        final String message;
        final Snapshot snapshot;

        private ActionResult(boolean success, String message, Snapshot snapshot) {
            this.success = success;
            this.message = message;
            this.snapshot = snapshot;
        }

        static ActionResult success(String message, Snapshot snapshot) {
            return new ActionResult(true, message, snapshot);
        }

        static ActionResult failure(String message) {
            return new ActionResult(false, message, null);
        }
    }

    private static final class ParsedDensity {
        final Integer physicalDensity;
        final Integer overrideDensity;

        ParsedDensity(Integer physicalDensity, Integer overrideDensity) {
            this.physicalDensity = physicalDensity;
            this.overrideDensity = overrideDensity;
        }
    }

    private static final class AttemptResult {
        final boolean success;
        final String label;
        final String detail;

        private AttemptResult(boolean success, String label, String detail) {
            this.success = success;
            this.label = label;
            this.detail = detail;
        }

        static AttemptResult success(String label, String detail) {
            return new AttemptResult(true, label, detail);
        }

        static AttemptResult failure(String label, String detail) {
            return new AttemptResult(false, label, detail);
        }
    }

    private static final class CommandAttempt {
        final String label;
        final String[] command;

        CommandAttempt(String label, String[] command) {
            this.label = label;
            this.command = command;
        }
    }

    private static final class CommandResult {
        final boolean success;
        final String output;
        final String detail;

        private CommandResult(boolean success, String output, String detail) {
            this.success = success;
            this.output = output == null ? "" : output.trim();
            this.detail = detail == null ? "" : detail.trim();
        }

        static CommandResult success(String output) {
            return new CommandResult(true, output, "");
        }

        static CommandResult failure(String output, String detail) {
            return new CommandResult(false, output, detail);
        }
    }
}


