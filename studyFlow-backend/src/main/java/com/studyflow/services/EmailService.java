
package com.studyflow.services;

import javax.mail.MessagingException;
import java.io.BufferedReader;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;

public class EmailService {

    private static final String EMAIL_API_URL =
            "http://127.0.0.1:3001/send-verification-code";

    private EmailService() {
        // Utility class
    }

    public static void sendVerificationCode(
            String recipientEmail,
            String code,
            String purpose) throws MessagingException {

        HttpURLConnection connection = null;

        try {
            String apiKey =
                    EmailConfig.getRequired("STUDYFLOW_EMAIL_API_KEY");

            URL url = new URL(EMAIL_API_URL);
            connection = (HttpURLConnection) url.openConnection();

            connection.setRequestMethod("POST");
            connection.setConnectTimeout(10000);
            connection.setReadTimeout(15000);
            connection.setDoOutput(true);

            connection.setRequestProperty(
                    "Content-Type", "application/json; charset=UTF-8");

            connection.setRequestProperty(
                    "Accept", "application/json");

            connection.setRequestProperty(
                    "x-api-key", apiKey);

            String json = "{"
                    + "\"recipientEmail\":\"" + escapeJson(recipientEmail) + "\","
                    + "\"code\":\"" + escapeJson(code) + "\","
                    + "\"purpose\":\"" + escapeJson(purpose) + "\""
                    + "}";

            byte[] requestBody =
                    json.getBytes(StandardCharsets.UTF_8);

            connection.setFixedLengthStreamingMode(requestBody.length);

            try (OutputStream output = connection.getOutputStream()) {
                output.write(requestBody);
                output.flush();
            }

            int responseCode = connection.getResponseCode();

            InputStream responseStream =
                    (responseCode >= 200 && responseCode < 300)
                            ? connection.getInputStream()
                            : connection.getErrorStream();

            String responseBody = readResponse(responseStream);

            if (responseCode < 200 || responseCode >= 300) {
                throw new MessagingException(
                        "Email service returned HTTP "
                                + responseCode + ": " + responseBody);
            }

            System.out.println(
                    "Email successfully sent to: " + recipientEmail);

        } catch (MessagingException e) {
            throw e;

        } catch (Exception e) {
            throw new MessagingException(
                    "Unable to communicate with StudyFlow Email Service: "
                            + e.getMessage(), e);

        } finally {
            if (connection != null) {
                connection.disconnect();
            }
        }
    }

    private static String readResponse(InputStream inputStream)
            throws Exception {

        if (inputStream == null) {
            return "";
        }

        StringBuilder response = new StringBuilder();

        try (BufferedReader reader = new BufferedReader(
                new InputStreamReader(
                        inputStream, StandardCharsets.UTF_8))) {

            String line;

            while ((line = reader.readLine()) != null) {
                response.append(line);
            }
        }

        return response.toString();
    }

    private static String escapeJson(String value) {

        if (value == null) {
            return "";
        }

        return value
                .replace("\\", "\\\\")
                .replace("\"", "\\\"")
                .replace("\b", "\\b")
                .replace("\f", "\\f")
                .replace("\n", "\\n")
                .replace("\r", "\\r")
                .replace("\t", "\\t");
    }
}
