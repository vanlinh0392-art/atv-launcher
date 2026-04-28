package com.atv.launcher.systembridge.density;

import android.content.Context;
import android.text.TextUtils;
import android.util.Base64;

import com.cgutman.adblib.AdbBase64;
import com.cgutman.adblib.AdbConnection;
import com.cgutman.adblib.AdbCrypto;
import com.cgutman.adblib.AdbStream;

import java.io.File;
import java.io.IOException;
import java.net.InetSocketAddress;
import java.net.Socket;
import java.net.SocketTimeoutException;
import java.nio.charset.StandardCharsets;
import java.security.NoSuchAlgorithmException;
import java.security.spec.InvalidKeySpecException;
import java.util.Locale;

final class LocalAdbBridge {
    private static final String KEY_DIRECTORY_NAME = "local_adb";
    private static final String PRIVATE_KEY_FILE_NAME = "adbkey";
    private static final String PUBLIC_KEY_FILE_NAME = "adbkey.pub";
    private static final String LOCAL_ADB_HOST = "127.0.0.1";
    private static final int LOCAL_ADB_PORT = 5555;
    private static final int CONNECT_TIMEOUT_MS = 2000;
    private static final int SOCKET_TIMEOUT_MS = 4000;
    private static final AdbBase64 ADB_BASE64 = data -> Base64.encodeToString(data, Base64.NO_WRAP);

    private LocalAdbBridge() {
    }

    static Result executeShell(Context context, String shellCommand) {
        File keyDir = new File(context.getFilesDir(), KEY_DIRECTORY_NAME);
        File privateKey = new File(keyDir, PRIVATE_KEY_FILE_NAME);
        File publicKey = new File(keyDir, PUBLIC_KEY_FILE_NAME);
        boolean generatedNewKey = false;
        try {
            AdbCrypto crypto;
            if (privateKey.isFile() && publicKey.isFile()) {
                crypto = AdbCrypto.loadAdbKeyPair(ADB_BASE64, privateKey, publicKey);
            } else {
                if (!keyDir.isDirectory() && !keyDir.mkdirs()) {
                    return Result.failure("Khong tao duoc thu muc local ADB key.");
                }
                crypto = AdbCrypto.generateAdbKeyPair(ADB_BASE64);
                crypto.saveAdbKeyPair(privateKey, publicKey);
                generatedNewKey = true;
            }
            return runShellCommand(shellCommand, crypto, generatedNewKey);
        } catch (NoSuchAlgorithmException | InvalidKeySpecException | IOException exception) {
            return Result.failure(exception.toString());
        }
    }

    private static Result runShellCommand(
            String shellCommand,
            AdbCrypto crypto,
            boolean generatedNewKey
    ) {
        Socket socket = new Socket();
        AdbConnection connection = null;
        AdbStream stream = null;
        StringBuilder output = new StringBuilder();
        try {
            socket.connect(new InetSocketAddress(LOCAL_ADB_HOST, LOCAL_ADB_PORT), CONNECT_TIMEOUT_MS);
            socket.setSoTimeout(SOCKET_TIMEOUT_MS);

            connection = AdbConnection.create(socket, crypto);
            connection.connect();
            stream = connection.open("shell:" + shellCommand);

            while (true) {
                try {
                    byte[] payload = stream.read();
                    if (payload != null && payload.length > 0) {
                        output.append(new String(payload, StandardCharsets.UTF_8));
                    }
                } catch (IOException exception) {
                    if (isExpectedStreamClose(exception)) {
                        break;
                    }
                    throw exception;
                }
            }

            String rawOutput = output.toString().trim();
            String lowerOutput = rawOutput.toLowerCase(Locale.US);
            boolean success = !lowerOutput.contains("permission denial")
                    && !lowerOutput.contains("security exception")
                    && !lowerOutput.contains("not found");
            return success
                    ? Result.success(rawOutput)
                    : Result.failure(rawOutput);
        } catch (SocketTimeoutException exception) {
            String detail = generatedNewKey
                    ? "Local ADB dang cho authorize. Neu TV hien prompt ADB cho unknown@unknown, hay bam Allow roi thu lai."
                    : "Local ADB timeout. Co the prompt authorize chua duoc chap nhan hoac localhost:5555 khong phan hoi.";
            return Result.failure(detail);
        } catch (Exception exception) {
            String detail = exception.toString();
            if (generatedNewKey && !TextUtils.isEmpty(detail)) {
                detail = detail + " | Neu TV hien prompt ADB cho unknown@unknown, hay bam Allow roi thu lai.";
            }
            return Result.failure(detail);
        } finally {
            if (stream != null) {
                try {
                    stream.close();
                } catch (Exception ignored) {
                }
            }
            if (connection != null) {
                try {
                    connection.close();
                } catch (Exception ignored) {
                }
            } else {
                try {
                    socket.close();
                } catch (Exception ignored) {
                }
            }
        }
    }

    private static boolean isExpectedStreamClose(IOException exception) {
        return exception.getMessage() != null
                && exception.getMessage().toLowerCase(Locale.US).contains("stream closed");
    }

    static final class Result {
        final boolean success;
        final String output;
        final String detail;

        private Result(boolean success, String output, String detail) {
            this.success = success;
            this.output = output == null ? "" : output.trim();
            this.detail = detail == null ? "" : detail.trim();
        }

        static Result success(String output) {
            return new Result(true, output, "");
        }

        static Result failure(String detail) {
            return new Result(false, "", detail);
        }
    }
}


