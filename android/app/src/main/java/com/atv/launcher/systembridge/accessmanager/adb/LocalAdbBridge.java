package com.atv.launcher.systembridge.accessmanager.adb;

import android.content.Context;
import android.text.TextUtils;
import android.util.Base64;

import java.io.Closeable;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.io.UnsupportedEncodingException;
import java.math.BigInteger;
import java.net.ConnectException;
import java.net.InetSocketAddress;
import java.net.Socket;
import java.net.SocketTimeoutException;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.charset.StandardCharsets;
import java.security.GeneralSecurityException;
import java.security.KeyFactory;
import java.security.KeyPair;
import java.security.KeyPairGenerator;
import java.security.NoSuchAlgorithmException;
import java.security.interfaces.RSAPublicKey;
import java.security.spec.EncodedKeySpec;
import java.security.spec.InvalidKeySpecException;
import java.security.spec.PKCS8EncodedKeySpec;
import java.security.spec.X509EncodedKeySpec;
import java.util.HashMap;
import java.util.Locale;
import java.util.Queue;
import java.util.concurrent.ConcurrentLinkedQueue;
import java.util.concurrent.atomic.AtomicBoolean;

import javax.crypto.Cipher;

public final class LocalAdbBridge {
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

    public static Result executeShell(Context context, String shellCommand) {
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
                    return Result.failure("Could not create the local ADB key directory.");
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

    private static Result runShellCommand(String shellCommand, AdbCrypto crypto, boolean generatedNewKey) {
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
            return success ? Result.success(rawOutput) : Result.failure(rawOutput);
        } catch (SocketTimeoutException exception) {
            String detail = generatedNewKey
                    ? "Local ADB is waiting for authorization. If the TV shows an ADB prompt for unknown@unknown, allow it and try again."
                    : "Local ADB timed out. The authorize prompt may still be pending or localhost:5555 is not responding.";
            return Result.failure(detail);
        } catch (Exception exception) {
            String detail = exception.toString();
            if (generatedNewKey && !TextUtils.isEmpty(detail)) {
                detail = detail + " If the TV shows an ADB prompt for unknown@unknown, allow it and try again.";
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

    public static final class Result {
        public final boolean success;
        public final String output;
        public final String detail;

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

    private interface AdbBase64 {
        String encodeToString(byte[] data);
    }

    private static final class AdbProtocol {
        static final int ADB_HEADER_LENGTH = 24;
        static final int CMD_CNXN = 0x4e584e43;
        static final int CONNECT_VERSION = 0x01000000;
        static final int CONNECT_MAXDATA = 4096;
        static final int CMD_AUTH = 0x48545541;
        static final int AUTH_TYPE_TOKEN = 1;
        static final int AUTH_TYPE_SIGNATURE = 2;
        static final int AUTH_TYPE_RSA_PUBLIC = 3;
        static final int CMD_OPEN = 0x4e45504f;
        static final int CMD_OKAY = 0x59414b4f;
        static final int CMD_CLSE = 0x45534c43;
        static final int CMD_WRTE = 0x45545257;
        static final byte[] CONNECT_PAYLOAD;

        static {
            byte[] payload = new byte[0];
            try {
                payload = "host::\0".getBytes("UTF-8");
            } catch (UnsupportedEncodingException ignored) {
            }
            CONNECT_PAYLOAD = payload;
        }

        private AdbProtocol() {
        }

        static boolean validateMessage(AdbMessage msg) {
            if (msg.command != (msg.magic ^ 0xFFFFFFFF)) {
                return false;
            }
            return msg.payloadLength == 0 || getPayloadChecksum(msg.payload) == msg.checksum;
        }

        static byte[] generateConnect() {
            return generateMessage(CMD_CNXN, CONNECT_VERSION, CONNECT_MAXDATA, CONNECT_PAYLOAD);
        }

        static byte[] generateAuth(int type, byte[] data) {
            return generateMessage(CMD_AUTH, type, 0, data);
        }

        static byte[] generateOpen(int localId, String dest) throws UnsupportedEncodingException {
            ByteBuffer buffer = ByteBuffer.allocate(dest.length() + 1);
            buffer.put(dest.getBytes("UTF-8"));
            buffer.put((byte) 0);
            return generateMessage(CMD_OPEN, localId, 0, buffer.array());
        }

        static byte[] generateWrite(int localId, int remoteId, byte[] data) {
            return generateMessage(CMD_WRTE, localId, remoteId, data);
        }

        static byte[] generateClose(int localId, int remoteId) {
            return generateMessage(CMD_CLSE, localId, remoteId, null);
        }

        static byte[] generateReady(int localId, int remoteId) {
            return generateMessage(CMD_OKAY, localId, remoteId, null);
        }

        private static int getPayloadChecksum(byte[] payload) {
            int checksum = 0;
            for (byte b : payload) {
                checksum += b >= 0 ? b : b + 256;
            }
            return checksum;
        }

        private static byte[] generateMessage(int cmd, int arg0, int arg1, byte[] payload) {
            ByteBuffer message = ByteBuffer.allocate(
                    payload != null ? ADB_HEADER_LENGTH + payload.length : ADB_HEADER_LENGTH
            ).order(ByteOrder.LITTLE_ENDIAN);
            message.putInt(cmd);
            message.putInt(arg0);
            message.putInt(arg1);
            if (payload != null) {
                message.putInt(payload.length);
                message.putInt(getPayloadChecksum(payload));
            } else {
                message.putInt(0);
                message.putInt(0);
            }
            message.putInt(cmd ^ 0xFFFFFFFF);
            if (payload != null) {
                message.put(payload);
            }
            return message.array();
        }

        static final class AdbMessage {
            int command;
            int arg0;
            int arg1;
            int payloadLength;
            int checksum;
            int magic;
            byte[] payload;

            static AdbMessage parseAdbMessage(InputStream inputStream) throws IOException {
                AdbMessage message = new AdbMessage();
                ByteBuffer header = ByteBuffer.allocate(ADB_HEADER_LENGTH).order(ByteOrder.LITTLE_ENDIAN);
                int dataRead = 0;
                do {
                    int bytesRead = inputStream.read(header.array(), dataRead, ADB_HEADER_LENGTH - dataRead);
                    if (bytesRead < 0) {
                        throw new IOException("Stream closed");
                    }
                    dataRead += bytesRead;
                } while (dataRead < ADB_HEADER_LENGTH);

                message.command = header.getInt();
                message.arg0 = header.getInt();
                message.arg1 = header.getInt();
                message.payloadLength = header.getInt();
                message.checksum = header.getInt();
                message.magic = header.getInt();

                if (message.payloadLength != 0) {
                    message.payload = new byte[message.payloadLength];
                    dataRead = 0;
                    do {
                        int bytesRead = inputStream.read(
                                message.payload,
                                dataRead,
                                message.payloadLength - dataRead
                        );
                        if (bytesRead < 0) {
                            throw new IOException("Stream closed");
                        }
                        dataRead += bytesRead;
                    } while (dataRead < message.payloadLength);
                }
                return message;
            }
        }
    }

    private static final class AdbConnection implements Closeable {
        private final HashMap<Integer, AdbStream> openStreams = new HashMap<>();
        private final Thread connectionThread;
        private Socket socket;
        private InputStream inputStream;
        OutputStream outputStream;
        private int lastLocalId;
        private boolean connectAttempted;
        private boolean connected;
        private AdbCrypto crypto;
        private boolean sentSignature;

        private AdbConnection() {
            connectionThread = createConnectionThread();
        }

        static AdbConnection create(Socket socket, AdbCrypto crypto) throws IOException {
            AdbConnection connection = new AdbConnection();
            connection.crypto = crypto;
            connection.socket = socket;
            connection.inputStream = socket.getInputStream();
            connection.outputStream = socket.getOutputStream();
            socket.setTcpNoDelay(true);
            return connection;
        }

        void connect() throws IOException, InterruptedException {
            if (connected) {
                throw new IllegalStateException("Already connected");
            }
            outputStream.write(AdbProtocol.generateConnect());
            outputStream.flush();
            connectAttempted = true;
            connectionThread.start();
            synchronized (this) {
                if (!connected) {
                    wait();
                }
                if (!connected) {
                    throw new IOException("Connection failed");
                }
            }
        }

        AdbStream open(String destination) throws IOException, InterruptedException {
            int localId = ++lastLocalId;
            if (!connectAttempted) {
                throw new IllegalStateException("connect() must be called first");
            }
            synchronized (this) {
                if (!connected) {
                    wait();
                }
                if (!connected) {
                    throw new IOException("Connection failed");
                }
            }

            AdbStream stream = new AdbStream(this, localId);
            openStreams.put(localId, stream);
            outputStream.write(AdbProtocol.generateOpen(localId, destination));
            outputStream.flush();

            synchronized (stream) {
                stream.wait();
            }
            if (stream.isClosed()) {
                throw new ConnectException("Stream open actively rejected by remote peer");
            }
            return stream;
        }

        @Override
        public void close() throws IOException {
            socket.close();
            connectionThread.interrupt();
            try {
                connectionThread.join();
            } catch (InterruptedException ignored) {
            }
        }

        private Thread createConnectionThread() {
            final AdbConnection connection = this;
            return new Thread(() -> {
                while (!connectionThread.isInterrupted()) {
                    try {
                        AdbProtocol.AdbMessage message = AdbProtocol.AdbMessage.parseAdbMessage(inputStream);
                        if (!AdbProtocol.validateMessage(message)) {
                            continue;
                        }

                        switch (message.command) {
                            case AdbProtocol.CMD_OKAY:
                            case AdbProtocol.CMD_WRTE:
                            case AdbProtocol.CMD_CLSE:
                                if (!connection.connected) {
                                    continue;
                                }
                                AdbStream waitingStream = openStreams.get(message.arg1);
                                if (waitingStream == null) {
                                    continue;
                                }
                                synchronized (waitingStream) {
                                    if (message.command == AdbProtocol.CMD_OKAY) {
                                        waitingStream.updateRemoteId(message.arg0);
                                        waitingStream.readyForWrite();
                                        waitingStream.notify();
                                    } else if (message.command == AdbProtocol.CMD_WRTE) {
                                        waitingStream.addPayload(message.payload);
                                        waitingStream.sendReady();
                                    } else {
                                        openStreams.remove(message.arg1);
                                        waitingStream.notifyClose();
                                    }
                                }
                                break;
                            case AdbProtocol.CMD_AUTH:
                                if (message.arg0 == AdbProtocol.AUTH_TYPE_TOKEN) {
                                    byte[] packet = sentSignature
                                            ? AdbProtocol.generateAuth(
                                            AdbProtocol.AUTH_TYPE_RSA_PUBLIC,
                                            connection.crypto.getAdbPublicKeyPayload()
                                    )
                                            : AdbProtocol.generateAuth(
                                            AdbProtocol.AUTH_TYPE_SIGNATURE,
                                            connection.crypto.signAdbTokenPayload(message.payload)
                                    );
                                    sentSignature = true;
                                    connection.outputStream.write(packet);
                                    connection.outputStream.flush();
                                }
                                break;
                            case AdbProtocol.CMD_CNXN:
                                synchronized (connection) {
                                    connection.connected = true;
                                    connection.notifyAll();
                                }
                                break;
                            default:
                                break;
                        }
                    } catch (Exception ignored) {
                        break;
                    }
                }

                synchronized (connection) {
                    for (AdbStream stream : openStreams.values()) {
                        try {
                            stream.close();
                        } catch (IOException ignored) {
                        }
                    }
                    openStreams.clear();
                    connection.notifyAll();
                    connection.connectAttempted = false;
                }
            });
        }
    }

    private static final class AdbStream implements Closeable {
        private final AdbConnection adbConnection;
        private final int localId;
        private final AtomicBoolean writeReady = new AtomicBoolean(false);
        private final Queue<byte[]> readQueue = new ConcurrentLinkedQueue<>();
        private int remoteId;
        private boolean closed;

        AdbStream(AdbConnection adbConnection, int localId) {
            this.adbConnection = adbConnection;
            this.localId = localId;
        }

        byte[] read() throws InterruptedException, IOException {
            byte[] data = null;
            synchronized (readQueue) {
                while (!closed && (data = readQueue.poll()) == null) {
                    readQueue.wait();
                }
                if (closed) {
                    throw new IOException("Stream closed");
                }
            }
            return data;
        }

        void addPayload(byte[] payload) {
            synchronized (readQueue) {
                readQueue.add(payload);
                readQueue.notifyAll();
            }
        }

        void sendReady() throws IOException {
            byte[] packet = AdbProtocol.generateReady(localId, remoteId);
            adbConnection.outputStream.write(packet);
            adbConnection.outputStream.flush();
        }

        void updateRemoteId(int remoteId) {
            this.remoteId = remoteId;
        }

        void readyForWrite() {
            writeReady.set(true);
        }

        void notifyClose() {
            closed = true;
            synchronized (this) {
                notifyAll();
            }
            synchronized (readQueue) {
                readQueue.notifyAll();
            }
        }

        boolean isClosed() {
            return closed;
        }

        @Override
        public void close() throws IOException {
            synchronized (this) {
                if (closed) {
                    return;
                }
                notifyClose();
            }
            byte[] packet = AdbProtocol.generateClose(localId, remoteId);
            adbConnection.outputStream.write(packet);
            adbConnection.outputStream.flush();
        }
    }

    private static final class AdbCrypto {
        private static final int KEY_LENGTH_BITS = 2048;
        private static final int KEY_LENGTH_BYTES = KEY_LENGTH_BITS / 8;
        private static final int KEY_LENGTH_WORDS = KEY_LENGTH_BYTES / 4;
        private static final int[] SIGNATURE_PADDING_AS_INT = new int[]{
                0x00, 0x01, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
                0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
                0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
                0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
                0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
                0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
                0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
                0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
                0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
                0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
                0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
                0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
                0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
                0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
                0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
                0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
                0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0x00,
                0x30, 0x21, 0x30, 0x09, 0x06, 0x05, 0x2b, 0x0e, 0x03, 0x02, 0x1a, 0x05, 0x00,
                0x04, 0x14
        };
        private static final byte[] SIGNATURE_PADDING;

        static {
            SIGNATURE_PADDING = new byte[SIGNATURE_PADDING_AS_INT.length];
            for (int i = 0; i < SIGNATURE_PADDING.length; i++) {
                SIGNATURE_PADDING[i] = (byte) SIGNATURE_PADDING_AS_INT[i];
            }
        }

        private KeyPair keyPair;
        private AdbBase64 base64;

        static AdbCrypto loadAdbKeyPair(AdbBase64 base64, File privateKey, File publicKey)
                throws IOException, NoSuchAlgorithmException, InvalidKeySpecException {
            AdbCrypto crypto = new AdbCrypto();
            byte[] privKeyBytes = readFile(privateKey);
            byte[] pubKeyBytes = readFile(publicKey);
            KeyFactory keyFactory = KeyFactory.getInstance("RSA");
            EncodedKeySpec privateKeySpec = new PKCS8EncodedKeySpec(privKeyBytes);
            EncodedKeySpec publicKeySpec = new X509EncodedKeySpec(pubKeyBytes);
            crypto.keyPair = new KeyPair(
                    keyFactory.generatePublic(publicKeySpec),
                    keyFactory.generatePrivate(privateKeySpec)
            );
            crypto.base64 = base64;
            return crypto;
        }

        static AdbCrypto generateAdbKeyPair(AdbBase64 base64) throws NoSuchAlgorithmException {
            AdbCrypto crypto = new AdbCrypto();
            KeyPairGenerator generator = KeyPairGenerator.getInstance("RSA");
            generator.initialize(KEY_LENGTH_BITS);
            crypto.keyPair = generator.genKeyPair();
            crypto.base64 = base64;
            return crypto;
        }

        byte[] signAdbTokenPayload(byte[] payload) throws GeneralSecurityException {
            Cipher cipher = Cipher.getInstance("RSA/ECB/NoPadding");
            cipher.init(Cipher.ENCRYPT_MODE, keyPair.getPrivate());
            cipher.update(SIGNATURE_PADDING);
            return cipher.doFinal(payload);
        }

        byte[] getAdbPublicKeyPayload() throws IOException {
            byte[] convertedKey = convertRsaPublicKeyToAdbFormat((RSAPublicKey) keyPair.getPublic());
            StringBuilder keyString = new StringBuilder(720);
            keyString.append(base64.encodeToString(convertedKey));
            keyString.append(" unknown@unknown");
            keyString.append('\0');
            return keyString.toString().getBytes("UTF-8");
        }

        void saveAdbKeyPair(File privateKey, File publicKey) throws IOException {
            writeFile(privateKey, keyPair.getPrivate().getEncoded());
            writeFile(publicKey, keyPair.getPublic().getEncoded());
        }

        private static byte[] convertRsaPublicKeyToAdbFormat(RSAPublicKey publicKey) {
            BigInteger r32 = BigInteger.ZERO.setBit(32);
            BigInteger n = publicKey.getModulus();
            BigInteger r = BigInteger.ZERO.setBit(KEY_LENGTH_WORDS * 32);
            BigInteger rr = r.modPow(BigInteger.valueOf(2), n);
            BigInteger rem = n.remainder(r32);
            BigInteger n0inv = rem.modInverse(r32);
            int[] myN = new int[KEY_LENGTH_WORDS];
            int[] myRr = new int[KEY_LENGTH_WORDS];
            BigInteger[] result;
            for (int i = 0; i < KEY_LENGTH_WORDS; i++) {
                result = rr.divideAndRemainder(r32);
                rr = result[0];
                rem = result[1];
                myRr[i] = rem.intValue();

                result = n.divideAndRemainder(r32);
                n = result[0];
                rem = result[1];
                myN[i] = rem.intValue();
            }

            ByteBuffer buffer = ByteBuffer.allocate(524).order(ByteOrder.LITTLE_ENDIAN);
            buffer.putInt(KEY_LENGTH_WORDS);
            buffer.putInt(n0inv.negate().intValue());
            for (int i : myN) {
                buffer.putInt(i);
            }
            for (int i : myRr) {
                buffer.putInt(i);
            }
            buffer.putInt(publicKey.getPublicExponent().intValue());
            return buffer.array();
        }

        private static byte[] readFile(File file) throws IOException {
            byte[] bytes = new byte[(int) file.length()];
            FileInputStream inputStream = new FileInputStream(file);
            try {
                inputStream.read(bytes);
                return bytes;
            } finally {
                inputStream.close();
            }
        }

        private static void writeFile(File file, byte[] bytes) throws IOException {
            FileOutputStream outputStream = new FileOutputStream(file);
            try {
                outputStream.write(bytes);
            } finally {
                outputStream.close();
            }
        }
    }
}


