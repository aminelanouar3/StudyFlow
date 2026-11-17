
package com.studyflow.services;

import java.io.BufferedReader;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;

import javax.mail.MessagingException;

public class EmailService {

    private static final String EMAIL_SERVICE_URL =
            "http://127.0.0.1:3001/send-verification-code";

    private static String getRequiredEnv(String name)
            throws MessagingException {

        String value = System.getenv(name);

        if (value == null || value.trim().isEmpty()) {
            throw new MessagingException(
                    "Missing environment variable: " + name
            );
        }

        return value.trim();
    }

    private static String escapeJson(String value) {
        return value.replace("\\", "\\\\")
                .replace("\"", "\\\"");
    }

    public static void sendVerificationCode(
            String recipientEmail,
            String code,
            String purpose) throws MessagingException {

        HttpURLConnection connection = null;

        try {
            String apiKey = getRequiredEnv("STUDYFLOW_EMAIL_API_KEY");

            URL url = new URL(EMAIL_SERVICE_URL);

            connection = (HttpURLConnection) url.openConnection();

            connection.setRequestMethod("POST");
            connection.setConnectTimeout(10000);
            connection.setReadTimeout(20000);
            connection.setDoOutput(true);

            connection.setRequestProperty(
                    "Content-Type", "application/json; charset=UTF-8"
            );

            connection.setRequestProperty("x-api-key", apiKey);

            String json =
                    "{"
                            + "\"recipientEmail\":\""
                            + escapeJson(recipientEmail)
                            + "\","
                            + "\"code\":\""
                            + escapeJson(code)
                            + "\","
                            + "\"purpose\":\""
                            + escapeJson(purpose)
                            + "\""
                            + "}";

            byte[] data = json.getBytes(StandardCharsets.UTF_8);

            try (OutputStream output = connection.getOutputStream()) {
                output.write(data);
            }

            int status = connection.getResponseCode();

            InputStream responseStream =
                    status >= 200 && status < 300
                            ? connection.getInputStream()
                            : connection.getErrorStream();

            StringBuilder responseBody = new StringBuilder();

            if (responseStream != null) {
                try (BufferedReader reader = new BufferedReader(
                        new InputStreamReader(
                                responseStream,
                                StandardCharsets.UTF_8))) {

                    String line;

                    while ((line = reader.readLine()) != null) {
                        responseBody.append(line);
                    }
                }
            }

            if (status < 200 || status >= 300) {
                throw new MessagingException(
                        "Email service error HTTP "
                                + status + ": " + responseBody
                );
            }

        } catch (MessagingException e) {
            throw e;

        } catch (Exception e) {
            throw new MessagingException(
                    "Unable to contact StudyFlow Email Service: "
                            + e.getMessage(), e
            );

        } finally {
            if (connection != null) {
                connection.disconnect();
            }
        }
    }
}
