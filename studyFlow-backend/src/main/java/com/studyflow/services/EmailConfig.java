
package com.studyflow.services;

import java.io.InputStream;
import java.util.Properties;

public final class EmailConfig {

    private static final Properties CONFIG = new Properties();

    static {
        try (InputStream input =
                     EmailConfig.class.getResourceAsStream("/.env")) {

            if (input == null) {
                throw new IllegalStateException(
                        "Missing .env file in backend resources.");
            }

            CONFIG.load(input);

        } catch (Exception e) {
            throw new ExceptionInInitializerError(e);
        }
    }

    private EmailConfig() {
    }

    public static String getRequired(String name) {

        String value = CONFIG.getProperty(name);

        if (value == null || value.trim().isEmpty()) {
            throw new IllegalStateException(
                    "Missing configuration: " + name);
        }

        return value.trim();
    }
}
